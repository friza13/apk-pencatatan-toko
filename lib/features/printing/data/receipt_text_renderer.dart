/// Renders a sale into plain-text receipt for 58 mm (32 cols) or
/// 80 mm (48 cols) thermal printers. The same text doubles as the ESC/POS
/// payload source later; PDF rendering uses a monospace layout of it.
class ReceiptTextRenderer {
  ReceiptTextRenderer({required this.widthChars});

  /// 58 mm printers usually support 32 characters; 80 mm about 48.
  final int widthChars;

  String render({
    required String storeName,
    required String number,
    required String dateTimeLocal,
    required List<ReceiptLine> lines,
    required int subtotalMinor,
    int discountMinor = 0,
    int taxMinor = 0,
    int shippingMinor = 0,
    int roundingMinor = 0,
    required int grandTotalMinor,
    required int paidMinor,
    required int dueMinor,
    required String paymentLabel,
    String? customerName,
    String? footerNote,
    String currencySymbol = 'Rp',
  }) {
    final b = StringBuffer();
    String money(int v) => '$currencySymbol${_group(v)}';

    b
      ..writeln(_center(storeName))
      ..writeln(_center(number))
      ..writeln(_center(dateTimeLocal));
    if (customerName != null && customerName.isNotEmpty) {
      b.writeln(_center(customerName));
    }
    b.writeln(_divider());

    for (final l in lines) {
      b
        ..writeln(_truncate(l.name))
        ..writeln(
          _leftRight(
            '  ${l.qty} x ${money(l.priceMinor)}',
            money(l.totalMinor),
          ),
        );
      if (l.discountMinor > 0) {
        b.writeln(_leftRight('  Diskon', '-${money(l.discountMinor)}'));
      }
    }

    b
      ..writeln(_divider())
      ..writeln(_leftRight('Subtotal', money(subtotalMinor)));
    if (discountMinor > 0) {
      b.writeln(_leftRight('Diskon', '-${money(discountMinor)}'));
    }
    if (taxMinor > 0) {
      b.writeln(_leftRight('Pajak', money(taxMinor)));
    }
    if (shippingMinor > 0) {
      b.writeln(_leftRight('Ongkir', money(shippingMinor)));
    }
    if (roundingMinor != 0) {
      b.writeln(_leftRight('Pembulatan', money(roundingMinor)));
    }
    b
      ..writeln(_leftRight('TOTAL', money(grandTotalMinor)))
      ..writeln(_leftRight(paymentLabel, money(paidMinor)));
    if (dueMinor > 0) {
      b.writeln(_leftRight('Sisa (piutang)', money(dueMinor)));
    }

    b.writeln(_divider());
    if (footerNote != null && footerNote.isNotEmpty) {
      b.writeln(_center(footerNote));
    } else {
      b.writeln(_center('Terima kasih!'));
    }
    return b.toString();
  }

  // ---------- primitives ----------

  String _divider() => '-' * widthChars;

  String _center(String text) {
    final t = _truncate(text);
    if (t.length >= widthChars) return t;
    final left = (widthChars - t.length) ~/ 2;
    return '${' ' * left}$t';
  }

  String _truncate(String s) =>
      s.length <= widthChars ? s : s.substring(0, widthChars);

  String _leftRight(String left, String right) {
    var l = left;
    var r = right;
    if (l.length + r.length > widthChars) {
      l = '${l.substring(0, (widthChars - r.length - 1).clamp(0, l.length))}…';
      if (r.length > widthChars) {
        r = r.substring(r.length - widthChars);
      }
      l = l.substring(0, (widthChars - r.length).clamp(0, l.length));
    }
    final spaces = widthChars - l.length - r.length;
    return '$l${' ' * spaces}$r';
  }

  static String _group(int amount) {
    final negative = amount < 0;
    final digits = (negative ? -amount : amount).toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buf.write('.');
    }
    return negative ? '-$buf' : buf.toString();
  }
}

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.priceMinor,
    required this.totalMinor,
    this.discountMinor = 0,
  });

  final String name;
  final String qty;
  final int priceMinor;
  final int totalMinor;
  final int discountMinor;
}
