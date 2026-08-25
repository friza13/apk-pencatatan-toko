// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spike_database.dart';

// ignore_for_file: type=lint
class $SpikeCategoriesTable extends SpikeCategories
    with TableInfo<$SpikeCategoriesTable, SpikeCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeCategoriesTable(this.attachedDatabase, [this._alias]);
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
    Insertable<SpikeCategory> instance, {
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
  SpikeCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeCategory(
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
  $SpikeCategoriesTable createAlias(String alias) {
    return $SpikeCategoriesTable(attachedDatabase, alias);
  }
}

class SpikeCategory extends DataClass implements Insertable<SpikeCategory> {
  final int id;
  final String name;
  const SpikeCategory({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  SpikeCategoriesCompanion toCompanion(bool nullToAbsent) {
    return SpikeCategoriesCompanion(id: Value(id), name: Value(name));
  }

  factory SpikeCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeCategory(
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

  SpikeCategory copyWith({int? id, String? name}) =>
      SpikeCategory(id: id ?? this.id, name: name ?? this.name);
  SpikeCategory copyWithCompanion(SpikeCategoriesCompanion data) {
    return SpikeCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeCategory(')
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
      (other is SpikeCategory &&
          other.id == this.id &&
          other.name == this.name);
}

class SpikeCategoriesCompanion extends UpdateCompanion<SpikeCategory> {
  final Value<int> id;
  final Value<String> name;
  const SpikeCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  SpikeCategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<SpikeCategory> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  SpikeCategoriesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return SpikeCategoriesCompanion(id: id ?? this.id, name: name ?? this.name);
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
    return (StringBuffer('SpikeCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SpikeProductsTable extends SpikeProducts
    with TableInfo<$SpikeProductsTable, SpikeProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikeProductsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, categoryId, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikeProduct> instance, {
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
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikeProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikeProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SpikeProductsTable createAlias(String alias) {
    return $SpikeProductsTable(attachedDatabase, alias);
  }
}

class SpikeProduct extends DataClass implements Insertable<SpikeProduct> {
  final int id;
  final String name;
  final int? categoryId;

  /// Added in spike schema v2 to prove migration.
  final String? note;
  const SpikeProduct({
    required this.id,
    required this.name,
    this.categoryId,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SpikeProductsCompanion toCompanion(bool nullToAbsent) {
    return SpikeProductsCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SpikeProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikeProduct(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<int?>(categoryId),
      'note': serializer.toJson<String?>(note),
    };
  }

  SpikeProduct copyWith({
    int? id,
    String? name,
    Value<int?> categoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => SpikeProduct(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note.present ? note.value : this.note,
  );
  SpikeProduct copyWithCompanion(SpikeProductsCompanion data) {
    return SpikeProduct(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikeProduct(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, categoryId, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikeProduct &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.note == this.note);
}

class SpikeProductsCompanion extends UpdateCompanion<SpikeProduct> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> categoryId;
  final Value<String?> note;
  const SpikeProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
  });
  SpikeProductsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SpikeProduct> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? categoryId,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
    });
  }

  SpikeProductsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? categoryId,
    Value<String?>? note,
  }) {
    return SpikeProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
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
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikeProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpikeDatabase extends GeneratedDatabase {
  _$SpikeDatabase(QueryExecutor e) : super(e);
  $SpikeDatabaseManager get managers => $SpikeDatabaseManager(this);
  late final $SpikeCategoriesTable spikeCategories = $SpikeCategoriesTable(
    this,
  );
  late final $SpikeProductsTable spikeProducts = $SpikeProductsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    spikeCategories,
    spikeProducts,
  ];
}

typedef $$SpikeCategoriesTableCreateCompanionBuilder =
    SpikeCategoriesCompanion Function({Value<int> id, required String name});
typedef $$SpikeCategoriesTableUpdateCompanionBuilder =
    SpikeCategoriesCompanion Function({Value<int> id, Value<String> name});

class $$SpikeCategoriesTableFilterComposer
    extends Composer<_$SpikeDatabase, $SpikeCategoriesTable> {
  $$SpikeCategoriesTableFilterComposer({
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

class $$SpikeCategoriesTableOrderingComposer
    extends Composer<_$SpikeDatabase, $SpikeCategoriesTable> {
  $$SpikeCategoriesTableOrderingComposer({
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

class $$SpikeCategoriesTableAnnotationComposer
    extends Composer<_$SpikeDatabase, $SpikeCategoriesTable> {
  $$SpikeCategoriesTableAnnotationComposer({
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

class $$SpikeCategoriesTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabase,
          $SpikeCategoriesTable,
          SpikeCategory,
          $$SpikeCategoriesTableFilterComposer,
          $$SpikeCategoriesTableOrderingComposer,
          $$SpikeCategoriesTableAnnotationComposer,
          $$SpikeCategoriesTableCreateCompanionBuilder,
          $$SpikeCategoriesTableUpdateCompanionBuilder,
          (
            SpikeCategory,
            BaseReferences<
              _$SpikeDatabase,
              $SpikeCategoriesTable,
              SpikeCategory
            >,
          ),
          SpikeCategory,
          PrefetchHooks Function()
        > {
  $$SpikeCategoriesTableTableManager(
    _$SpikeDatabase db,
    $SpikeCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpikeCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => SpikeCategoriesCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  SpikeCategoriesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabase,
      $SpikeCategoriesTable,
      SpikeCategory,
      $$SpikeCategoriesTableFilterComposer,
      $$SpikeCategoriesTableOrderingComposer,
      $$SpikeCategoriesTableAnnotationComposer,
      $$SpikeCategoriesTableCreateCompanionBuilder,
      $$SpikeCategoriesTableUpdateCompanionBuilder,
      (
        SpikeCategory,
        BaseReferences<_$SpikeDatabase, $SpikeCategoriesTable, SpikeCategory>,
      ),
      SpikeCategory,
      PrefetchHooks Function()
    >;
typedef $$SpikeProductsTableCreateCompanionBuilder =
    SpikeProductsCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> categoryId,
      Value<String?> note,
    });
typedef $$SpikeProductsTableUpdateCompanionBuilder =
    SpikeProductsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> categoryId,
      Value<String?> note,
    });

class $$SpikeProductsTableFilterComposer
    extends Composer<_$SpikeDatabase, $SpikeProductsTable> {
  $$SpikeProductsTableFilterComposer({
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

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikeProductsTableOrderingComposer
    extends Composer<_$SpikeDatabase, $SpikeProductsTable> {
  $$SpikeProductsTableOrderingComposer({
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

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikeProductsTableAnnotationComposer
    extends Composer<_$SpikeDatabase, $SpikeProductsTable> {
  $$SpikeProductsTableAnnotationComposer({
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

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$SpikeProductsTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabase,
          $SpikeProductsTable,
          SpikeProduct,
          $$SpikeProductsTableFilterComposer,
          $$SpikeProductsTableOrderingComposer,
          $$SpikeProductsTableAnnotationComposer,
          $$SpikeProductsTableCreateCompanionBuilder,
          $$SpikeProductsTableUpdateCompanionBuilder,
          (
            SpikeProduct,
            BaseReferences<_$SpikeDatabase, $SpikeProductsTable, SpikeProduct>,
          ),
          SpikeProduct,
          PrefetchHooks Function()
        > {
  $$SpikeProductsTableTableManager(
    _$SpikeDatabase db,
    $SpikeProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpikeProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpikeProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpikeProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SpikeProductsCompanion(
                id: id,
                name: name,
                categoryId: categoryId,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SpikeProductsCompanion.insert(
                id: id,
                name: name,
                categoryId: categoryId,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikeProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabase,
      $SpikeProductsTable,
      SpikeProduct,
      $$SpikeProductsTableFilterComposer,
      $$SpikeProductsTableOrderingComposer,
      $$SpikeProductsTableAnnotationComposer,
      $$SpikeProductsTableCreateCompanionBuilder,
      $$SpikeProductsTableUpdateCompanionBuilder,
      (
        SpikeProduct,
        BaseReferences<_$SpikeDatabase, $SpikeProductsTable, SpikeProduct>,
      ),
      SpikeProduct,
      PrefetchHooks Function()
    >;

class $SpikeDatabaseManager {
  final _$SpikeDatabase _db;
  $SpikeDatabaseManager(this._db);
  $$SpikeCategoriesTableTableManager get spikeCategories =>
      $$SpikeCategoriesTableTableManager(_db, _db.spikeCategories);
  $$SpikeProductsTableTableManager get spikeProducts =>
      $$SpikeProductsTableTableManager(_db, _db.spikeProducts);
}
