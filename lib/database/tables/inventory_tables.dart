import 'package:drift/drift.dart';

import 'business_tables.dart';
import 'catalog_tables.dart';
import '../../core/time/utc.dart';
import 'column_mixins.dart';
import 'purchase_tables.dart';
import 'sales_tables.dart';

/// Inventory movement ledger — the source of truth for stock (D-014).
/// `qty_base_micro` is signed: positive adds stock, negative removes it.
@TableIndex(
  name: 'idx_movements_product_time',
  columns: {#productId, #occurredAt},
)
@TableIndex(name: 'idx_movements_variant', columns: {#variantId})
class StockMovements extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get variantId => integer()
      .nullable()
      .references(ProductVariants, #id, onDelete: KeyAction.restrict)();

  IntColumn get saleId => integer()
      .nullable()
      .references(Sales, #id, onDelete: KeyAction.setNull)();

  IntColumn get purchaseId => integer()
      .nullable()
      .references(Purchases, #id, onDelete: KeyAction.setNull)();

  /// `purchase_in`, `sale_out`, `sales_return_in`, `purchase_return_out`,
  /// `adjustment_in`, `adjustment_out`, `stock_opname`, `opening_balance`.
  TextColumn get movementType => text()
      .customConstraint(
        "NOT NULL CHECK (movement_type IN ('purchase_in','sale_out',"
        "'sales_return_in','purchase_return_out','adjustment_in',"
        "'adjustment_out','stock_opname','opening_balance'))",
      )();

  IntColumn get qtyBaseMicro => integer()();

  /// Cost per base unit snapshot at movement time, minor units.
  IntColumn get unitCostMinor => integer().withDefault(const Constant(0))();

  TextColumn get referenceNumber => text().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get occurredAt =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();
}

/// Sales return document — references the original sale; the sale itself is
/// never modified (D-009).
class SalesReturns extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.restrict)();

  TextColumn get number => text()();

  TextColumn get reason => text().nullable()();

  IntColumn get totalMinor => integer().withDefault(const Constant(0))();

  /// Refund payment covering this return when money was given back (#14).
  IntColumn get refundPaymentId => integer().nullable()();

  IntColumn get voidedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

@TableIndex(name: 'idx_sales_return_lines_return', columns: {#salesReturnId})
class SalesReturnLines extends Table with IdColumn {
  IntColumn get salesReturnId =>
      integer().references(SalesReturns, #id, onDelete: KeyAction.cascade)();

  IntColumn get saleLineId =>
      integer().references(SaleLines, #id, onDelete: KeyAction.restrict)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get variantId => integer()
      .nullable()
      .references(ProductVariants, #id, onDelete: KeyAction.restrict)();

  /// Returned base quantity in micro units.
  IntColumn get qtyBaseMicro => integer()();

  IntColumn get amountMinor => integer()();
}

/// Purchase return document (schema-ready; workflow is Phase 2).
class PurchaseReturns extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get purchaseId => integer()
      .nullable()
      .references(Purchases, #id, onDelete: KeyAction.setNull)();

  TextColumn get number => text()();

  TextColumn get reason => text().nullable()();

  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
}

class PurchaseReturnLines extends Table with IdColumn {
  IntColumn get purchaseReturnId => integer()
      .references(PurchaseReturns, #id, onDelete: KeyAction.cascade)();

  IntColumn get purchaseLineId => integer()
      .nullable()
      .references(PurchaseLines, #id, onDelete: KeyAction.setNull)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  IntColumn get qtyBaseMicro => integer()();

  IntColumn get amountMinor => integer()();
}
