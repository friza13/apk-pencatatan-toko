import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:notakit/spike/spike_database.dart';
import 'package:notakit/spike/spike_database_legacy.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// SQLCipher-compatible (SQLite3MultipleCiphers) technical spike.
///
/// Covers the 8 mandatory POC areas from the owner's amendment #2:
///   1. open encrypted database            (encrypted_opens_and_supports_crud)
///   2. Drift CRUD                         (encrypted_opens_and_supports_crud)
///   3. foreign keys                       (foreign_keys_are_enforced)
///   4. transactions                       (transactions_commit_and_rollback_atomically)
///   5. schema migration                   (migration_v1_to_v2_preserves_data)
///   6. app restart persistence            (data_survives_close_and_reopen)
///   7. Android build compatibility        (`flutter build apk --debug`)
///   8. backup/restore interaction         (byte_level_backup_restore_roundtrip)
/// plus wrong-passphrase rejection and plaintext-header detection.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Directory> documentsDir() => getApplicationDocumentsDirectory();

  Future<File> freshDbFile(String name) async {
    final dir = await documentsDir();
    final file = File(p.join(dir.path, name));
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (await f.exists()) {
        await f.delete();
      }
    }
    return file;
  }

  test('encrypted engine accepts PRAGMA key and serves queries', () async {
    // Note: this SQLite3MultipleCiphers build does not expose
    // PRAGMA cipher_version, so we verify the engine behaviorally: the
    // connection accepts a key and reads/writes normally. At-rest encryption
    // itself is proven by the plaintext-header and wrong-passphrase tests.
    final file = await freshDbFile('spike_engine.db');
    final db = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'pass'),
    );

    final rows = await db.customSelect('PRAGMA cipher_version').get();
    // ignore: avoid_print
    print('[SPIKE] cipher_version on this build = '
        '${rows.isEmpty ? '<not compiled in>' : rows.first.data.values.first}');

    await db
        .into(db.spikeCategories)
        .insert(SpikeCategoriesCompanion.insert(name: 'EngineProbe'));
    final count =
        await db.customSelect('SELECT count(*) AS c FROM spike_categories')
            .getSingle();
    expect(count.data['c'], 1);
    await db.close();
  });

  test('encrypted database opens and supports CRUD', () async {
    final file = await freshDbFile('spike_crud.db');
    final db = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'correct-pass'),
    );

    final categoryId =
        await db.into(db.spikeCategories).insert(SpikeCategoriesCompanion.insert(name: 'Minuman'));
    final productId = await db.into(db.spikeProducts).insert(
          SpikeProductsCompanion.insert(
            name: 'Kopi Arabica',
            categoryId: Value(categoryId),
            note: const Value('200 gram'),
          ),
        );

    final loaded = await (db.select(db.spikeProducts)
          ..where((t) => t.id.equals(productId)))
        .getSingle();
    expect(loaded.name, 'Kopi Arabica');
    expect(loaded.note, '200 gram');

    await (db.update(db.spikeProducts)..where((t) => t.id.equals(productId)))
        .write(const SpikeProductsCompanion(note: Value('250 gram')));
    final updated = await (db.select(db.spikeProducts)
          ..where((t) => t.id.equals(productId)))
        .getSingle();
    expect(updated.note, '250 gram');

    await (db.delete(db.spikeProducts)..where((t) => t.id.equals(productId)))
        .go();
    final remaining = await db.select(db.spikeProducts).get();
    expect(remaining, isEmpty);
    await db.close();
  });

  test('database file header is NOT plaintext SQLite magic', () async {
    final file = await freshDbFile('spike_header.db');
    final db = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'header-pass'),
    );
    await db
        .into(db.spikeCategories)
        .insert(SpikeCategoriesCompanion.insert(name: 'Makanan'));
    await db.close();

    final bytes = await file.readAsBytes();
    final magic = Uint8List.fromList('SQLite format 3'.codeUnits);
    bool startsWithPlaintextMagic() {
      if (bytes.length < magic.length) {
        return false;
      }
      for (var i = 0; i < magic.length; i++) {
        if (bytes[i] != magic[i]) {
          return false;
        }
      }
      return true;
    }

    expect(startsWithPlaintextMagic(), isFalse,
        reason: 'file at rest must be encrypted');
  });

  test('foreign keys are enforced', () async {
    final file = await freshDbFile('spike_fk.db');
    final db = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'fk-pass'),
    );

    // Force table creation, then inspect actual DDL.
    final ddl = await db.customSelect(
      "SELECT sql FROM sqlite_master WHERE name = 'spike_products'",
    ).getSingle();
    final String createSql = ddl.data['sql'] as String? ?? '';
    // ignore: avoid_print
    print('[SPIKE-FK] DDL: $createSql');

    final fkState =
        await db.customSelect('PRAGMA foreign_keys').getSingle();
    // ignore: avoid_print
    print('[SPIKE-FK] PRAGMA foreign_keys => ${fkState.data}');

    var constraintFailed = false;
    try {
      await db.into(db.spikeProducts).insert(
            SpikeProductsCompanion.insert(
              name: 'Orphan Product',
              categoryId: const Value(9999),
            ),
          );
    } catch (e) {
      constraintFailed = e.toString().contains('FOREIGN KEY');
    }

    expect(constraintFailed, isTrue,
        reason: 'product without valid category must be rejected; DDL was: '
            '$createSql');
    await db.close();
  });

  test('transactions commit and rollback atomically', () async {
    final file = await freshDbFile('spike_tx.db');
    final db = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'tx-pass'),
    );

    var rolledBack = false;
    try {
      await db.transaction(() async {
        await db.into(db.spikeCategories)
            .insert(SpikeCategoriesCompanion.insert(name: 'A'));
        throw Exception('deliberate failure inside transaction');
      });
    } on Exception {
      rolledBack = true;
    }
    expect(rolledBack, isTrue);
    expect(await db.select(db.spikeCategories).get(), isEmpty,
        reason: 'failed transaction must roll back fully');

    await db.transaction(() async {
      await db.into(db.spikeCategories)
          .insert(SpikeCategoriesCompanion.insert(name: 'B'));
      await db.into(db.spikeCategories)
          .insert(SpikeCategoriesCompanion.insert(name: 'C'));
    });
    expect(await db.select(db.spikeCategories).get().then((v) => v.length), 2);
    await db.close();
  });

  test('migration v1 to v2 preserves data', () async {
    final file = await freshDbFile('spike_migration.db');

    final legacy = SpikeDatabaseLegacy(
      openSpikeExecutor(file: file, passphrase: 'mig-pass'),
    );
    final legacyCatId =
        await legacy.into(legacy.spikeCategoriesV1Seed).insert(
              SpikeCategoriesV1SeedCompanion.insert(name: 'Legacy Cat'),
            );
    await legacy.into(legacy.spikeProductsV1Seed).insert(
          SpikeProductsV1SeedCompanion.insert(name: 'Legacy Product'),
        );
    await legacy.close();

    final migrated = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'mig-pass'),
    );
    final rows = await migrated.select(migrated.spikeProducts).get();
    expect(rows, hasLength(1));
    expect(rows.single.note, isNull);

    await (migrated.update(migrated.spikeProducts)).write(
      const SpikeProductsCompanion(note: Value('migrated')),
    );
    final after = await migrated.select(migrated.spikeProducts).getSingle();
    expect(after.name, 'Legacy Product');
    expect(after.categoryId, isNull);
    expect(after.note, 'migrated');

    final cats = await migrated.select(migrated.spikeCategories).get();
    expect(cats.single.id, legacyCatId);
    await migrated.close();
  });

  test('data survives close and reopen (restart persistence)', () async {
    final file = await freshDbFile('spike_restart.db');

    final first = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'restart-pass'),
    );
    await first.into(first.spikeCategories).insert(
          SpikeCategoriesCompanion.insert(name: 'Persisted'),
        );
    await first.close();

    final second = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'restart-pass'),
    );
    final names =
        await second.select(second.spikeCategories).get().then(
              (rows) => rows.map((r) => r.name).toList(),
            );
    expect(names, ['Persisted']);
    await second.close();
  });

  test('byte-level backup/restore roundtrip keeps data readable', () async {
    final dir = await documentsDir();
    final original = await freshDbFile('spike_backup.db');
    final backupCopy = File(p.join(dir.path, 'spike_backup.copy.nkb'));

    final writer = SpikeDatabase(
      openSpikeExecutor(file: original, passphrase: 'backup-pass'),
    );
    await writer.into(writer.spikeCategories).insert(
          SpikeCategoriesCompanion.insert(name: 'Backup Survivor'),
        );
    // Fold WAL into the main file so a single-file copy is complete.
    await writer.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await writer.close();

    await backupCopy.writeAsBytes(await original.readAsBytes());
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${original.path}$suffix');
      if (await f.exists()) {
        await f.delete();
      }
    }
    await original.writeAsBytes(await backupCopy.readAsBytes());

    final restored = SpikeDatabase(
      openSpikeExecutor(file: original, passphrase: 'backup-pass'),
    );
    final names =
        await restored.select(restored.spikeCategories).get().then(
              (rows) => rows.map((r) => r.name).toList(),
            );
    expect(names, ['Backup Survivor']);
    await restored.close();
    await backupCopy.delete();
  });

  test('wrong passphrase is rejected', () async {
    final file = await freshDbFile('spike_wrongpass.db');

    final creator = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'the-real-pass'),
    );
    await creator.into(creator.spikeCategories).insert(
          SpikeCategoriesCompanion.insert(name: 'Secret'),
        );
    await creator.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await creator.close();

    final intruder = SpikeDatabase(
      openSpikeExecutor(file: file, passphrase: 'totally-wrong'),
    );

    await expectLater(
      intruder.select(intruder.spikeCategories).get(),
      throwsA(anything),
      reason: 'SQLITE_NOTADB expected on wrong key',
    );
    await intruder.close();
  });
}
