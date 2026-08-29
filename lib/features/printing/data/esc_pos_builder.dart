import 'dart:convert';
import 'dart:typed_data';

import '../domain/receipt_document.dart';

/// Builds raw ESC/POS byte commands for 58 mm (32 cols) and 80 mm (48 cols)
/// thermal POS printers.
class EscPosBuilder {
  const EscPosBuilder({required this.is80mm});

  final bool is80mm;

  int get widthChars => is80mm ? 48 : 32;

  // ESC/POS command constants
  static const int _esc = 0x1B;
  static const int _gs = 0x1D;

  /// Builds a complete ESC/POS byte sequence for the given [ReceiptDocument].
  Uint8List build(ReceiptDocument document) {
    final buffer = BytesBuilder()..add([_esc, 0x40]);

    // 2. Header (Centered, Bold Store Name)
    _setAlign(buffer, 1);
    _setBold(buffer, true);
    _setTextSize(buffer, widthDouble: true, heightDouble: true);
    buffer.add(latin1.encode('${document.storeName}\n'));
    _setTextSize(buffer, widthDouble: false, heightDouble: false);
    _setBold(buffer, false);

    if (document.config.showTagline &&
        document.tagline != null &&
        document.tagline!.trim().isNotEmpty) {
      buffer.add(latin1.encode('${document.tagline!.trim()}\n'));
    }

    _setAlign(buffer, 0);
    _addDivider(buffer);

    // 3. Metadata Grid (Left-Right)
    if (document.transactionId != null &&
        document.transactionId!.trim().isNotEmpty) {
      _addLeftRight(buffer, 'No. Ref', document.transactionId!.trim());
    }
    _addLeftRight(buffer, 'No. Nota', document.invoiceNumber);
    _addLeftRight(buffer, 'Tanggal', document.dateTimeLocal);
    if (document.customerName != null &&
        document.customerName!.trim().isNotEmpty) {
      _addLeftRight(buffer, 'Pelanggan', document.customerName!.trim());
    }
    if (document.config.showOperator &&
        document.operatorName != null &&
        document.operatorName!.trim().isNotEmpty) {
      _addLeftRight(buffer, 'Kasir', document.operatorName!.trim());
    }

    _addDivider(buffer);

    // 4. 2-Line Items
    for (final item in document.lines) {
      _setBold(buffer, true);
      final priceStr = _money(item.lineTotalMinor, document.currencySymbol);
      if (item.name.length + priceStr.length + 1 <= widthChars) {
        _addLeftRight(buffer, item.name, priceStr);
      } else {
        buffer.add(latin1.encode('${item.name}\n'));
        _addRight(buffer, priceStr);
      }
      _setBold(buffer, false);

      final unitPart =
          item.unit != null && item.unit!.trim().isNotEmpty
              ? ' ${item.unit!.trim()}'
              : '';
      buffer.add(
        latin1.encode(
          '  ${item.qty}$unitPart X ${_group(item.unitPriceMinor)}\n',
        ),
      );

      if (item.discountMinor > 0) {
        _addLeftRight(
          buffer,
          '  Diskon',
          '-${_money(item.discountMinor, document.currencySymbol)}',
        );
      }
    }

    _addDivider(buffer);

    // 5. Summary & Totals
    if (document.config.showItemCount) {
      _addLeftRight(buffer, 'ITEM', document.calculatedItemCount);
    }
    _addLeftRight(
      buffer,
      'Subtotal',
      _money(document.subtotalMinor, document.currencySymbol),
    );
    if (document.discountMinor > 0) {
      _addLeftRight(
        buffer,
        'Diskon',
        '-${_money(document.discountMinor, document.currencySymbol)}',
      );
    }
    if (document.taxMinor > 0) {
      _addLeftRight(
        buffer,
        'Pajak',
        _money(document.taxMinor, document.currencySymbol),
      );
    }
    if (document.shippingMinor > 0) {
      _addLeftRight(
        buffer,
        'Ongkir',
        _money(document.shippingMinor, document.currencySymbol),
      );
    }
    if (document.roundingMinor != 0) {
      _addLeftRight(
        buffer,
        'Pembulatan',
        _money(document.roundingMinor, document.currencySymbol),
      );
    }

    _setBold(buffer, true);
    _addLeftRight(
      buffer,
      'JUMLAH TOTAL',
      _money(document.grandTotalMinor, document.currencySymbol),
    );
    _setBold(buffer, false);

    _addLeftRight(
      buffer,
      document.paymentLabel.isNotEmpty ? document.paymentLabel : 'Dibayar',
      _money(document.paidMinor, document.currencySymbol),
    );

    if (document.changeMinor > 0) {
      _addLeftRight(
        buffer,
        'Kembali',
        _money(document.changeMinor, document.currencySymbol),
      );
    }
    if (document.dueMinor > 0) {
      _addLeftRight(
        buffer,
        'Sisa (piutang)',
        _money(document.dueMinor, document.currencySymbol),
      );
    }

    _addDivider(buffer);

    // 6. Footer & Signature / QR
    final footer = document.effectiveFooter;
    if (footer.isNotEmpty) {
      _setAlign(buffer, 1);
      buffer.add(latin1.encode('$footer\n'));
    }

    if (document.config.showSignature) {
      _setAlign(buffer, 1);
      buffer.add(
        latin1.encode('\nTanda Tangan / Stempel\n\n\n(....................)\n'),
      );
    }

    if (document.config.showQr) {
      final qr = document.effectiveQrPayload;
      if (qr.isNotEmpty) {
        _setAlign(buffer, 1);
        _addQrCode(buffer, qr);
      }
    }

    // 7. Feed 3 lines & Paper Cut (Full cut with feed)
    buffer
      ..add([_esc, 0x64, 0x03]) // ESC d 3
      ..add([_gs, 0x56, 0x41, 0x10]); // GS V 'A' 16

    return buffer.toBytes();
  }

