import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/sales/data/sales_return_service.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

void main() {
  late AppDatabase db;
  late int productId;
  late int variantId;
  late int accountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    final businessId = await db
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
        name: 'Kaos',
        baseUnitId: pcs,
        costPriceMinor: 4000,
        salePriceMinor: 10000,
        variants: [VariantInput(name: 'Merah', salePriceMinor: 10000)],
      ),
    );
    variantId = (await (db.select(
      db.productVariants,
    )..where((t) => t.productId.equals(productId))).getSingle()).id;
    await (db.update(db.products)..where((t) => t.id.equals(productId))).write(
      const ProductsCompanion(stockQuantityMicro: Value(9000000)),
    );
    await (db.update(
      db.productVariants,
    )..where((t) => t.id.equals(variantId))).write(
      const ProductVariantsCompanion(stockQuantityMicro: Value(2000000)),
    );
  });

  tearDown(() => db.close());

  test(
    'variant checkout and return use variant stock, not parent stock',
    () async {
      final service = SalesService(db);
      final sale = await service.checkout(
        CheckoutInput(
          lines: [
            SaleLineInput(
              productId: productId,
              variantId: variantId,
              qtyMicro: 1000000,
              unitPriceMinor: 10000,
            ),
          ],
          accountId: accountId,
          paidNowMinor: 10000,
        ),
      );

      expect(
        (await (db.select(
              db.products,
            )..where((t) => t.id.equals(productId))).getSingle())
            .stockQuantityMicro,
        9000000,
      );
      expect(
        (await (db.select(
              db.productVariants,
            )..where((t) => t.id.equals(variantId))).getSingle())
            .stockQuantityMicro,
        1000000,
      );
      final movement = (await (db.select(
        db.stockMovements,
      )..where((t) => t.movementType.equals('sale_out'))).getSingle());
      expect(movement.variantId, variantId);

      final line = (await db.select(db.saleLines).getSingle());
      await SalesReturnService(db).createReturn(
        SalesReturnInput(
          saleId: sale.saleId,
          lines: [
            SalesReturnLineInput(saleLineId: line.id, qtyBaseMicro: 1000000),
          ],
          reason: 'retur varian',
        ),
      );
      expect(
        (await (db.select(
              db.productVariants,
            )..where((t) => t.id.equals(variantId))).getSingle())
            .stockQuantityMicro,
        2000000,
      );
      expect(
        (await (db.select(
              db.products,
            )..where((t) => t.id.equals(productId))).getSingle())
            .stockQuantityMicro,
        9000000,
      );
    },
  );
}
