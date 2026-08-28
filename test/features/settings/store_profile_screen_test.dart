import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/security/providers.dart';
import 'package:notakit/features/settings/presentation/store_profile_screen.dart';

void main() {
  testWidgets('StoreProfileScreen loads existing data and updates business', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'Budi Owner'));
    final business = await db
        .into(db.businesses)
        .insertReturning(
          BusinessesCompanion.insert(
            ownerId: ownerId,
            name: 'Toko Lama',
            phone: const Value('08123456789'),
            address: const Value('Jl. Melati No. 1'),
            footerNote: const Value('Terima kasih atas kunjungannya!'),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) async => db),
          currentBusinessProvider.overrideWith((ref) async => business),
        ],
        child: const MaterialApp(home: StoreProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial values
    expect(find.text('Toko Lama'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);
    expect(find.text('Jl. Melati No. 1'), findsOneWidget);
    expect(find.text('Terima kasih atas kunjungannya!'), findsOneWidget);

    // Edit store name
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama Toko *'),
      'Toko Baru Jaya',
    );
    // Edit footer note
    await tester.enterText(
      find.widgetWithText(TextField, 'Catatan Kaki Struk'),
      'Barang yang dibeli tidak dapat ditukar.',
    );

    // Tap Simpan
    await tester.tap(find.text('Simpan Pengaturan'));
    await tester.pumpAndSettle();

    // Verify in database
    final updated = await (db.select(
      db.businesses,
    )..where((t) => t.id.equals(business.id))).getSingle();
    expect(updated.name, 'Toko Baru Jaya');
    expect(updated.footerNote, 'Barang yang dibeli tidak dapat ditukar.');
  });
}
