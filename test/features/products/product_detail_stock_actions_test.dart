import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/units/quantity.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/products/presentation/product_detail_screen.dart';
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
    'ProductDetailScreen renders Atur Stok and Kartu Stok buttons and adjusts stock',
    (tester) async {
      final repo = ProductRepository(db);
      final prodId = await repo.createProduct(
        ProductDraft(
          businessId: businessId,
          name: 'Susu UHT',
          baseUnitId: baseUnitId,
          costPriceMinor: 4000,
          salePriceMinor: 6000,
          initialStockMicro: 10 * quantityScale,
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
          child: MaterialApp(
            home: ProductDetailScreen(productId: prodId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atur Stok'), findsOneWidget);
      expect(find.text('Kartu Stok'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // Tap Atur Stok
      await tester.tap(find.text('Atur Stok'));
      await tester.pumpAndSettle();

      // Bottom sheet open
      expect(find.text('Atur Stok — Susu UHT'), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);

      // Enter +5
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah tambah (+)'), '5');
      await tester.tap(find.text('Simpan Perubahan Stok'));
      await tester.pumpAndSettle();

      // Verify updated stock in detail view (15)
      expect(find.text('15'), findsOneWidget);
    },
  );
}
