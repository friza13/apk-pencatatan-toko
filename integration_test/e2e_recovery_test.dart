import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/backup/data/backup_service.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

/// P11 Hardening — end-to-end recovery test on the real device/emulator:
///
///   seed data -> jual -> backup .nkb -> hapus semua produk ->
///   restore dari .nkb -> verifikasi data & stok kembali utuh.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late File dbFile;
  late AppDatabase db;
  late ProductRepository products;
  late InventoryService inventory;
  late SalesService sales;
  late BackupService backup;
  late int businessId;

  Future<int> stockOf(int pid) async =>
      (await (db.select(db.products)..where((t) => t.id.equals(pid)))
            .getSingle())
          .stockQuantityMicro;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('nk_e2e');
    dbFile = File('${tmpDir.path}/e2e.db');
    db = AppDatabase(NativeDatabase(
      dbFile,
      setup: (rawDb) => rawDb
        ..execute("PRAGMA key = 'e2e-pass'")
        ..execute('PRAGMA foreign_keys = ON'),
    ));
    products = ProductRepository(db);
    inventory = InventoryService(db);
    sales = SalesService(db);
    backup = BackupService(db);

    final ownerId =
        await db.into(db.owners).insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko E2E'),
        );
    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    final kas = await db.into(db.accounts).insert(
          AccountsCompanion.insert(businessId: businessId, name: 'Kas'),
        );
    assert(kas > 0);
  });

  tearDown(() async {
    await db.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('E2E: jual -> backup -> wipe produk -> restore -> verifikasi',
      () async {
    // ---- Seed 2 produk + stok awal.
    final pcs = (await (ReferenceRepository(db)).unitByCode(businessId, 'pcs'))!.id;
    final kopi = await products.createProduct(ProductDraft(
      businessId: businessId,
      name: 'Kopi Arabica',
      baseUnitId: pcs,
      costPriceMinor: 8000,
      salePriceMinor: 12000,
      minStockMicro: 5000000,
    ));
    final gula = await products.createProduct(ProductDraft(
      businessId: businessId,
      name: 'Gula Pasir',
      baseUnitId: pcs,
      costPriceMinor: 6000,
      salePriceMinor: 9000,
    ));
    await inventory.setOpeningBalance(kopi, 20000000); // 20
    await inventory.setOpeningBalance(gula, 30000000); // 30

    // ---- Jual 3 Kopi (lunas).
    final out = await sales.checkout(CheckoutInput(
      lines: [
        SaleLineInput(productId: kopi, qtyMicro: 3000000, unitPriceMinor: 12000),
      ],
      accountId: (await (db.select(db.accounts)).get()).first.id,
      paidNowMinor: 36000,
    ));
    expect(await stockOf(kopi), 17000000);

    // ---- Backup .nkb.
    final nkbPath = '${tmpDir.path}/e2e.nkb';
    await backup.createBackup(
      sourceDbPath: dbFile.path.replaceFirst('.db', '.sqlite'),
      saveToPath: nkbPath,
      password: 'pw-e2e-123',
      schemaVersion: db.schemaVersion,
      appVersion: '1.0.0-dev',
      dbPassphrase: 'e2e-pass',
      recordCounts: {
        'products':
            (await db.select(db.products).get()).length,
        'sales': (await db.select(db.sales).get()).length,
      },
      dbKeyHex: 'ab' * 32,
    );

    // ---- "Bencana": database hilang total (HP rusak).
    // FK memblokir delete rows; simulasi realistis = hapus file db,
    // lalu buat database kosong baru pada path yang sama.
    await db.close();
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    final fresh = AppDatabase(NativeDatabase(
      dbFile,
      setup: (rawDb) => rawDb
        ..execute("PRAGMA key = 'e2e-pass'")
        ..execute('PRAGMA foreign_keys = ON'),
    ));
    expect((await fresh.select(fresh.products).get()), isEmpty);
    await fresh.close();

    // ---- Restore dari .nkb via staging + atomic swap.
    final preview =
        await backup.inspect(nkbFile: File(nkbPath), password: 'pw-e2e-123');
    expect(preview.recordCounts['products'], 2);
    await backup.applyRestore(
        preview: preview,
        targetDbPath: dbFile.path,
        dbPassphrase: 'e2e-pass');

    // ---- Buka ulang dan verifikasi.
    final restored = AppDatabase(NativeDatabase(
      dbFile,
      setup: (rawDb) => rawDb
        ..execute("PRAGMA key = 'e2e-pass'")
        ..execute('PRAGMA foreign_keys = ON'),
    ));
    try {
      final prods = await restored.select(restored.products).get();
      expect(prods.map((p) => p.name), containsAll(['Kopi Arabica', 'Gula Pasir']));

      final salesRows = await restored.select(restored.sales).get();
      expect(salesRows.single.number, out.number);
      expect(salesRows.single.grandTotalMinor, 36000);

      // Stok cache ikut pulih (17 - 3 terjual tersimpan di backup).
      final kopiRow = await (restored.select(restored.products)
            ..where((t) => t.id.equals(kopi)))
          .getSingle();
      expect(kopiRow.stockQuantityMicro, 17000000);

      final movements =
          await restored.select(restored.stockMovements).get();
      expect(movements.length, greaterThanOrEqualTo(3)); // opening x2 + sale
    } finally {
      await restored.close();
    }
  });
}
