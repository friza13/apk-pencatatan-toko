import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/backup/data/backup_service.dart';
import 'package:notakit/features/backup/data/nkb_container.dart';
import 'package:notakit/features/backup/data/nkb_exceptions.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';

void main() {
  late Directory tmp;
  late File sourceDb;
  late AppDatabase db;
  late BackupService service;
  const appVersion = '0.1.0-dev';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nkbtest');
    sourceDb = File('${tmp.path}/source.db');
    db = AppDatabase(NativeDatabase(sourceDb));
    service = BackupService(db);

    // Seed minimal data: owner/business + 2 produk + 1 pelanggan.
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    final bid = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Uji'));

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(bid);
    final pcs = (await refs.unitByCode(bid, 'pcs'))!.id;

    final products = ProductRepository(db);
    await products.createProduct(
      ProductDraft(
        businessId: bid,
        name: 'Kopi',
        baseUnitId: pcs,
        salePriceMinor: 10000,
      ),
    );
    await products.createProduct(
      ProductDraft(
        businessId: bid,
        name: 'Gula',
        baseUnitId: pcs,
        salePriceMinor: 8000,
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<Map<String, int>> counts() async => {
    'products': await _count(db, 'products'),
    'customers': await _count(db, 'customers'),
    'sales': await _count(db, 'sales'),
  };

  test('create -> inspect -> apply restore roundtrip preserves data', () async {
    final nkb = await service.createBackup(
      sourceDbPath: sourceDb.path,
      saveToPath: '${tmp.path}/backup.nkb',
      password: 'rahasia123',
      schemaVersion: db.schemaVersion,
      dbPassphrase: '',
      appVersion: appVersion,
      recordCounts: await counts(),
      dbKeyHex: 'aa' * 32,
    );
    expect(await nkb.exists(), isTrue);
    expect(nkb.path.endsWith('.nkb'), isTrue);

    final preview = await service.inspect(nkbFile: nkb, password: 'rahasia123');
    expect(preview.schemaVersion, db.schemaVersion);
    expect(preview.recordCounts['products'], 2);
    expect(preview.dbKeyHex, 'aa' * 32);

    final targetPath = '${tmp.path}/restored.db';
    await service.applyRestore(
      preview: preview,
      targetDbPath: targetPath,
      dbPassphrase: '',
    );

    final restored = AppDatabase(NativeDatabase(File(targetPath)));
    try {
      final products = await restored.select(restored.products).get();
      expect(products.map((p) => p.name), containsAll(['Kopi', 'Gula']));
    } finally {
      await restored.close();
    }
  });

  test('restore rejects incomplete schema and cleans staging', () async {
    final incomplete = File('${tmp.path}/incomplete.db');
    await db.customStatement('VACUUM INTO ?', [incomplete.path]);
    final raw = sqlite3.sqlite3.open(incomplete.path);
    try {
      raw.execute('DROP TABLE marketplace_orders');
    } finally {
      raw.close();
    }

    final target = File('${tmp.path}/active.db');
    await target.writeAsBytes([9, 8, 7]);
    await expectLater(
      service.applyRestore(
        preview: RestorePreview(
          createdAtIso: '',
          schemaVersion: db.schemaVersion,
          recordCounts: const {},
          databaseBytes: await incomplete.readAsBytes(),
          dbKeyHex: 'dd' * 32,
        ),
        targetDbPath: target.path,
        dbPassphrase: '',
      ),
      throwsA(isA<BackupFormatException>()),
    );
    expect(await target.readAsBytes(), [9, 8, 7]);
    final leftovers = tmp
        .listSync()
        .where((entry) => entry.path.contains('.restore-'))
        .toList();
    expect(leftovers, isEmpty);
  });
  test('wrong password rejected at inspect', () async {
    final nkb = await service.createBackup(
      sourceDbPath: sourceDb.path,
      saveToPath: '${tmp.path}/b.nkb',
      password: 'benar123',
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      recordCounts: await counts(),
      dbKeyHex: 'bb' * 32,
      dbPassphrase: '',
    );

    await expectLater(
      service.inspect(nkbFile: nkb, password: 'salah456'),
      throwsA(isA<BackupWrongPasswordException>()),
    );
  });

  test('corrupted magic rejected', () async {
    final bytes =
        List<int>.from([0x00, 0x01, 0x02, 0x03]) + List<int>.filled(64, 7);
    final f = File('${tmp.path}/fake.nkb');
    await f.writeAsBytes(bytes);

    await expectLater(
      service.inspect(nkbFile: f, password: 'x'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('tampered payload fails checksum', () async {
    final nkb = await service.createBackup(
      sourceDbPath: sourceDb.path,
      saveToPath: '${tmp.path}/t.nkb',
      password: 'pw123456',
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      recordCounts: await counts(),
      dbKeyHex: 'cc' * 32,
      dbPassphrase: '',
    );

    final bytes = await nkb.readAsBytes();
    bytes[bytes.length - 20] ^= 0xFF; // flip a byte near the end
    await nkb.writeAsBytes(bytes);

    await expectLater(
      service.inspect(nkbFile: nkb, password: 'pw123456'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('schema_version newer than app rejected', () async {
    final bytes = <int>[...NkbContainer.magic, ...NkbContainer.u32(0)];
    final f = File('${tmp.path}/empty.nkb');
    await f.writeAsBytes(bytes);

    await expectLater(
      service.inspect(nkbFile: f, password: 'x'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('malformed encrypted payload is rejected as invalid backup', () async {
    final manifest = NkbContainer.buildManifest(
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
      recordCounts: const {},
      saltHex: '00' * 16,
      nonceHex: '00' * 12,
      kdfIterations: 1,
      checksumHex: NkbContainer.sha256Hex([1, 2, 3]),
    );
    final f = File('${tmp.path}/malformed.nkb');
    await f.writeAsBytes(
      NkbContainer.serialize(
        manifest: manifest,
        encryptedBlob: Uint8List.fromList([1, 2, 3]),
      ),
    );

    await expectLater(
      service.inspect(nkbFile: f, password: 'x'),
      throwsA(isA<BackupFormatException>()),
    );
  });
}

Future<int> _count(AppDatabase db, String t) async {
  final row = await db.customSelect('SELECT count(*) AS c FROM $t').getSingle();
  return row.data['c'] as int;
}
