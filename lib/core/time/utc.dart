import 'package:drift/drift.dart';

/// Drift converter storing [DateTime] as UTC epoch milliseconds (D-012).
///
/// All timestamps in the database flow through this converter so that stored
/// values are timezone-independent; presentation converts to the business
/// timezone via core date utilities only.
class EpochMillisUtcConverter extends TypeConverter<DateTime, int> {
  const EpochMillisUtcConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}
