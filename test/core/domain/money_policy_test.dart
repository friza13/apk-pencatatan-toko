import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/domain/money_policy.dart';

void main() {
  group('lineGrossMinor', () {
    test('exact integer result', () {
      expect(MoneyPolicy.lineGrossMinor(2000000, 10000), 20000);
    });

    test('fractional qty rounds half-up once', () {
      // 0.125 kg × Rp10.005 = 1.250,625 → 1.251
      expect(MoneyPolicy.lineGrossMinor(125000, 10005), 1251);
    });
  });

  group('lineNetMinor', () {
    test('percent then fixed', () {
      // gross 20.000 − 10% = 18.000 − 500 fixed = 17.500
      expect(MoneyPolicy.lineNetMinor(20000, 1000, 500), 17500);
    });

    test('clamps at zero', () {
      expect(MoneyPolicy.lineNetMinor(1000, 5000, 9999), 0);
    });
  });

  group('applyOrderDiscount (SRS bertingkat)', () {
    test('two percent levels plus fixed', () {
      // 100.000 → ×0.90 = 90.000 → ×0.95 = 85.500 → −1.000 = 84.500
      expect(MoneyPolicy.applyOrderDiscount(100000, 1000, 500, 1000), 84500);
    });

    test('single level only', () {
      expect(MoneyPolicy.applyOrderDiscount(25500, 1000, 0, 0), 22950);
    });

    test('clamps at zero when fixed exceeds subtotal', () {
      expect(MoneyPolicy.applyOrderDiscount(10000, 0, 0, 99999), 0);
    });
  });

  group('computeSaleTotals', () {
    test('case A: subtotal + tax 11%', () {
      final totals = computeSaleTotals(
        const SaleTotalsInput(
          lineNetTotalsMinor: [20000, 5500],
          taxRateBp: 1100,
        ),
      );
      // subtotal 25.500; base after 10% nota disc? none here; tax 11% of
      // 25.500 = 2.805
      expect(totals.subtotalMinor, 25500);
      expect(totals.taxTotalMinor, 2805);
      expect(totals.grandTotalMinor, 28305);
    });

    test('case B: order discount then tax on discounted base', () {
      final totals = computeSaleTotals(
        SaleTotalsInput(
          lineNetTotalsMinor: const [20000, 5500],
          orderDiscountLevel1PercentBp: 1000,
          taxRateBp: 1100,
        ),
      );
      // base = 22.950; discountTotal = 2.550; tax = 2.524,5 → 2.525
      expect(totals.discountTotalMinor, 2550);
      expect(totals.taxTotalMinor, 2525);
      expect(totals.grandTotalMinor, 25475);
    });

    test('case C: service charge + shipping untaxed policy', () {
      final totals = computeSaleTotals(
        SaleTotalsInput(
          lineNetTotalsMinor: const [20000],
          orderDiscountLevel1PercentBp: 500,
          serviceChargeBp: 500,
          shippingFeeMinor: 2000,
          taxRateBp: 1100,
        ),
      );
      // base = 19.000; sc = 950; shipping = 2.000; tax = 2.090
      // grand = 19.000 + 950 + 2.000 + 2.090 = 24.040
      expect(totals.serviceChargeMinor, 950);
      expect(totals.shippingFeeMinor, 2000);
      expect(totals.taxTotalMinor, 2090);
      expect(totals.grandTotalMinor, 24040);
    });

    test(
      'case D: denomination rounding rounds down and records adjustment',
      () {
        final totals = computeSaleTotals(
          const SaleTotalsInput(lineNetTotalsMinor: [12345], denomination: 500),
        );
        // computed 12.345 → rounded to 12.000, adjustment −345
        expect(totals.roundingMinor, -345);
        expect(totals.grandTotalMinor, 12000);
      },
    );

    test('case E: guard — massive fixed discount yields zero grand total', () {
      final totals = computeSaleTotals(
        const SaleTotalsInput(
          lineNetTotalsMinor: [10000],
          orderDiscountFixedMinor: 99999,
          taxRateBp: 1100,
        ),
      );
      expect(totals.discountTotalMinor, 10000);
      expect(totals.taxTotalMinor, 0);
      expect(totals.grandTotalMinor, 0);
    });

    test('totals equality is value-based', () {
      final a = computeSaleTotals(
        const SaleTotalsInput(lineNetTotalsMinor: [100]),
      );
      final b = computeSaleTotals(
        const SaleTotalsInput(lineNetTotalsMinor: [100]),
      );
      expect(a, equals(b));
    });
  });
}
