import 'package:drift/drift.dart';

part 'spike_database_legacy.g.dart';

/// TEMPORARY spike schema v1 — seeds a migration source for
/// [SpikeDatabase] (v2). Physical table names match v2 so that ALTER TABLE
/// migration applies. Lives in its own file because drift_dev dedupes tables
/// sharing an SQL name within one library.

class SpikeCategoriesV1Seed extends Table {
  @override
  String get tableName => 'spike_categories';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();
}

class SpikeProductsV1Seed extends Table {
  @override
  String get tableName => 'spike_products';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();
}

@DriftDatabase(tables: [SpikeCategoriesV1Seed, SpikeProductsV1Seed])
class SpikeDatabaseLegacy extends _$SpikeDatabaseLegacy {
  SpikeDatabaseLegacy(super.e);

  @override
  int get schemaVersion => 1;
}
