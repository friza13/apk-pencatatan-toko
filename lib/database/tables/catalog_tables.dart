import 'package:drift/drift.dart';

import 'business_tables.dart';
import '../../core/time/utc.dart';
import 'column_mixins.dart';

/// Product categories with optional hierarchy.
@TableIndex(name: 'idx_categories_business', columns: {#businessId})
class Categories extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get parentId => integer().nullable().references(Categories, #id)();

  TextColumn get name => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Units of measure (pcs, dus, kg, ...).
class Units extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get code => text()();

  TextColumn get name => text()();

  TextColumn get symbol => text().nullable()();

  /// Decimal places used when displaying quantities in this unit.
  IntColumn get decimalScale => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {businessId, code},
      ];
}

/// Products: goods / service / non-stock (FR-PROD-001).
///
/// Stock columns are cached balances derived from `stock_movements`
/// (D-014) — the movement ledger remains the source of truth.
@TableIndex(name: 'idx_products_business_name', columns: {#businessId, #name})
@TableIndex(name: 'idx_products_business_sku', columns: {#businessId, #sku})
@TableIndex(
  name: 'idx_products_business_barcode',
  columns: {#businessId, #barcode},
)
@TableIndex(
  name: 'idx_products_business_active',
  columns: {#businessId, #isActive},
)
class Products extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  /// Nullable: many small sellers do not assign codes (D-021).
  TextColumn get sku => text().nullable()();

  TextColumn get barcode => text().nullable()();

  /// `goods`, `service`, `non_stock`.
  TextColumn get type => text()
      .withDefault(const Constant('goods'))
      .customConstraint("CHECK (type IN ('goods','service','non_stock'))")();

  TextColumn get photoPath => text().nullable()();

  TextColumn get videoPath => text().nullable()();

  IntColumn get baseUnitId => integer().references(Units, #id)();

  /// Current weighted average cost per base unit in minor units (G-02).
  IntColumn get costPriceMinor => integer().withDefault(const Constant(0))();

  IntColumn get salePriceMinor => integer().withDefault(const Constant(0))();

  IntColumn get wholesalePriceMinor => integer().nullable()();

  /// Cached stock balance in micro units — derived from movements (G-01).
  IntColumn get stockQuantityMicro =>
      integer().withDefault(const Constant(0))();

  /// Low-stock threshold in micro units.
  IntColumn get minStockMicro => integer().withDefault(const Constant(0))();

  IntColumn get maxStockMicro => integer().nullable()();

  BoolColumn get trackStock => boolean().withDefault(const Constant(true))();

  /// Shipping attributes (grams / milliliters as integer units — D-021).
  IntColumn get weightGrams => integer().nullable()();

  IntColumn get volumeMl => integer().nullable()();

  TextColumn get shippingNote => text().nullable()();

  TextColumn get marketplaceSkuTokopedia => text().nullable()();

  TextColumn get marketplaceSkuTiktok => text().nullable()();

  TextColumn get marketplaceSkuShopee => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get archivedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

/// Product variants with their own code/price/stock; inherit from parent via
/// nullable overrides (FR-PROD-002).
class ProductVariants extends Table with IdColumn, AuditColumns {
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get sku => text().nullable()();

  TextColumn get barcode => text().nullable()();

  IntColumn get costPriceMinor => integer().nullable()();

  IntColumn get salePriceMinor => integer().nullable()();

  IntColumn get stockQuantityMicro =>
      integer().withDefault(const Constant(0))();

  IntColumn get minStockMicro => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Alternative selling/purchasing units and conversion to base unit
/// (FR-PROD-003). Conversion uses micro-scaled integers (D-008): a factor of
/// 24 is stored as 24 × quantityScale.
class ProductUnits extends Table with IdColumn {
  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get unitId => integer().references(Units, #id)();

  /// How many base units one of this unit represents, scaled by
  /// quantityScale. Must be > 0.
  IntColumn get conversionToBaseMicro => integer()();

  IntColumn get salePriceOverrideMinor => integer().nullable()();

  IntColumn get purchasePriceOverrideMinor => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {productId, unitId},
      ];

  @override
  List<String> get customConstraints => const [
        'CHECK (conversion_to_base_micro > 0)',
      ];
}
