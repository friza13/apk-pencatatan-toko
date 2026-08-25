import 'package:drift/drift.dart';

import 'business_tables.dart';
import 'catalog_tables.dart';
import '../../core/time/utc.dart';
import 'column_mixins.dart';

/// Customer groups driving default pricing/terms (FR-PRICE-001).
class CustomerTypes extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  /// `percent` or `fixed` (minor units value).
  TextColumn get defaultDiscountType => text()
      .nullable()
      .customConstraint(
        'CHECK (default_discount_type IS NULL OR '
        "default_discount_type IN ('percent','fixed'))",
      )();

  IntColumn get defaultDiscountValue => integer().nullable()();

  IntColumn get defaultPriceTierId =>
      integer().nullable().references(PriceTiers, #id)();

  IntColumn get defaultPaymentTermDays =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Customers (FR section E).
@TableIndex(name: 'idx_customers_business_name', columns: {#businessId, #name})
@TableIndex(name: 'idx_customers_business_phone', columns: {#businessId, #phone})
class Customers extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get customerTypeId => integer()
      .nullable()
      .references(CustomerTypes, #id, onDelete: KeyAction.setNull)();

  IntColumn get salesmanId => integer()
      .nullable()
      .references(Salesmen, #id, onDelete: KeyAction.setNull)();

  TextColumn get name => text()();

  TextColumn get address => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get whatsapp => text().nullable()();

  TextColumn get email => text().nullable()();

  /// Maximum outstanding receivable allowed in minor units; 0 disables
  /// credit sales for this customer.
  IntColumn get creditLimitMinor => integer().withDefault(const Constant(0))();

  IntColumn get paymentTermDays => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Sales representatives (FR section H).
class Salesmen extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get code => text()();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {businessId, code},
      ];
}

/// Named price tiers (retail/grosir/...) with explicit priority.
class PriceTiers extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  /// Lower number = higher priority when tiers overlap.
  IntColumn get priority => integer().withDefault(const Constant(100))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Product price rules per tier / customer type / unit / variant / quantity
/// break. All nullable dimensions fall back to product base pricing.
class ProductPrices extends Table with IdColumn, AuditColumns {
  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get priceTierId => integer()
      .nullable()
      .references(PriceTiers, #id, onDelete: KeyAction.cascade)();

  IntColumn get customerTypeId => integer()
      .nullable()
      .references(CustomerTypes, #id, onDelete: KeyAction.cascade)();

  IntColumn get unitId =>
      integer().nullable().references(Units, #id, onDelete: KeyAction.setNull)();

  IntColumn get variantId => integer()
      .nullable()
      .references(ProductVariants, #id, onDelete: KeyAction.cascade)();

  IntColumn get minQtyMicro => integer().nullable()();

  IntColumn get priceMinor => integer()();

  IntColumn get validFrom =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();

  IntColumn get validTo =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

/// Per-customer price overrides (highest pricing priority).
class CustomerPrices extends Table with IdColumn, AuditColumns {
  IntColumn get customerId => integer()
      .references(Customers, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer()
      .references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get variantId => integer()
      .nullable()
      .references(ProductVariants, #id, onDelete: KeyAction.cascade)();

  IntColumn get unitId =>
      integer().nullable().references(Units, #id, onDelete: KeyAction.setNull)();

  IntColumn get minQtyMicro => integer().nullable()();

  IntColumn get priceMinor => integer()();

  IntColumn get validFrom =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();

  IntColumn get validTo =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}
