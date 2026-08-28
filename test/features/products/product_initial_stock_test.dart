import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/units/quantity.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/products/presentation/product_form_screen.dart';
import 'package:notakit/features/security/providers.dart';

void main() {
  late AppDatabase db;
  late int businessId;
  late int baseUnitId;
  late Business business;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'Owner'));
    business = await db
        .into(db.businesses)
        .insertReturning(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Test'),
        );
    businessId = business.id;

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    baseUnitId = (await refs.unitByCode(businessId, 'pcs'))!.id;
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'ProductRepository.createProduct creates opening balance movement when initialStockMicro > 0',
    () async {
      final repo = ProductRepository(db);

      final prodId = await repo.createProduct(
        ProductDraft(
          businessId: businessId,
          name: 'Kulkul Coklat',
          baseUnitId: baseUnitId,
          costPriceMinor: 5000,
          salePriceMinor: 8000,
          initialStockMicro: 25 * quantityScale,
          variants: [
            VariantInput(
              name: 'Mini',
              salePriceMinor: 4000,
              initialStockMicro: 10 * quantityScale,
            ),
          ],
        ),
      );

      final product = await repo.byId(prodId);
      expect(product, isNotNull);
      expect(product!.stockQuantityMicro, 25 * quantityScale);

      final detail = await repo.detail(prodId);
      expect(detail!.variants.length, 1);
      expect(detail.variants.first.stockQuantityMicro, 10 * quantityScale);

      // Verify stock movements
      final movements = await (db.select(
        db.stockMovements,
      )..where((t) => t.productId.equals(prodId))).get();
      expect(movements.length, 2);
      expect(
        movements.any(
          (m) =>
              m.variantId == null &&
              m.qtyBaseMicro == 25 * quantityScale &&
              m.movementType == 'opening_balance',
        ),
        isTrue,
      );
      expect(
        movements.any(
          (m) =>
              m.variantId != null &&
              m.qtyBaseMicro == 10 * quantityScale &&
              m.movementType == 'opening_balance',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'ProductFormScreen shows initial stock field and saves opening balance',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          currentBusinessProvider.overrideWith((ref) async => business),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProductFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Fill form
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama produk *'),
        'Keripik Tempe',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Harga beli/modal'),
        '10000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Harga jual *'),
        '15000',
      );

      // Fill initial stock
      expect(find.widgetWithText(TextField, 'Stok awal'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Stok awal'), '50');

      // Submit
      final submitBtn = find.text('Simpan Produk');
      await tester.scrollUntilVisible(
        submitBtn,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify in DB
      final products = await (db.select(
        db.products,
      )..where((t) => t.name.equals('Keripik Tempe'))).get();
      expect(products.length, 1);
      expect(products.first.stockQuantityMicro, 50 * quantityScale);
    },
  );
}
