import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/units/quantity.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/presentation/stock_screen.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
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

  testWidgets(
    'StockScreen allows tapping product and selecting variant to adjust stock',
    (tester) async {
      final repo = ProductRepository(db);
      await repo.createProduct(
        ProductDraft(
          businessId: businessId,
          name: 'Kaos Polos',
          baseUnitId: baseUnitId,
          costPriceMinor: 20000,
          salePriceMinor: 35000,
          initialStockMicro: 50 * quantityScale,
          variants: [
            VariantInput(
              name: 'Hitam M',
              salePriceMinor: 35000,
              initialStockMicro: 20 * quantityScale,
            ),
            VariantInput(
              name: 'Hitam L',
              salePriceMinor: 35000,
              initialStockMicro: 30 * quantityScale,
            ),
          ],
        ),
      );

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
          child: const MaterialApp(home: StockScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kaos Polos'), findsOneWidget);

      // Tap the list item
      await tester.tap(find.text('Kaos Polos'));
      await tester.pumpAndSettle();

      // Sheet opens with variant picker
      expect(find.text('Atur Stok — Kaos Polos'), findsOneWidget);
      expect(find.text('Pilih Varian'), findsOneWidget);

      // Select Hitam M
      await tester.tap(find.text('Semua / Produk Utama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hitam M (Stok: 20)').last);
      await tester.pumpAndSettle();

      // Add 10 to Hitam M
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah tambah (+)'),
        '10',
      );
      await tester.tap(find.text('Simpan Perubahan Stok'));
      await tester.pumpAndSettle();

      // Check variant stock in DB
      final variants = await db.select(db.productVariants).get();
      final hitamM = variants.firstWhere((v) => v.name == 'Hitam M');
      expect(hitamM.stockQuantityMicro, 30 * quantityScale);
    },
  );
}
