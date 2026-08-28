import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/domain/qty.dart';
import 'package:notakit/core/units/quantity.dart';

void main() {
  group('Qty basics', () {
    test('fromString parses decimals', () {
      expect(Qty.fromString('2').micro, 2000000);
      expect(Qty.fromString('0.5').micro, 500000);
      expect(Qty.fromString('-1.25').micro, -1250000);
    });

    test('toString canonical output', () {
      expect(const Qty(2500000).toString(), '2.5');
      expect(const Qty(0).toString(), '0');
      expect(const Qty(-3000000).toString(), '-3');
    });

    test('equality and comparison', () {
      expect(Qty.fromString('2'), Qty.fromString('2.0'));
      expect(
        Qty.fromString('3').compareTo(Qty.fromString('2.5')),
        greaterThan(0),
      );
    });

    test('add/subtract', () {
      final a = Qty.fromString('1.5');
      final b = Qty.fromString('0.25');
      expect(a.add(b).toString(), '1.75');
      expect(a.subtract(b).toString(), '1.25');
    });
  });

  group('timesPriceMinor', () {
    test('exact multiplication', () {
      // 2 pcs × Rp10.000 = Rp20.000
      expect(Qty.fromString('2').timesPriceMinor(10000), 20000);
    });

    test('half-up rounding on fractional qty', () {
      // 0.125 kg × Rp10.005 = 1250,625 → 1251
      expect(Qty.fromString('0.125').timesPriceMinor(10005), 1251);
    });

    test('negative quantity yields negative money (return lines)', () {
      expect(Qty.fromString('-2').timesPriceMinor(10000), -20000);
    });
  });

  group('toBaseUnits', () {
    test('dus → pcs with factor 24', () {
      const factor24 = 24 * quantityScale;
      expect(Qty.fromString('2').toBaseUnits(factor24).toString(), '48');
    });

    test('fractional factor: 1 pack = 0.5 kg', () {
      const halfKg = quantityScale ~/ 2;
      expect(Qty.fromString('3').toBaseUnits(halfKg).toString(), '1.5');
    });

    test('rounds half-up', () {
      // 1 unit × factor 0.0000015-ish edge: use micro math directly.
      const oddFactor = 15; // 0.000015 base units per unit? tiny factor
      // 500.000 micro qty × 15 / 1.000.000 = 7,5 → 8
      expect(const Qty(500000).toBaseUnits(oddFactor).micro, 8);
    });
  });

  group('divideRoundHalfUp', () {
    test('classic half-up on positives', () {
      expect(divideRoundHalfUp(5, 2), 3);
      expect(divideRoundHalfUp(4, 2), 2);
      expect(divideRoundHalfUp(7, 4), 2);
    });

    test('away-from-zero on negatives', () {
      expect(divideRoundHalfUp(-5, 2), -3);
    });

    test('rejects zero denominator', () {
      expect(() => divideRoundHalfUp(1, 0), throwsArgumentError);
    });
  });
}