  /// Builds a sample test print payload.
  Uint8List buildTestPrint({required String storeName}) {
    final buffer = BytesBuilder()..add([_esc, 0x40]); // Init
    _setAlign(buffer, 1);
    _setBold(buffer, true);
    buffer
      ..add(latin1.encode('TEST PRINT NOTAKIT\n'))
      ..add(latin1.encode('$storeName\n'))
      ..add(latin1.encode('Printer Mode: ${is80mm ? '80 mm' : '58 mm'}\n'));
    _setBold(buffer, false);
    _addDivider(buffer);
    buffer.add(
      latin1.encode('Printer thermal Bluetooth/USB siap digunakan!\n'),
    );
    _addDivider(buffer);
    buffer
      ..add([_esc, 0x64, 0x03]) // Feed 3
      ..add([_gs, 0x56, 0x41, 0x10]); // Cut

    return buffer.toBytes();
  }

  // ---------- Helpers ----------

  void _setAlign(BytesBuilder buffer, int align) {
    // 0 = Left, 1 = Center, 2 = Right
    buffer.add([_esc, 0x61, align]);
  }

  void _setBold(BytesBuilder buffer, bool bold) {
    buffer.add([_esc, 0x45, bold ? 1 : 0]);
  }

  void _setTextSize(
    BytesBuilder buffer, {
    required bool widthDouble,
    required bool heightDouble,
  }) {
    int n = 0;
    if (widthDouble) n |= 0x20;
    if (heightDouble) n |= 0x01;
    buffer.add([_gs, 0x21, n]);
  }

  void _addDivider(BytesBuilder buffer) {
    _setAlign(buffer, 0);
    buffer.add(latin1.encode('${'-' * widthChars}\n'));
  }

  void _addRight(BytesBuilder buffer, String text) {
    if (text.length >= widthChars) {
      buffer.add(latin1.encode('$text\n'));
      return;
    }
    final spaces = widthChars - text.length;
    buffer.add(latin1.encode('${' ' * spaces}$text\n'));
  }

  void _addLeftRight(BytesBuilder buffer, String left, String right) {
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
    buffer.add(
      latin1.encode('$l${' ' * (spaces > 0 ? spaces : 1)}$r\n'),
    );
  }

  void _addQrCode(BytesBuilder buffer, String data) {
    final bytes = utf8.encode(data);
    final len = bytes.length + 3;
    final pL = len % 256;
    final pH = len ~/ 256;

    // Model type (Model 2), Size (4), Error correction (L), Store data, Print QR
    buffer
      ..add([_gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00])
      ..add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04])
      ..add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30])
      ..add([_gs, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...bytes])
      ..add([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30])
      ..add(latin1.encode('\n'));
  }

  static String _money(int amount, String symbol) => '$symbol${_group(amount)}';

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
