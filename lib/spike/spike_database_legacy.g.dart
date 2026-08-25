// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spike_database_legacy.dart';

// ignore_for_file: type=lint
class $SpikeCategoriesV1SeedTable extends SpikeCategoriesV1Seed
    with TableInfo<$SpikeCategoriesV1SeedTable, SpikeCategoriesV1SeedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeCategoriesV1SeedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeCategoriesV1SeedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeCategoriesV1SeedData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeCategoriesV1SeedData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $SpikeCategoriesV1SeedTable createAlias(String alias) {
    return $SpikeCategoriesV1SeedTable(attachedDatabase, alias);
  }
}

class SpikeCategoriesV1SeedData extends DataClass
    implements Insertable<SpikeCategoriesV1SeedData> {
  final int id;
  final String name;
  const SpikeCategoriesV1SeedData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  SpikeCategoriesV1SeedCompanion toCompanion(bool nullToAbsent) {
    return SpikeCategoriesV1SeedCompanion(id: Value(id), name: Value(name));
  }

  factory SpikeCategoriesV1SeedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeCategoriesV1SeedData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  SpikeCategoriesV1SeedData copyWith({int? id, String? name}) =>
      SpikeCategoriesV1SeedData(id: id ?? this.id, name: name ?? this.name);
  SpikeCategoriesV1SeedData copyWithCompanion(
    SpikeCategoriesV1SeedCompanion data,
  ) {
    return SpikeCategoriesV1SeedData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeCategoriesV1SeedData(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeCategoriesV1SeedData &&
          other.id == this.id &&
          other.name == this.name);
}

class SpikeCategoriesV1SeedCompanion
    extends UpdateCompanion<SpikeCategoriesV1SeedData> {
  final Value<int> id;
  final Value<String> name;
  const SpikeCategoriesV1SeedCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  SpikeCategoriesV1SeedCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<SpikeCategoriesV1SeedData> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  SpikeCategoriesV1SeedCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
  }) {
    return SpikeCategoriesV1SeedCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeCategoriesV1SeedCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SpikeProductsV1SeedTable extends SpikeProductsV1Seed
    with TableInfo<$SpikeProductsV1SeedTable, SpikeProductsV1SeedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeProductsV1SeedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeProductsV1SeedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeProductsV1SeedData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeProductsV1SeedData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $SpikeProductsV1SeedTable createAlias(String alias) {
    return $SpikeProductsV1SeedTable(attachedDatabase, alias);
  }
}

