import 'package:drift/drift.dart';

import '../../core/time/utc.dart';

/// Shared column mixins for NotaKit tables.

/// Current UTC time used as client default for timestamp columns.
DateTime nowUtc() => DateTime.now().toUtc();

/// UTC epoch millis variant for raw-integer mapped timestamp columns, where
/// drift applies the type converter after the default value.
int nowUtcMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

/// Auto-increment primary key.
mixin IdColumn on Table {
  IntColumn get id => integer().autoIncrement()();
}

/// Creation/update timestamps stored as UTC epoch millis (D-012).
mixin AuditColumns on Table {
  IntColumn get createdAt => integer()
      .map(const EpochMillisUtcConverter())
      .clientDefault(nowUtcMillis)();

  IntColumn get updatedAt => integer()
      .map(const EpochMillisUtcConverter())
      .clientDefault(nowUtcMillis)();
}
