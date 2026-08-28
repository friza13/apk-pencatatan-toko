import 'package:drift/drift.dart';

import 'business_tables.dart';
import 'catalog_tables.dart';
import '../../core/time/utc.dart';
import 'column_mixins.dart';
import 'crm_pricing_tables.dart';

/// Sale header. Finalized sales are immutable (D-009); totals are cached and
/// must remain reconstructible from sale lines.
@TableIndex(name: 'idx_sales_business_number', columns: {#businessId, #number})
@TableIndex(
  name: 'idx_sales_business_created',
  columns: {#businessId, #createdAt},
)
@TableIndex(
  name: 'idx_sales_business_customer_created',
  columns: {#businessId, #customerId, #createdAt},
)
class Sales extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get customerId => integer().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get salesmanId => integer().nullable().references(
    Salesmen,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Unique per business once finalized; drafts may be unnumbered (D-021).
  TextColumn get number => text().nullable()();

  /// Lifecycle per D-009: draft → confirmed → paid/partially_paid/credit,
  /// with voided as terminal side-state.
  TextColumn get status => text().customConstraint(
    "NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','confirmed',"
    "'paid','partially_paid','credit','voided'))",
  )();

  /// Business mode of the transaction.
  TextColumn get saleType => text().customConstraint(
    "NOT NULL DEFAULT 'retail' CHECK (sale_type IN ('retail','wholesale',"
    "'restaurant','online','minimarket'))",
  )();

  /// Reserved for future restaurant order types; unused in MVP UI (#16).
  TextColumn get orderType => text().nullable()();

  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get discountTotalMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get taxTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get serviceChargeMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get shippingFeeMinor => integer().withDefault(const Constant(0))();

  IntColumn get roundingMinor => integer().withDefault(const Constant(0))();

  IntColumn get grandTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get paidTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get dueTotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get dueDate =>
      integer().map(const EpochMillisUtcConverter()).nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get finalizedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();

  IntColumn get voidedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

/// Sale line with full transaction-time snapshots so later master-data edits
/// never mutate history (FR-SALES-001, amendment #7).
@TableIndex(name: 'idx_sale_lines_sale', columns: {#saleId})
class SaleLines extends Table with IdColumn {
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get variantId => integer().nullable().references(
    ProductVariants,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get productNameSnapshot => text()();

  TextColumn get skuSnapshot => text().nullable()();

  TextColumn get unitNameSnapshot => text()();

  IntColumn get unitId => integer().nullable()();

  /// Quantity in the sold unit, micro units (D-008).
  IntColumn get qtyMicro => integer()();

  /// Conversion factor sold-unit → base unit at transaction time
  /// (1 base unit per sold unit = quantityScale).
  IntColumn get conversionFactorMicro => integer()();

  /// qty × conversion factor in base units, micro units.
  IntColumn get qtyBaseMicro => integer()();

  /// Price per sold unit at transaction time, minor units.
  IntColumn get unitPriceMinor => integer()();

  IntColumn get discountAmountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get taxAmountMinor => integer().withDefault(const Constant(0))();

  /// HPP per base unit snapshot for profit reports (ERD §17).
  IntColumn get costPriceSnapshotMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get lineTotalMinor => integer()();

  TextColumn get note => text().nullable()();
}
