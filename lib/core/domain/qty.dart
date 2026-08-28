import '../units/quantity.dart';
import 'divide_half_up.dart';

export 'divide_half_up.dart' show divideRoundHalfUp;

/// Immutable quantity value object backed by integer micro-units (D-008).
///
/// All arithmetic is exact integer math; scaling uses half-up rounding.
class Qty implements Comparable<Qty> {
  const Qty(this.micro);

  factory Qty.zero() => const Qty(0);

  /// Parses decimal strings like `2`, `0.5`, `-1.25`.
  factory Qty.fromString(String decimal) => Qty(toMicro(decimal));

  final int micro;

  bool get isNegative => micro < 0;

  bool get isZero => micro == 0;

  Qty add(Qty other) => Qty(micro + other.micro);

  Qty subtract(Qty other) => Qty(micro - other.micro);

  /// Multiplies by a unit price (minor units per unit), yielding money minor
  /// units with half-up rounding.
  int timesPriceMinor(int unitPriceMinor) =>
      divideRoundHalfUp(micro * unitPriceMinor, quantityScale);

  /// Converts a quantity in some unit to base units using the given
  /// conversion factor (micro-scaled), half-up rounding.
  Qty toBaseUnits(int conversionFactorMicro) =>
      Qty(divideRoundHalfUp(micro * conversionFactorMicro, quantityScale));

  @override
  int compareTo(Qty other) => micro.compareTo(other.micro);

  @override
  bool operator ==(Object other) => other is Qty && other.micro == micro;

  @override
  int get hashCode => micro;

  @override
  String toString() => microToDecimalString(micro);
}
