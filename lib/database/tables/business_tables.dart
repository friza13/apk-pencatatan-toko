import 'package:drift/drift.dart';

import '../../core/time/utc.dart';
import 'column_mixins.dart';

/// Owner profile — singleton row (FR-AUTH-001).
class Owners extends Table with IdColumn, AuditColumns {
  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();
}

/// Business workspace — one active instance (PRD §29 keeps business_id).
@DataClassName('Business')
class Businesses extends Table with IdColumn, AuditColumns {
  IntColumn get ownerId =>
      integer().references(Owners, #id, onDelete: KeyAction.restrict)();

  TextColumn get name => text()();

  TextColumn get address => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get logoPath => text().nullable()();

  /// Nota footer text printed under receipts.
  TextColumn get footerNote => text().nullable()();

  /// ISO-4217 code. IDR default (scale 0).
  TextColumn get currency => text().withDefault(const Constant('IDR'))();

  /// Minor-unit scale of [currency] (0 for IDR).
  IntColumn get currencyScale => integer().withDefault(const Constant(0))();

  /// IANA timezone used for business-day boundaries (D-012).
  TextColumn get timezone =>
      text().withDefault(const Constant('Asia/Jakarta'))();

  /// Prefix for sale numbers, e.g. `INV`.
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();

  /// Monotonic counter; incremented inside the finalize transaction.
  IntColumn get invoiceSequence => integer().withDefault(const Constant(0))();

  /// Optional denomination rounding in minor units (e.g. 100/500), off when
  /// null (D-011).
  IntColumn get roundingDenomination => integer().nullable()();
}

/// Key-value settings. Sensitive values are encrypted at the application
/// layer before being written as JSON (delta documented in D-021).
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  TextColumn get settingKey => text()();

  TextColumn get valueJson => text()();

  IntColumn get updatedAt =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {businessId, settingKey},
      ];
}

/// Audit trail (FR-AUDIT-001). Append-only; no updates/deletes from domain.
class ActivityLogs extends Table with IdColumn {
  IntColumn get businessId => integer().references(Businesses, #id)();

  /// `owner` or `system`.
  TextColumn get actorType => text()();

  TextColumn get action => text()();

  TextColumn get entityType => text()();

  /// Kept as TEXT so non-integer references stay possible.
  TextColumn get entityId => text().nullable()();

  TextColumn get beforeJson => text().nullable()();

  TextColumn get afterJson => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get createdAt =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();
}

/// Local notification outbox/history (FR-NOTIF-001).
class AppNotifications extends Table with IdColumn {
  IntColumn get businessId => integer().references(Businesses, #id)();

  TextColumn get type => text()();

  TextColumn get title => text()();

  TextColumn get body => text()();

  TextColumn get referenceType => text().nullable()();

  TextColumn get referenceId => text().nullable()();

  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();
}

/// Metadata about produced backup files (the `.nkb` files themselves live on
/// disk and are described by D-002's manifest).
class BackupRecords extends Table with IdColumn {
  IntColumn get businessId => integer().references(Businesses, #id)();

  TextColumn get fileName => text()();

  IntColumn get formatVersion => integer()();

  TextColumn get appVersion => text()();

  IntColumn get schemaVersion => integer()();

  BoolColumn get encrypted => boolean()();

  IntColumn get sizeBytes => integer()();

  TextColumn get checksum => text()();

  /// `local`, `drive`, `share`.
  TextColumn get locationType => text()();

  TextColumn get sourceDeviceId => text().nullable()();

  IntColumn get createdAt =>
      integer().map(const EpochMillisUtcConverter()).clientDefault(nowUtcMillis)();
}

/// Saved printer configurations (FR-PRINT-001).
class PrinterProfiles extends Table with IdColumn {
  IntColumn get businessId => integer().references(Businesses, #id)();

  TextColumn get name => text()();

  /// e.g. `thermal58`, `thermal80`, `a4`, `pdf`.
  TextColumn get printerType => text()();

  IntColumn get paperWidthMm => integer().nullable()();

  /// `none` (PDF/share only), `bluetooth`, `network`, `usb`.
  TextColumn get connectionType => text()();

  /// Encrypted at application layer via secure storage key.
  TextColumn get connectionConfigEncrypted => text().nullable()();

  TextColumn get templateId => text().nullable()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
