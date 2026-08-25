import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/units/quantity.dart';

void main() {
  group('quantityScale', () {
    test('is exactly one million', () {
      expect(quantityScale, 1000000);
    });
  });

  group('toMicro', () {
    test('parses integers', () {
      expect(toMicro('2'), 2000000);
      expect(toMicro('24'), 24000000);
    });

    test('parses decimals up to six places', () {
      expect(toMicro('0.5'), 500000);
      expect(toMicro('1.25'), 1250000);
      expect(toMicro('0.000001'), 1);
    });

    test('parses negative quantities (adjustments)', () {
      expect(toMicro('-3'), -3000000);
      expect(toMicro('-0.25'), -250000);
    });

    test('rejects more than six decimal places', () {
      expect(() => toMicro('0.0000005'), throwsArgumentError);
    });

    test('rejects empty and malformed input', () {
      expect(() => toMicro(''), throwsArgumentError);
      expect(() => toMicro('abc'), throwsArgumentError);
      expect(() => toMicro('1.2.3'), throwsArgumentError);
    });
  });

  group('microToDecimalString', () {
    test('formats integers without trailing zeros', () {
      expect(microToDecimalString(2000000), '2');
      expect(microToDecimalString(-3000000), '-3');
    });

    test('formats fractional quantities', () {
      expect(microToDecimalString(500000), '0.5');
      expect(microToDecimalString(1250000), '1.25');
      expect(microToDecimalString(1), '0.000001');
    });

    test('round-trips through toMicro', () {
      for (final raw in ['0', '2', '0.5', '1.25', '-3', '1234.567891']) {
        expect(microToDecimalString(toMicro(raw)), raw);
      }
    });
  });
}
