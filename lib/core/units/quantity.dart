/// Quantity representation for NotaKit (D-008).
///
/// Quantities are stored as integer micro-units: `qty_micro = qty × scale`.
/// The literal 1000000 must only appear here — never scatter it through the
/// codebase; import [quantityScale] instead.
const int quantityScale = 1000000;

const int _maxFractionDigits = 6;

/// Parses a decimal quantity string (e.g. `2`, `0.5`, `-1.25`) into micro
/// units. Throws [ArgumentError] on malformed input or more than six decimal
/// places.
int toMicro(String decimal) {
  final value = decimal.trim();
  if (value.isEmpty) {
    throw ArgumentError('empty quantity');
  }

  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,6}))?$').firstMatch(value);
  if (match == null) {
    throw ArgumentError('malformed quantity: $decimal');
  }

  final sign = match.group(1) == '-' ? -1 : 1;
  final whole = int.parse(match.group(2)!);
  final fraction = match.group(3) ?? '';
  final fractionMicro = fraction.isEmpty
      ? 0
      : int.parse(fraction.padRight(_maxFractionDigits, '0'));
  return sign * (whole * quantityScale + fractionMicro);}

/// Formats micro units back into a canonical decimal string without trailing
/// zeros (e.g. `500000` → `0.5`, `2000000` → `2`).
String microToDecimalString(int micro) {
  final negative = micro < 0;
  var magnitude = negative ? -micro : micro;

  final whole = magnitude ~/ quantityScale;
  final fraction = magnitude % quantityScale;

  var result = '$whole';
  if (fraction > 0) {
    var fracStr = fraction.toString().padLeft(_maxFractionDigits, '0');
    while (fracStr.endsWith('0')) {
      fracStr = fracStr.substring(0, fracStr.length - 1);
    }
    result = '$result.$fracStr';
  }

  return negative && magnitude > 0 ? '-$result' : result;
}
