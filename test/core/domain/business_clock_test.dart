import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/domain/business_clock.dart';

DateTime _utc(int y, int m, int d, int h, int min, [int sec = 0]) =>
    DateTime.utc(y, m, d, h, min, sec);

void main() {
  group('offsetMinutesFor', () {
    test('known Indonesian zones', () {
      expect(BusinessClock.offsetMinutesFor('Asia/Jakarta'), 420);
      expect(BusinessClock.offsetMinutesFor('Asia/Makassar'), 480);
      expect(BusinessClock.offsetMinutesFor('Asia/Jayapura'), 540);
    });

    test('unknown zone falls back to UTC', () {
      expect(BusinessClock.offsetMinutesFor('Europe/Berlin'), 0);
    });
  });

  group('dayRangeUtcMillis', () {
    test('WIB evening instant belongs to same local day', () {
      // 2026-08-25 17:30 WIB = 10:30Z
      final at = _utc(2026, 8, 25, 10, 30).millisecondsSinceEpoch;
      final (start, end) = BusinessClock.dayRangeUtcMillis(at, 420);

      // Local day start = 2026-08-25 00:00 WIB = 2026-08-24 17:00Z
      expect(
        DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
        _utc(2026, 8, 24, 17, 0),
      );
      expect(end - start, BusinessClock.millisPerDay);
    });

    test('local midnight boundary maps to previous UTC day', () {
      // 2026-08-25 00:15 WIB = 2026-08-24 17:15Z
      final at = _utc(2026, 8, 24, 17, 15).millisecondsSinceEpoch;
      final (start, end) = BusinessClock.dayRangeUtcMillis(at, 420);
      expect(
        DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
        _utc(2026, 8, 24, 17, 0),
      );
      // The whole range stays within the local Aug 25.
      expect(
        DateTime.fromMillisecondsSinceEpoch(end - 1, isUtc: true),
        _utc(2026, 8, 25, 16, 59, 59)
            .add(const Duration(milliseconds: 999)),
      );
    });

    test('WITA shifts the window by one hour versus WIB', () {
      final at = _utc(2026, 8, 25, 10, 30).millisecondsSinceEpoch;
      final wibStart = BusinessClock.startOfDayUtcMillis(at, 420);
      final witaStart = BusinessClock.startOfDayUtcMillis(at, 480);
      // Larger offset → the same instant is later locally → the local day
      // began earlier in absolute UTC terms.
      expect(witaStart - wibStart, -3600000);
    });

    test('UTC fallback behaves like plain UTC day', () {
      final at = _utc(2026, 8, 25, 10, 30).millisecondsSinceEpoch;
      final (start, end) = BusinessClock.dayRangeUtcMillis(at, 0);
      expect(
        DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
        _utc(2026, 8, 25, 0, 0),
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(end - 1, isUtc: true),
        _utc(2026, 8, 25, 23, 59, 59)
            .add(const Duration(milliseconds: 999)),
      );
    });
  });
}
