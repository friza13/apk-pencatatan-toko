import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/domain/business_clock.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/reports/data/report_repository.dart';
import 'package:notakit/features/customers/data/party_repositories.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

void main() {
  late AppDatabase db;
  late ReportRepository reports;
  late int businessId;
  late int kasId;
  late int barangId;
  late int jasaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reports = ReportRepository(db);

    final ownerId =
        await db.into(db.owners).insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'),
        );

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    final pcs = (await refs.unitByCode(businessId, 'pcs'))!.id;

    kasId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(businessId: businessId, name: 'Kas'),
        );

    final products = ProductRepository(db);
    barangId = await products.createProduct(ProductDraft(
      businessId: businessId,
      name: 'Kopi 200g',
      baseUnitId: pcs,
      costPriceMinor: 8000,
      salePriceMinor: 12000,
    ));
    jasaId = await products.createProduct(ProductDraft(
      businessId: businessId,
      name: 'Jasa Kirim',
      type: 'service',
      trackStock: false,
      baseUnitId: pcs,
      salePriceMinor: 5000,
    ));

    await InventoryService(db).setOpeningBalance(barangId, 50000000); // 50
  });

  tearDown(() async => db.close());

  Future<void> backdateLastSaleByDays(int days) async {
    // Ambil sale terakhir lalu geser created_at ke masa lalu.
    final sale = await (db.select(db.sales)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingle();
    await (db.update(db.sales)..where((t) => t.id.equals(sale.id))).write(
      SalesCompanion(
        createdAt: Value(
            DateTime.now().toUtc().subtract(Duration(days: days))),
      ),
    );
  }

  test('salesSummary computes total/profit/count for today', () async {
    final out = await SalesService(db).checkout(CheckoutInput(
      lines: [
        SaleLineInput(productId: barangId, qtyMicro: 3000000, unitPriceMinor: 12000),
      ],
      accountId: kasId,
      paidNowMinor: 36000,
    ));

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final offset = BusinessClock.offsetMinutesFor('Asia/Jakarta');
    final (s, e) = BusinessClock.dayRangeUtcMillis(now, offset);

    final sum = await reports.salesSummary(
      businessId: businessId,
      startUtcMillis: s,
      endUtcMillis: e,
    );
    expect(sum.transactionCount, 1);
    expect(sum.totalMinor, 36000);
    expect(sum.profitMinor, 12000); // 36k - 3x8k
    expect(out.number, isNotEmpty);
  });

  test('backdated sale counted in last7 but not today', () async {
    await SalesService(db).checkout(CheckoutInput(
      lines: [SaleLineInput(productId: barangId, qtyMicro: 2000000, unitPriceMinor: 12000)],
      accountId: kasId,
      paidNowMinor: 24000,
    ));
    await backdateLastSaleByDays(3);
    await SalesService(db).checkout(CheckoutInput(
      lines: [SaleLineInput(productId: barangId, qtyMicro: 1000000, unitPriceMinor: 12000)],
      accountId: kasId,
      paidNowMinor: 12000,
    ));

    final offset = BusinessClock.offsetMinutesFor('Asia/Jakarta');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final (ts, te) = BusinessClock.dayRangeUtcMillis(now, offset);

    final today = await reports.salesSummary(
        businessId: businessId, startUtcMillis: ts, endUtcMillis: te);
    expect(today.totalMinor, 12000);

    final week = await reports.salesSummary(
      businessId: businessId,
      startUtcMillis: ts - 6 * BusinessClock.millisPerDay,
      endUtcMillis: te,
    );
    expect(week.totalMinor, 36000);
    expect(week.transactionCount, 2);
  });

  test('voided sale excluded from summaries', () async {
    final out = await SalesService(db).checkout(CheckoutInput(
      lines: [SaleLineInput(productId: barangId, qtyMicro: 1000000, unitPriceMinor: 12000)],
      accountId: kasId,
      paidNowMinor: 12000,
    ));
    await SalesService(db).voidSale(out.saleId, 'tes');

    final offset = BusinessClock.offsetMinutesFor('Asia/Jakarta');
    final (s, e) =
        BusinessClock.dayRangeUtcMillis(DateTime.now().toUtc().millisecondsSinceEpoch, offset);
    final sum = await reports.salesSummary(
        businessId: businessId, startUtcMillis: s, endUtcMillis: e);
    expect(sum.totalMinor, 0);
  });

  test('topProducts aggregates by snapshot name', () async {
    await SalesService(db).checkout(CheckoutInput(
      lines: [
        SaleLineInput(productId: barangId, qtyMicro: 2000000, unitPriceMinor: 12000),
        SaleLineInput(productId: jasaId, qtyMicro: 1000000, unitPriceMinor: 5000),
      ],
      accountId: kasId,
      paidNowMinor: 29000,
    ));

    final offset = BusinessClock.offsetMinutesFor('Asia/Jakarta');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final (s, e) = BusinessClock.dayRangeUtcMillis(now, offset);

    final top = await reports.topProducts(
        businessId: businessId, startUtcMillis: s, endUtcMillis: e);
    expect(top.first.name, 'Kopi 200g');
    expect(top.first.totalMinor, 24000);
  });

  test('stockValuation uses cached stock x WAC', () async {
    // Opening 50 - 3 sold below = 47 -> 47 x 8.000
    await SalesService(db).checkout(CheckoutInput(
      lines: [SaleLineInput(productId: barangId, qtyMicro: 3000000, unitPriceMinor: 12000)],
      accountId: kasId,
      paidNowMinor: 36000,
    ));
    expect(await reports.stockValuationMinor(businessId), 376000000 ~/ 1000 * 1000 == 0 ? 0 : 47 * 8000);
  });

  test('receivablesOutstanding sums remaining', () async {
    final custRepo = CustomerRepository(db);
    final cid = await custRepo.create(businessId: businessId, name: 'C1');
    await SalesService(db).checkout(CheckoutInput(
      lines: [SaleLineInput(productId: jasaId, qtyMicro: 2000000, unitPriceMinor: 5000)],
      accountId: kasId,
      customerId: cid,
      paidNowMinor: 4000, // sisa 6.000
    ));
    expect(await reports.receivablesOutstanding(businessId), 6000);
  });
}
