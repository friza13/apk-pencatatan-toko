import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/core/units/quantity.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/customers/data/party_repositories.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

void main() {
  late AppDatabase db;
  late SalesService sales;
  late InventoryService inventory;
  late int businessId;
  late int cashAccountId;
  late int barangId; // tracked goods
  late int jasaId; // service
  late int customerId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sales = SalesService(db);
    inventory = InventoryService(db);

    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'));

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);

    cashAccountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(businessId: businessId, name: 'Kas'));

    final products = ProductRepository(db);
    barangId = await products.createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Kopi 200g',
        baseUnitId: (await refs.unitByCode(businessId, 'pcs'))!.id,
        costPriceMinor: 8000,
        salePriceMinor: 12000,
        minStockMicro: 5000000,
      ),
    );
    await inventory.setOpeningBalance(barangId, 20000000); // 20 pcs

    jasaId = await products.createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Ongkir dalam kota',
        type: 'service',
        trackStock: false,
        baseUnitId: (await refs.unitByCode(businessId, 'pcs'))!.id,
        salePriceMinor: 5000,
      ),
    );

    final custRepo = CustomerRepository(db);
    customerId = await custRepo.create(
      businessId: businessId,
      name: 'Ibu Sari',
    );
  });

  tearDown(() async => db.close());

  Future<int> stockOf(int pid) async => (await (db.select(
    db.products,
  )..where((t) => t.id.equals(pid))).getSingle()).stockQuantityMicro;

  SaleLineInput line(int pid, String qty, int price) => SaleLineInput(
    productId: pid,
    qtyMicro: toMicro(qty),
    unitPriceMinor: price,
  );

  test('paid sale commits everything atomically', () async {
    final out = await sales.checkout(
      CheckoutInput(
        lines: [line(barangId, '3', 12000)],
        accountId: cashAccountId,
        paidNowMinor: 36000,
      ),
    );

    expect(out.number, startsWith('INV'));
    expect(out.grandTotalMinor, 36000);
    expect(out.dueTotalMinor, 0);

    expect(await stockOf(barangId), 17000000); // 20-3

    final payments = await db.select(db.payments).get();
    expect(payments.single.amountMinor, 36000);
    final ledger = await db.select(db.ledgerEntries).get();
    expect(ledger.single.entryType, 'debit');

    final acc = await (db.select(
      db.accounts,
    )..where((t) => t.id.equals(cashAccountId))).getSingle();
    expect(acc.currentBalanceMinor, 36000);

    final logs = await db.select(db.activityLogs).get();
    expect(logs.single.action, 'sale.created');

    final biz = await (db.select(db.businesses)).getSingle();
    expect(biz.invoiceSequence, 1);
  });

  test(
    'credit sale creates receivable; partial payment marks partially_paid',
    () async {
      final out = await sales.checkout(
        CheckoutInput(
          lines: [line(barangId, '2', 12000)], // 24.000
          accountId: cashAccountId,
          customerId: customerId,
          paidNowMinor: 10000,
        ),
      );
      expect(out.dueTotalMinor, 14000);

      final sale = await (db.select(db.sales)).getSingle();
      expect(sale.status, 'partially_paid');

      final receivable = await db.select(db.receivables).getSingle();
      expect(receivable.remainingAmountMinor, 14000);
    },
  );

  test('zero-pay with customer -> CREDIT status + full receivable', () async {
    final out = await sales.checkout(
      CheckoutInput(
        lines: [line(jasaId, '2', 5000)], // jasa: 10.000
        accountId: cashAccountId,
        customerId: customerId,
        // paidNowMinor defaults to 0 -> full credit sale.
      ),
    );
    expect(out.dueTotalMinor, 10000);
    final sale = await (db.select(db.sales)).getSingle();
    expect(sale.status, 'credit');
    expect(await stockOf(barangId), 20000000);
    final movements = await inventory.movementsFor(barangId);
    expect(movements, hasLength(1)); // opening only
  });

  test('insufficient stock rolls back the whole transaction', () async {
    final beforePayments = await db.select(db.payments).get();
    await expectLater(
      sales.checkout(
        CheckoutInput(
          lines: [line(barangId, '999', 12000)],
          accountId: cashAccountId,
          paidNowMinor: 999 * 12000,
        ),
      ),
      throwsA(isA<Failure>()),
    );
    expect(await db.select(db.payments).get(), beforePayments);
    expect(await stockOf(barangId), 20000000);
  });

  test('order-level discount uses MoneyPolicy chain', () async {
    final out = await sales.checkout(
      CheckoutInput(
        lines: [line(barangId, '10', 12000)], // 120.000
        accountId: cashAccountId,
        paidNowMinor: 108000,
        orderDiscountLevel1PercentBp: 1000, // -10% => 108.000
      ),
    );
    expect(out.grandTotalMinor, 108000);
  });

  test('voidSale rejects a sale with financial side effects', () async {
    final out = await sales.checkout(
      CheckoutInput(
        lines: [line(barangId, '5', 12000)],
        accountId: cashAccountId,
        paidNowMinor: 60000,
      ),
    );
    expect(await stockOf(barangId), 15000000);

    await expectLater(
      sales.voidSale(out.saleId, 'salah input'),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCodes.saleCannotVoid),
      ),
    );
    expect(await stockOf(barangId), 15000000);
    expect((await db.select(db.sales).get()).single.status, 'paid');
    expect(
      await (db.select(
        db.activityLogs,
      )..where((t) => t.action.equals('sale.voided'))).get(),
      isEmpty,
    );
  });

  test(
    'unpaid sale without customer is rejected without committing rows',
    () async {
      await expectLater(
        sales.checkout(
          CheckoutInput(
            lines: [line(barangId, '1', 12000)],
            accountId: cashAccountId,
          ),
        ),
        throwsA(
          isA<Failure>().having(
            (f) => f.code,
            'code',
            ErrorCodes.customerRequiredForCredit,
          ),
        ),
      );
      expect(await db.select(db.sales).get(), isEmpty);
      expect(await db.select(db.payments).get(), isEmpty);
      expect(await stockOf(barangId), 20000000);
    },
  );

  test('invoice numbers increment across sales', () async {
    final a = await sales.checkout(
      CheckoutInput(
        lines: [line(jasaId, '1', 5000)],
        accountId: cashAccountId,
        paidNowMinor: 5000,
      ),
    );
    final b = await sales.checkout(
      CheckoutInput(
        lines: [line(jasaId, '1', 5000)],
        accountId: cashAccountId,
        paidNowMinor: 5000,
      ),
    );
    expect(a.number, isNot(b.number));
  });
}
