import 'package:drift/drift.dart';

import '../../core/time/utc.dart';
import 'business_tables.dart';
import 'catalog_tables.dart';
import 'column_mixins.dart';

/// Supplier master (FR section F).
class Suppliers extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get address => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Purchase header. Stock/WAC effects happen only at finalize (D-013).
class Purchases extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get supplierId => integer()
      .nullable()
      .references(Suppliers, #id, onDelete: KeyAction.setNull)();

  TextColumn get number => text().nullable()();

  /// `draft`, `finalized`, `voided`.
  TextColumn get status => text()
      .customConstraint(
        "NOT NULL DEFAULT 'draft' "
        "CHECK (status IN ('draft','finalized','voided'))",
      )();

  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get discountTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get taxTotalMinor => integer().withDefault(const Constant(0))();

  /// Additional purchase costs (freight etc.) allocated into WAC.
  IntColumn get otherCostMinor => integer().withDefault(const Constant(0))();

  IntColumn get grandTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get paidTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get dueTotalMinor => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  IntColumn get finalizedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();

  IntColumn get voidedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

/// Purchase line with unit/conversion snapshot at transaction time.
@TableIndex(name: 'idx_purchase_lines_purchase', columns: {#purchaseId})
class PurchaseLines extends Table with IdColumn {
  IntColumn get purchaseId =>
      integer().references(Purchases, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get variantId => integer()
      .nullable()
      .references(ProductVariants, #id, onDelete: KeyAction.restrict)();

  IntColumn get qtyMicro => integer()();

  IntColumn get unitId => integer().references(Units, #id)();

  /// Sold/purchase-unit → base factor snapshot in micro units (D-008).
  IntColumn get conversionFactorMicro => integer()();

  IntColumn get qtyBaseMicro => integer()();

  /// Cost per purchased unit, minor units.
  IntColumn get unitCostMinor => integer()();

  IntColumn get discountAmountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get lineTotalMinor => integer()();
}
