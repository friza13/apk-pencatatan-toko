import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/customers/data/party_repositories.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/sales/data/sales_return_service.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

void main() {
  late AppDatabase db;
  late int businessId;
  late int accountId;
  late int productId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'));
    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    final pcs = (await refs.unitByCode(businessId, 'pcs'))!.id;
    accountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(businessId: businessId, name: 'Kas'));
    productId = await ProductRepository(db).createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Kopi',
        baseUnitId: pcs,
        costPriceMinor: 8000,
        salePriceMinor: 12000,
      ),
    );
    await InventoryService(db).setOpeningBalance(productId, 10000000);
  });

  tearDown(() => db.close());

  test(
    'full cash return restores stock and reverses account balance',
    () async {
      final sale = await SalesService(db).checkout(
        CheckoutInput(
          lines: [
            SaleLineInput(
              productId: productId,
              qtyMicro: 1000000,
              unitPriceMinor: 12000,
            ),
          ],
          accountId: accountId,
          paidNowMinor: 12000,
        ),
      );
      final line = (await db.select(db.saleLines).get()).single;
      final before =
          (await db.select(db.products).get()).single.stockQuantityMicro;
      final accountBefore =
          (await db.select(db.accounts).get()).single.currentBalanceMinor;

      final returned = await SalesReturnService(db).createReturn(
        SalesReturnInput(
          saleId: sale.saleId,
          lines: [
            SalesReturnLineInput(saleLineId: line.id, qtyBaseMicro: 1000000),
          ],
          reason: 'rusak',
        ),
      );

      expect(returned.totalMinor, 12000);
      expect(
        (await db.select(db.products).get()).single.stockQuantityMicro,
        before + 1000000,
      );
      expect(
        (await db.select(db.accounts).get()).single.currentBalanceMinor,
        accountBefore - 12000,
      );
      expect(
        (await db.select(db.payments).get()).where(
          (p) => p.purpose == 'refund',
        ),
        hasLength(1),
      );
      expect(
        (await db.select(db.activityLogs).get()).where(
          (l) => l.action == 'sale.returned',
        ),
        hasLength(1),
      );
    },
  );

  test('return cannot exceed remaining sale quantity', () async {
    final sale = await SalesService(db).checkout(
      CheckoutInput(
        lines: [
          SaleLineInput(
            productId: productId,
            qtyMicro: 1000000,
            unitPriceMinor: 12000,
          ),
        ],
        accountId: accountId,
        paidNowMinor: 12000,
      ),
    );
    final line = (await db.select(db.saleLines).get()).single;
    await SalesReturnService(db).createReturn(
      SalesReturnInput(
        saleId: sale.saleId,
        lines: [
          SalesReturnLineInput(saleLineId: line.id, qtyBaseMicro: 1000000),
        ],
        reason: 'retur pertama',
      ),
    );

    await expectLater(
      SalesReturnService(db).createReturn(
        SalesReturnInput(
          saleId: sale.saleId,
          lines: [SalesReturnLineInput(saleLineId: line.id, qtyBaseMicro: 1)],
          reason: 'retur kedua',
        ),
      ),
      throwsA(
        isA<Failure>().having(
          (f) => f.code,
          'code',
          ErrorCodes.invalidQuantity,
        ),
      ),
    );
  });

  test('credit return reduces receivable and refunds paid portion', () async {
    final customerId = await CustomerRepository(
      db,
    ).create(businessId: businessId, name: 'Pelanggan');
    final sale = await SalesService(db).checkout(
      CheckoutInput(
        lines: [
          SaleLineInput(
            productId: productId,
            qtyMicro: 1000000,
            unitPriceMinor: 12000,
          ),
        ],
        accountId: accountId,
        customerId: customerId,
        paidNowMinor: 5000,
      ),
    );
    final line = (await db.select(db.saleLines).get()).single;

    await SalesReturnService(db).createReturn(
      SalesReturnInput(
        saleId: sale.saleId,
        lines: [
          SalesReturnLineInput(saleLineId: line.id, qtyBaseMicro: 1000000),
        ],
        reason: 'retur kredit',
      ),
    );

    final receivable = (await db.select(db.receivables).get()).single;
    expect(receivable.remainingAmountMinor, 0);
    expect(
      (await db.select(db.payments).get()).where((p) => p.purpose == 'refund'),
      hasLength(1),
    );
    expect((await db.select(db.accounts).get()).single.currentBalanceMinor, 0);
  });
}
