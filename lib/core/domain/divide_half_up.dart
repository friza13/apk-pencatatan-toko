/// Half-up integer division shared by money and quantity policies (D-008,
/// D-011). Lives alone to keep both policy files dependency-free.
library;

/// Divides [numerator] by [denominator] rounding halves up (away from zero
/// for negative numerators).
int divideRoundHalfUp(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError('division by zero');
  }
  if (numerator >= 0) {
    return (numerator + denominator ~/ 2) ~/ denominator;
  }
  return -divideRoundHalfUp(-numerator, denominator);
}
