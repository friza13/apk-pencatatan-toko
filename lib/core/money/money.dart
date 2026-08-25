/// Money helpers (D-011). Amounts are integer minor units — never floating
/// point. Rounding policy lives here in P2; formatting only for now.
library;

String formatMinor(int amount, {int scale = 0}) {
  final negative = amount < 0;
  final magnitude = negative ? -amount : amount;

  var result = '';
  if (scale > 0) {
    final factor = _pow10(scale);
    final whole = magnitude ~/ factor;
    final fraction = magnitude % factor;
    result = '${_group(whole)},'
        '${fraction.toString().padLeft(scale, '0')}';
  } else {
    result = _group(magnitude);
  }

  return negative && magnitude > 0 ? '-Rp$result' : 'Rp$result';
}

String _group(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
