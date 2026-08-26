/// Business-time utilities (D-012).
///
/// Timestamps are stored UTC; day boundaries for reports are computed in the
/// business timezone. Indonesia has no DST, so a fixed-offset table covers
/// all official zones; unknown zones fall back to UTC (documented behavior).
abstract final class BusinessClock {
  static const Map<String, int> _zoneOffsetMinutes = {
    'Asia/Jakarta': 7 * 60, // WIB
    'Asia/Pontianak': 7 * 60,
    'Asia/Makassar': 8 * 60, // WITA
    'Asia/Jayapura': 9 * 60, // WIT
  };

  static const int millisPerDay = 86400000;

  /// Offset from UTC in minutes for a known Indonesian zone; 0 otherwise.
  static int offsetMinutesFor(String ianaZone) =>
      _zoneOffsetMinutes[ianaZone] ?? 0;

  /// Start of the business day (UTC millis) containing [atUtcMillis].
  static int startOfDayUtcMillis(int atUtcMillis, int offsetMinutes) {
    final localMillis = atUtcMillis + offsetMinutes * 60000;
    final localDayStart = (localMillis ~/ millisPerDay) * millisPerDay;
    return localDayStart - offsetMinutes * 60000;
  }

  /// [startUtcMillis, endExclusiveUtcMillis) of the business day containing
  /// [atUtcMillis].
  static (int, int) dayRangeUtcMillis(int atUtcMillis, int offsetMinutes) {
    final start = startOfDayUtcMillis(atUtcMillis, offsetMinutes);
    return (start, start + millisPerDay);
  }
}
