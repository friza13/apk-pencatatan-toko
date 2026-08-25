import '../units/quantity.dart';
import 'divide_half_up.dart';

/// Centralized monetary policy (D-011). Every sale/line computation MUST go
/// through here — no scattered arithmetic on money anywhere else.
///
/// Documented policy:
/// - Amounts are integer minor units; quantities are integer micro-units.
/// - Rounding mode: HALF_UP (away from zero for negatives) exactly once per
///   logical step, never accumulated per intermediate float.
/// - Calculation order: line nets → subtotal → order discounts (bertingkat,
///   SRS formula, rounded once after the multiplicative chain) → service
///   charge (bp over discounted merchandise base) → shipping (fixed) → tax
///   (bp over discounted merchandise base only; service & shipping untaxed
///   in MVP policy) → optional denomination rounding (ROUND DOWN, e.g. to
///   Rp500) recorded as `roundingMinor`.
/// - Guards: no component may push any total below zero.
abstract final class MoneyPolicy {
  /// Gross line amount: qty (micro units) × price per unit (minor),
  /// half-up rounded.
  static int lineGrossMinor(int qtyMicro, int unitPriceMinor) =>
      divideRoundHalfUp(qtyMicro * unitPriceMinor, quantityScale);

  /// Applies a single line discount (percent bp first, then fixed minor)
  /// and clamps at zero.
  static int lineNetMinor(
    int grossMinor,
    int lineDiscountPercentBp,
    int lineDiscountFixedMinor,
  ) {
    final afterPercent = divideRoundHalfUp(
      grossMinor * (10000 - lineDiscountPercentBp),
      10000,
    );
    final net = afterPercent - lineDiscountFixedMinor;
    return net < 0 ? 0 : net;
  }

  /// SRS bertingkat order discount on [subtotalMinor]:
  /// `net = (gross × (1−d1)) × (1−d2) − fixed`, rounded once, clamped ≥ 0.
  static int applyOrderDiscount(
    int subtotalMinor,
    int level1PercentBp,
    int level2PercentBp,
    int fixedMinor,
  ) {
    var net = subtotalMinor;
    if (level1PercentBp != 0) {
      net = divideRoundHalfUp(net * (10000 - level1PercentBp), 10000);
    }
    if (level2PercentBp != 0) {
      net = divideRoundHalfUp(net * (10000 - level2PercentBp), 10000);
    }
    net -= fixedMinor;
    return net < 0 ? 0 : net;
  }

  /// Percentage of a base amount in basis points, half-up.
  static int percentOfMinor(int baseMinor, int rateBp) =>
      divideRoundHalfUp(baseMinor * rateBp, 10000);

  /// Rounds a grand total DOWN to the given denomination (e.g. 500), and
  /// returns the adjustment that was subtracted (`grand - computed`).
  static int denominationRoundingAdjustment(
    int computedGrandMinor,
    int denomination,
  ) {
    if (denomination <= 0 || computedGrandMinor <= 0) {
      return 0;
    }
    final remainder = computedGrandMinor % denomination;
    if (remainder == 0) {
      return 0;
    }
    return -remainder;
  }
}

/// Immutable result of a full sale totals computation.
class SaleTotals {
  const SaleTotals({
    required this.subtotalMinor,
    required this.discountTotalMinor,
    required this.serviceChargeMinor,
    required this.shippingFeeMinor,
    required this.taxTotalMinor,
    required this.roundingMinor,
    required this.grandTotalMinor,
  });

  final int subtotalMinor;
  final int discountTotalMinor;
  final int serviceChargeMinor;
  final int shippingFeeMinor;
  final int taxTotalMinor;
  final int roundingMinor;
  final int grandTotalMinor;

  @override
  bool operator ==(Object other) =>
      other is SaleTotals &&
      other.subtotalMinor == subtotalMinor &&
      other.discountTotalMinor == discountTotalMinor &&
      other.serviceChargeMinor == serviceChargeMinor &&
      other.shippingFeeMinor == shippingFeeMinor &&
      other.taxTotalMinor == taxTotalMinor &&
      other.roundingMinor == roundingMinor &&
      other.grandTotalMinor == grandTotalMinor;

  @override
  int get hashCode => Object.hash(subtotalMinor, discountTotalMinor,
      serviceChargeMinor, shippingFeeMinor, taxTotalMinor, roundingMinor,
      grandTotalMinor);
}

/// Input for [computeSaleTotals].
class SaleTotalsInput {
  const SaleTotalsInput({
    required this.lineNetTotalsMinor,
    this.orderDiscountLevel1PercentBp = 0,
    this.orderDiscountLevel2PercentBp = 0,
    this.orderDiscountFixedMinor = 0,
    this.serviceChargeBp = 0,
    this.taxRateBp = 0,
    this.shippingFeeMinor = 0,
    this.denomination = 0,
  });

  /// Pre-computed NET totals per line (after line-level discounts).
  final List<int> lineNetTotalsMinor;

  final int orderDiscountLevel1PercentBp;
  final int orderDiscountLevel2PercentBp;
  final int orderDiscountFixedMinor;

  /// Service charge over the discounted merchandise base, in bp.
  final int serviceChargeBp;

  /// VAT/sales tax over the discounted merchandise base only, in bp.
  final int taxRateBp;

  final int shippingFeeMinor;

  /// Denomination for cash-friendly rounding (0 disables).
  final int denomination;
}

SaleTotals computeSaleTotals(SaleTotalsInput input) {
  var subtotal = 0;
  for (final line in input.lineNetTotalsMinor) {
    subtotal += line;
  }

  final discountedBase =
      MoneyPolicy.applyOrderDiscount(subtotal, input.orderDiscountLevel1PercentBp,
          input.orderDiscountLevel2PercentBp, input.orderDiscountFixedMinor);
  final discountTotal = subtotal - discountedBase;

  final serviceCharge =
      MoneyPolicy.percentOfMinor(discountedBase, input.serviceChargeBp);
  final tax = MoneyPolicy.percentOfMinor(discountedBase, input.taxRateBp);

  final computed = discountedBase + serviceCharge + input.shippingFeeMinor + tax;
  final rounding = MoneyPolicy.denominationRoundingAdjustment(
    computed,
    input.denomination,
  );

  return SaleTotals(
    subtotalMinor: subtotal,
    discountTotalMinor: discountTotal,
    serviceChargeMinor: serviceCharge,
    shippingFeeMinor: input.shippingFeeMinor,
    taxTotalMinor: tax,
    roundingMinor: rounding,
    grandTotalMinor: computed + rounding,
  );
}
