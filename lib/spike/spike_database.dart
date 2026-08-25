import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'spike_database.g.dart';

/// TEMPORARY technical-spike schema (docs/IMPLEMENTATION_PLAN.md Task S0–Sn).
/// Delete or replace with the real production database once the spike passes.
/// The v1 migration source lives in `spike_database_legacy.dart`.

class SpikeCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();
}

class SpikeProducts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get categoryId => integer().nullable()();

  /// Added in spike schema v2 to prove migration.
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const [
        'FOREIGN KEY (category_id) REFERENCES spike_categories(id)',
      ];
}

/// Current spike schema (v2).
@DriftDatabase(tables: [SpikeCategories, SpikeProducts])
class SpikeDatabase extends _$SpikeDatabase {
  SpikeDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(spikeProducts, spikeProducts.note);
          }
        },
      );
}

String _escapeSqlString(String value) => value.replaceAll("'", "''");

/// Opens a SQLCipher-compatible (SQLite3MultipleCiphers) encrypted executor.
///
/// Hard-fails when the bundled engine cannot encrypt — a misconfigured build
/// must never silently produce a plaintext database (D-003).
QueryExecutor openSpikeExecutor({
  required File file,
  required String passphrase,
}) {
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) => _setupEncrypted(rawDb, passphrase),
  );
}

void _setupEncrypted(sqlite3.Database rawDb, String passphrase) {
  // Note: this SQLite3MultipleCiphers build does NOT expose
  // `PRAGMA cipher_version`, so engine capability cannot be probed via
  // pragma. Encryption correctness is proven behaviorally by the spike tests
  // (plaintext-header detection + wrong-passphrase rejection).
  //
  // PRAGMA key must be the first statement touching the database.
  rawDb
    ..execute("PRAGMA key = '${_escapeSqlString(passphrase)}'")
    ..execute('PRAGMA foreign_keys = ON')
    ..execute('PRAGMA journal_mode = WAL')
    // Force real I/O immediately so a wrong passphrase fails right here
    // (SQLITE_NOTADB) instead of surfacing later mid-transaction.
    ..execute('SELECT count(*) FROM sqlite_master');
}
