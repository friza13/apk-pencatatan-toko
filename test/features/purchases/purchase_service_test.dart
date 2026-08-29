import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/purchases/data/purchase_service.dart';

void main() {
  late AppDatabase db;
  late int businessId;
  late int accountId;
  late int supplierId;
  late int productId;
  late int pcsUnitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'Owner'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'));

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    pcsUnitId = (await refs.unitByCode(businessId, 'pcs'))!.id;

    accountId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            businessId: businessId,
            name: 'Kas',
            currentBalanceMinor: const Value(1000000),
          ),
        );

    supplierId = await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            businessId: businessId,
            name: 'PT Sumber Pangan',
          ),
        );

    productId = await ProductRepository(db).createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Minyak Goreng 1L',
        baseUnitId: pcsUnitId,
        costPriceMinor: 8000,
        salePriceMinor: 14000,
      ),
    );

    // Initial stock: 10 pcs @ Rp8.000
    await InventoryService(db).setOpeningBalance(productId, 10000000);
  });

  tearDown(() => db.close());

  group('PurchaseService', () {
    test('creates and finalizes purchase with stock increase and WAC update', () async {
      final service = PurchaseService(db);

      // Incoming: 10 pcs @ Rp10.000 (Subtotal = Rp100.000, Paid = Rp100.000)
      final purchase = await service.createAndFinalizePurchase(
        businessId: businessId,
        supplierId: supplierId,
        lines: [
          PurchaseLineInput(
            productId: productId,
            qtyMicro: 10000000, // 10 pcs
            unitId: pcsUnitId,
            conversionFactorMicro: 1000000,
            unitCostMinor: 10000,
          ),
        ],
        accountId: accountId,
        paidNowMinor: 100000,
      );

      expect(purchase.status, 'finalized');
      expect(purchase.grandTotalMinor, 100000);
      expect(purchase.paidTotalMinor, 100000);
      expect(purchase.dueTotalMinor, 0);

      // Verify stock increased from 10 to 20 pcs
      final product = await (db.select(db.products)..where((t) => t.id.equals(productId))).getSingle();
      expect(product.stockQuantityMicro, 20000000);

      // Verify WAC cost updated: (10 * 8000 + 10 * 10000) / 20 = 180000 / 20 = 9000
      expect(product.costPriceMinor, 9000);

      // Verify account balance deducted by Rp100.000: 1.000.000 - 100.000 = 900.000
      final account = await (db.select(db.accounts)..where((t) => t.id.equals(accountId))).getSingle();
      expect(account.currentBalanceMinor, 900000);
    });

    test('records accounts payable (dueTotalMinor) when purchase is partially paid', () async {
      final service = PurchaseService(db);

      // Total = Rp100.000, Paid = Rp40.000 -> Due = Rp60.000 (Hutang)
      final purchase = await service.createAndFinalizePurchase(
        businessId: businessId,
        supplierId: supplierId,
        lines: [
          PurchaseLineInput(
            productId: productId,
            qtyMicro: 10000000,
            unitId: pcsUnitId,
            conversionFactorMicro: 1000000,
            unitCostMinor: 10000,
          ),
        ],
        accountId: accountId,
        paidNowMinor: 40000,
      );

      expect(purchase.grandTotalMinor, 100000);
      expect(purchase.paidTotalMinor, 40000);
      expect(purchase.dueTotalMinor, 60000);

      // Verify account balance deducted only by paidNowMinor (40.000)
      final account = await (db.select(db.accounts)..where((t) => t.id.equals(accountId))).getSingle();
      expect(account.currentBalanceMinor, 960000);
    });
  });
}
