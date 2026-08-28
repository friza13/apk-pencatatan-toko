import 'package:drift/drift.dart';

import 'business_tables.dart';
import '../../core/time/utc.dart';
import 'column_mixins.dart';
import 'crm_pricing_tables.dart';
import 'purchase_tables.dart';
import 'sales_tables.dart';

/// Cash / bank / e-wallet accounts (FR section M).
class Accounts extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  /// `cash`, `bank`, `ewallet`, `other`.
  TextColumn get type => text().customConstraint(
    "NOT NULL DEFAULT 'cash' "
    "CHECK (type IN ('cash','bank','ewallet','other'))",
  )();

  TextColumn get accountNumber => text().nullable()();

  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();

  /// Cached balance; verifiable against ledger entries (G-04).
  IntColumn get currentBalanceMinor =>
      integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Generic payment model (D-007b) covering sale payments, purchase payments,
/// refunds, transfers and manual income/expense with explicit direction,
/// purpose, account and references.
@TableIndex(name: 'idx_payments_paid_at', columns: {#paidAt})
@TableIndex(name: 'idx_payments_sale', columns: {#saleId})
@TableIndex(name: 'idx_payments_account_time', columns: {#accountId, #paidAt})
class Payments extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  /// `in` = money into [accountId]; `out` = money out of it.
  TextColumn get direction =>
      text().customConstraint("NOT NULL CHECK (direction IN ('in','out'))")();

  /// `sale_payment`, `purchase_payment`, `receivable_settlement`,
  /// `payable_settlement` (future), `refund`, `transfer`, `other_income`,
  /// `other_expense`.
  TextColumn get purpose => text().customConstraint(
    "NOT NULL CHECK (purpose IN ('sale_payment','purchase_payment',"
    "'receivable_settlement','payable_settlement','refund','transfer',"
    "'other_income','other_expense'))",
  )();

  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Transfer counterpart (destination for out, source for in).
  IntColumn get counterAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get saleId => integer().nullable().references(
    Sales,
    #id,
    onDelete: KeyAction.restrict,
  )();

  IntColumn get purchaseId => integer().nullable().references(
    Purchases,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Refund traceability to the original incoming payment (#14).
  IntColumn get refundOfPaymentId => integer().nullable()();

  /// Always positive; direction carries the sign.
  IntColumn get amountMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_minor > 0)')();

  /// `cash`, `bank`, `ewallet`, `card`, `other`.
  TextColumn get method => text().customConstraint(
    "NOT NULL DEFAULT 'cash' "
    "CHECK (method IN ('cash','bank','ewallet','card','other'))",
  )();

  /// Free-text category for other_income/other_expense.
  TextColumn get category => text().nullable()();

  TextColumn get referenceNumber => text().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get paidAt => integer()
      .map(const EpochMillisUtcConverter())
      .clientDefault(nowUtcMillis)();
}

/// Receivable per credit sale (FR-AR-001). OVERDUE is never stored — derived
/// from due_date + remaining_amount at query time (D-010).
class Receivables extends Table with IdColumn, AuditColumns {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  IntColumn get saleId =>
      integer().unique().references(Sales, #id, onDelete: KeyAction.restrict)();

  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.restrict)();

  IntColumn get originalAmountMinor => integer()();

  IntColumn get paidAmountMinor => integer().withDefault(const Constant(0))();

  IntColumn get remainingAmountMinor => integer()();

  IntColumn get dueDate => integer().map(const EpochMillisUtcConverter())();

  /// `open`, `partial`, `paid`.
  TextColumn get status => text().customConstraint(
    "NOT NULL DEFAULT 'open' CHECK (status IN ('open','partial','paid'))",
  )();

  IntColumn get closedAt =>
      integer().map(const EpochMillisUtcConverter()).nullable()();
}

/// Allocation of a payment to one receivable (a single payment may settle
/// several receivables).
class ReceivablePayments extends Table with IdColumn {
  IntColumn get receivableId =>
      integer().references(Receivables, #id, onDelete: KeyAction.cascade)();

  IntColumn get paymentId =>
      integer().references(Payments, #id, onDelete: KeyAction.restrict)();

  IntColumn get amountAppliedMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_applied_minor > 0)')();
}

/// Cash ledger — every balance-affecting action posts here
/// (FR-CASH-001). Transfers post two paired entries.
@TableIndex(name: 'idx_ledger_account_time', columns: {#accountId, #occurredAt})
class LedgerEntries extends Table with IdColumn {
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Polymorphic source: `payment`, `sale`, `purchase`, `transfer`,
  /// `adjustment`, ...
  TextColumn get sourceType => text()();

  TextColumn get sourceId => text().nullable()();

  /// `debit` (increase cash/bank) or `credit` (decrease).
  TextColumn get entryType => text().customConstraint(
    "NOT NULL CHECK (entry_type IN ('debit','credit'))",
  )();

  IntColumn get amountMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_minor > 0)')();

  IntColumn get occurredAt => integer()
      .map(const EpochMillisUtcConverter())
      .clientDefault(nowUtcMillis)();

  TextColumn get note => text().nullable()();
}
