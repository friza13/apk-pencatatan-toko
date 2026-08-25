import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/time/utc.dart';

void main() {
  const converter = EpochMillisUtcConverter();

  test('stores as UTC epoch millis', () {
    final dt = DateTime.utc(2026, 8, 25, 10, 30);
    expect(converter.toSql(dt), dt.millisecondsSinceEpoch);
  });

  test('normalizes local input to UTC', () {
    final local = DateTime(2026, 8, 25, 17, 30); // WIB
    expect(converter.toSql(local), local.toUtc().millisecondsSinceEpoch);
  });

  test('reads back as UTC datetime', () {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      1790000000000,
      isUtc: true,
    );
    expect(converter.fromSql(1790000000000), dt);
  });

  test('round-trips through int', () {
    const millis = 1790000000000;
    expect(converter.toSql(converter.fromSql(millis)), millis);
  });
}
