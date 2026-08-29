import '../domain/receipt_config.dart';
import '../domain/receipt_document.dart';

export '../domain/receipt_config.dart';
export '../domain/receipt_document.dart';

/// Renders a sale into plain-text receipt for 58 mm (32 cols) or
/// 80 mm (48 cols) thermal printers. The same text doubles as the ESC/POS
/// payload source later; PDF rendering uses a monospace layout of it.
class ReceiptTextRenderer {
  ReceiptTextRenderer({required this.widthChars});

  /// 58 mm printers usually support 32 characters; 80 mm about 48.
  final int widthChars;

  /// Renders a [ReceiptDocument] into structured plain text.
  String renderDocument(ReceiptDocument doc) {
    final b = StringBuffer();
    String money(int v) => '${doc.currencySymbol}${_group(v)}';

    // 1. Header
    b.writeln(_center(doc.storeName));
    if (doc.config.showTagline &&
        doc.tagline != null &&
        doc.tagline!.trim().isNotEmpty) {
      b.writeln(_center(doc.tagline!.trim()));
    }
    b.writeln(_divider());

    // 2. Metadata Grid
    if (doc.transactionId != null && doc.transactionId!.trim().isNotEmpty) {
      b.writeln(_leftRight('No. Ref', doc.transactionId!.trim()));
    }
    b
      ..writeln(_leftRight('No. Nota', doc.invoiceNumber))
      ..writeln(_leftRight('Tanggal', doc.dateTimeLocal));
    if (doc.customerName != null && doc.customerName!.trim().isNotEmpty) {
      b.writeln(_leftRight('Pelanggan', doc.customerName!.trim()));
    }
    if (doc.config.showOperator &&
        doc.operatorName != null &&
        doc.operatorName!.trim().isNotEmpty) {
      b.writeln(_leftRight('Kasir', doc.operatorName!.trim()));
    }
    b.writeln(_divider());

    // 3. 2-Line Item Layout
    for (final l in doc.lines) {
      // Line 1: Product name & line subtotal (wraps cleanly if name is long)
      final subtotal = money(l.lineTotalMinor);
      if (l.name.length + subtotal.length + 1 <= widthChars) {
        b.writeln(_leftRight(l.name, subtotal));
      } else {
        b
          ..writeln(l.name)
          ..writeln(_right(subtotal));
      }

      // Line 2: [Qty] [Unit] X [UnitPrice] (e.g. 75 crt X 44.800)
      final unitPart =
          l.unit != null && l.unit!.trim().isNotEmpty
              ? ' ${l.unit!.trim()}'
              : '';
      b.writeln('  ${l.qty}$unitPart X ${_group(l.unitPriceMinor)}');

      // Line 3: Discount if applicable
      if (l.discountMinor > 0) {
        b.writeln(_leftRight('  Diskon', '-${money(l.discountMinor)}'));
      }
    }
    b.writeln(_divider());

    // 4. Summary & Totals
    if (doc.config.showItemCount) {
      b.writeln(_leftRight('ITEM', doc.calculatedItemCount));
    }
    b.writeln(_leftRight('Subtotal', money(doc.subtotalMinor)));
    if (doc.discountMinor > 0) {
      b.writeln(_leftRight('Diskon', '-${money(doc.discountMinor)}'));
    }
    if (doc.taxMinor > 0) {
      b.writeln(_leftRight('Pajak', money(doc.taxMinor)));
    }
    if (doc.shippingMinor > 0) {
      b.writeln(_leftRight('Ongkir', money(doc.shippingMinor)));
    }
    if (doc.roundingMinor != 0) {
      b.writeln(_leftRight('Pembulatan', money(doc.roundingMinor)));
    }
    b
      ..writeln(_leftRight('JUMLAH TOTAL', money(doc.grandTotalMinor)))
      ..writeln(
        _leftRight(
          doc.paymentLabel.isNotEmpty ? doc.paymentLabel : 'Dibayar',
          money(doc.paidMinor),
        ),
      );

    if (doc.changeMinor > 0) {
      b.writeln(_leftRight('Kembali', money(doc.changeMinor)));
    }
    if (doc.dueMinor > 0) {
      b.writeln(_leftRight('Sisa (piutang)', money(doc.dueMinor)));
    }

    // 5. Footer & Signature / QR
    b.writeln(_divider());
    final footer = doc.effectiveFooter;
    if (footer.isNotEmpty) {
      b.writeln(_center(footer));
    }

    if (doc.config.showSignature) {
      b
        ..writeln()
        ..writeln(_center('Tanda Tangan / Stempel'))
        ..writeln()
        ..writeln()
        ..writeln(_center('(....................)'));
    }

    if (doc.config.showQr) {
      final qr = doc.effectiveQrPayload;
      if (qr.isNotEmpty) {
        b
          ..writeln()
          ..writeln(_center('[ QR: $qr ]'));
      }
    }

    return b.toString();
  }

  /// Legacy helper method maintaining backward compatibility.
  String render({
    required String storeName,
    String? tagline,
    String? transactionId,
    required String number,
    required String dateTimeLocal,
    required List<ReceiptItem> lines,
    required int subtotalMinor,
    int discountMinor = 0,
    int taxMinor = 0,
    int shippingMinor = 0,
    int roundingMinor = 0,
    required int grandTotalMinor,
    required int paidMinor,
    required int dueMinor,
    int changeMinor = 0,
    required String paymentLabel,
    String? customerName,
    String? operatorName,
    String? footerNote,
    String? totalItemCount,
    String currencySymbol = 'Rp',
    ReceiptConfig config = const ReceiptConfig(),
  }) {
    return renderDocument(
      ReceiptDocument(
        storeName: storeName,
        tagline: tagline,
        transactionId: transactionId,
        invoiceNumber: number,
        dateTimeLocal: dateTimeLocal,
        lines: lines,
        subtotalMinor: subtotalMinor,
        discountMinor: discountMinor,
        taxMinor: taxMinor,
        shippingMinor: shippingMinor,
        roundingMinor: roundingMinor,
        grandTotalMinor: grandTotalMinor,
        paidMinor: paidMinor,
        dueMinor: dueMinor,
        changeMinor: changeMinor,
        paymentLabel: paymentLabel,
        customerName: customerName,
        operatorName: operatorName,
        footerNote: footerNote,
        totalItemCount: totalItemCount,
        currencySymbol: currencySymbol,
        config: config,
      ),
    );
  }

  // ---------- primitives ----------

  String _divider() => '-' * widthChars;

  String _center(String text) {
    final t = _truncate(text);
    if (t.length >= widthChars) return t;
    final left = (widthChars - t.length) ~/ 2;
    return '${' ' * left}$t';
  }

  String _right(String text) {
    if (text.length >= widthChars) return text;
    return '${' ' * (widthChars - text.length)}$text';
  }

  String _truncate(String s) =>
      s.length <= widthChars ? s : s.substring(0, widthChars);

  String _leftRight(String left, String right) {
    var l = left;
    final r = right;
    if (l.length + r.length >= widthChars) {
      final available = widthChars - r.length - 2;
      if (available > 0) {
        l = '${l.substring(0, available)}…';
      } else {
        l = l.substring(0, (widthChars - r.length - 1).clamp(0, l.length));
      }
    }
    final spaces = widthChars - l.length - r.length;
    return '$l${' ' * (spaces > 0 ? spaces : 1)}$r';
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