class SpikeProductsV1SeedData extends DataClass
    implements Insertable<SpikeProductsV1SeedData> {
  final int id;
  final String name;
  const SpikeProductsV1SeedData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  SpikeProductsV1SeedCompanion toCompanion(bool nullToAbsent) {
    return SpikeProductsV1SeedCompanion(id: Value(id), name: Value(name));
  }

  factory SpikeProductsV1SeedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeProductsV1SeedData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  SpikeProductsV1SeedData copyWith({int? id, String? name}) =>
      SpikeProductsV1SeedData(id: id ?? this.id, name: name ?? this.name);
  SpikeProductsV1SeedData copyWithCompanion(SpikeProductsV1SeedCompanion data) {
    return SpikeProductsV1SeedData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeProductsV1SeedData(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeProductsV1SeedData &&
          other.id == this.id &&
          other.name == this.name);
}

class SpikeProductsV1SeedCompanion
    extends UpdateCompanion<SpikeProductsV1SeedData> {
  final Value<int> id;
  final Value<String> name;
  const SpikeProductsV1SeedCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  SpikeProductsV1SeedCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<SpikeProductsV1SeedData> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  SpikeProductsV1SeedCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return SpikeProductsV1SeedCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeProductsV1SeedCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpikeDatabaseLegacy extends GeneratedDatabase {
  _$SpikeDatabaseLegacy(QueryExecutor e) : super(e);
  $SpikeDatabaseLegacyManager get managers => $SpikeDatabaseLegacyManager(this);
  late final $SpikeCategoriesV1SeedTable spikeCategoriesV1Seed =
      $SpikeCategoriesV1SeedTable(this);
  late final $SpikeProductsV1SeedTable spikeProductsV1Seed =
      $SpikeProductsV1SeedTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spikeCategoriesV1Seed,
    spikeProductsV1Seed,
  ];
}

typedef $$SpikeCategoriesV1SeedTableCreateCompanionBuilder =
    SpikeCategoriesV1SeedCompanion Function({
      Value<int> id,
      required String name,
    });
typedef $$SpikeCategoriesV1SeedTableUpdateCompanionBuilder =
    SpikeCategoriesV1SeedCompanion Function({
      Value<int> id,
      Value<String> name,
    });

class $$SpikeCategoriesV1SeedTableFilterComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeCategoriesV1SeedTable> {
  $$SpikeCategoriesV1SeedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeCategoriesV1SeedTableOrderingComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeCategoriesV1SeedTable> {
  $$SpikeCategoriesV1SeedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeCategoriesV1SeedTableAnnotationComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeCategoriesV1SeedTable> {
  $$SpikeCategoriesV1SeedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$SpikeCategoriesV1SeedTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabaseLegacy,
          $SpikeCategoriesV1SeedTable,
          SpikeCategoriesV1SeedData,
          $$SpikeCategoriesV1SeedTableFilterComposer,
          $$SpikeCategoriesV1SeedTableOrderingComposer,
          $$SpikeCategoriesV1SeedTableAnnotationComposer,
          $$SpikeCategoriesV1SeedTableCreateCompanionBuilder,
          $$SpikeCategoriesV1SeedTableUpdateCompanionBuilder,
          (
            SpikeCategoriesV1SeedData,
            BaseReferences<
              _$SpikeDatabaseLegacy,
              $SpikeCategoriesV1SeedTable,
              SpikeCategoriesV1SeedData
            >,
          ),
          SpikeCategoriesV1SeedData,
          PrefetchHooks Function()
        > {
  $$SpikeCategoriesV1SeedTableTableManager(
    _$SpikeDatabaseLegacy db,
    $SpikeCategoriesV1SeedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeCategoriesV1SeedTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SpikeCategoriesV1SeedTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SpikeCategoriesV1SeedTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => SpikeCategoriesV1SeedCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  SpikeCategoriesV1SeedCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeCategoriesV1SeedTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabaseLegacy,
      $SpikeCategoriesV1SeedTable,
      SpikeCategoriesV1SeedData,
      $$SpikeCategoriesV1SeedTableFilterComposer,
      $$SpikeCategoriesV1SeedTableOrderingComposer,
      $$SpikeCategoriesV1SeedTableAnnotationComposer,
      $$SpikeCategoriesV1SeedTableCreateCompanionBuilder,
      $$SpikeCategoriesV1SeedTableUpdateCompanionBuilder,
      (
        SpikeCategoriesV1SeedData,
        BaseReferences<
          _$SpikeDatabaseLegacy,
          $SpikeCategoriesV1SeedTable,
          SpikeCategoriesV1SeedData
        >,
      ),
      SpikeCategoriesV1SeedData,
      PrefetchHooks Function()
    >;
typedef $$SpikeProductsV1SeedTableCreateCompanionBuilder =
    SpikeProductsV1SeedCompanion Function({
      Value<int> id,
      required String name,
    });
typedef $$SpikeProductsV1SeedTableUpdateCompanionBuilder =
    SpikeProductsV1SeedCompanion Function({Value<int> id, Value<String> name});

class $$SpikeProductsV1SeedTableFilterComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeProductsV1SeedTable> {
  $$SpikeProductsV1SeedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeProductsV1SeedTableOrderingComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeProductsV1SeedTable> {
  $$SpikeProductsV1SeedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeProductsV1SeedTableAnnotationComposer
    extends Composer<_$SpikeDatabaseLegacy, $SpikeProductsV1SeedTable> {
  $$SpikeProductsV1SeedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$SpikeProductsV1SeedTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabaseLegacy,
          $SpikeProductsV1SeedTable,
          SpikeProductsV1SeedData,
          $$SpikeProductsV1SeedTableFilterComposer,
          $$SpikeProductsV1SeedTableOrderingComposer,
          $$SpikeProductsV1SeedTableAnnotationComposer,
          $$SpikeProductsV1SeedTableCreateCompanionBuilder,
          $$SpikeProductsV1SeedTableUpdateCompanionBuilder,
          (
            SpikeProductsV1SeedData,
            BaseReferences<
              _$SpikeDatabaseLegacy,
              $SpikeProductsV1SeedTable,
              SpikeProductsV1SeedData
            >,
          ),
          SpikeProductsV1SeedData,
          PrefetchHooks Function()
        > {
  $$SpikeProductsV1SeedTableTableManager(
    _$SpikeDatabaseLegacy db,
    $SpikeProductsV1SeedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeProductsV1SeedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeProductsV1SeedTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SpikeProductsV1SeedTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => SpikeProductsV1SeedCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  SpikeProductsV1SeedCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeProductsV1SeedTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabaseLegacy,
      $SpikeProductsV1SeedTable,
      SpikeProductsV1SeedData,
      $$SpikeProductsV1SeedTableFilterComposer,
      $$SpikeProductsV1SeedTableOrderingComposer,
      $$SpikeProductsV1SeedTableAnnotationComposer,
      $$SpikeProductsV1SeedTableCreateCompanionBuilder,
      $$SpikeProductsV1SeedTableUpdateCompanionBuilder,
      (
        SpikeProductsV1SeedData,
        BaseReferences<
          _$SpikeDatabaseLegacy,
          $SpikeProductsV1SeedTable,
          SpikeProductsV1SeedData
        >,
      ),
      SpikeProductsV1SeedData,
      PrefetchHooks Function()
    >;

class $SpikeDatabaseLegacyManager {
  final _$SpikeDatabaseLegacy _db;
  $SpikeDatabaseLegacyManager(this._db);
  $$SpikeCategoriesV1SeedTableTableManager get spikeCategoriesV1Seed =>
      $$SpikeCategoriesV1SeedTableTableManager(_db, _db.spikeCategoriesV1Seed);
  $$SpikeProductsV1SeedTableTableManager get spikeProductsV1Seed =>
      $$SpikeProductsV1SeedTableTableManager(_db, _db.spikeProductsV1Seed);
}
