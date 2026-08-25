import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/money/money.dart';

void main() {
  group('formatIdr', () {
    test('formats zero', () {
      expect(formatMinor(0), 'Rp0');
    });

    test('groups thousands with dots', () {
      expect(formatMinor(10500), 'Rp10.500');
      expect(formatMinor(125000), 'Rp125.000');
      expect(formatMinor(1234567), 'Rp1.234.567');
    });

    test('formats negative amounts', () {
      expect(formatMinor(-10500), '-Rp10.500');
    });

    test('keeps decimals only when currency scale requires it', () {
      expect(formatMinor(10500, scale: 2), 'Rp105,00');
      expect(formatMinor(125000, scale: 2), 'Rp1.250,00');
      expect(formatMinor(5, scale: 2), 'Rp0,05');
    });
  });
}
