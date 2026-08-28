import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/settings/presentation/references_screen.dart';

void main() {
  testWidgets('adding from the Kategori tab creates a category', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'Owner'));
    final business = await db
        .into(db.businesses)
        .insertReturning(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Uji'),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentBusinessProvider.overrideWith((ref) async => business),
          referenceRepositoryProvider.overrideWith(
            (ref) async => ReferenceRepository(db),
          ),
          categoriesStreamProvider.overrideWith(
            (ref) => Stream.value(const <Category>[]),
          ),
          unitsStreamProvider.overrideWith(
            (ref) => Stream.value(const <Unit>[]),
          ),
        ],
        child: const MaterialApp(home: ReferencesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Kategori'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Minuman');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final categories = await (db.select(
      db.categories,
    )..where((t) => t.businessId.equals(business.id))).get();
    expect(categories.map((category) => category.name), contains('Minuman'));
  });
}
