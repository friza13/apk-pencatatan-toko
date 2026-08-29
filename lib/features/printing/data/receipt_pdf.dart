import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/receipt_document.dart';

/// Builds a high-resolution printable/shareable thermal receipt PDF.
class ReceiptPdf {
  ReceiptPdf._();

  /// Returns PDF bytes sized to thermal roll width (58 mm or 80 mm).
  ///
  /// If [document] is provided, renders a rich layout with typography,
  /// 2-line items, totals, signature box, and QR code barcode.
  /// If only [text] is provided, falls back to monospace plain-text layout.
  static Future<List<int>> build({
    ReceiptDocument? document,
    String? text,
    required bool is80mm,
  }) async {
    final doc = pw.Document();
    final widthPt = (is80mm ? 80.0 : 58.0) * PdfPageFormat.mm;
    final marginPt = (is80mm ? 4.0 : 3.0) * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      widthPt,
      double.infinity,
      marginAll: marginPt,
    );

    if (document != null) {
      final titleFontSize = is80mm ? 12.0 : 10.0;
      final subFontSize = is80mm ? 7.5 : 6.5;
      final metaFontSize = is80mm ? 7.5 : 6.5;
      final itemFontSize = is80mm ? 7.5 : 6.5;
      final itemSubFontSize = is80mm ? 6.5 : 5.5;
      final totalFontSize = is80mm ? 9.5 : 8.0;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // 1. Header
                pw.Center(
                  child: pw.Text(
                    document.storeName,
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: titleFontSize,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (document.config.showTagline &&
                    document.tagline != null &&
                    document.tagline!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      document.tagline!.trim(),
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: subFontSize,
                        color: PdfColors.grey800,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 2),

                // 2. Metadata Grid
                if (document.transactionId != null &&
                    document.transactionId!.trim().isNotEmpty)
                  _pdfKv(
                    'No. Ref',
                    document.transactionId!.trim(),
                    metaFontSize,
                  ),
                _pdfKv('No. Nota', document.invoiceNumber, metaFontSize),
                _pdfKv('Tanggal', document.dateTimeLocal, metaFontSize),
                if (document.customerName != null &&
                    document.customerName!.trim().isNotEmpty)
                  _pdfKv(
                    'Pelanggan',
                    document.customerName!.trim(),
                    metaFontSize,
                  ),
                if (document.config.showOperator &&
                    document.operatorName != null &&
                    document.operatorName!.trim().isNotEmpty)
                  _pdfKv('Kasir', document.operatorName!.trim(), metaFontSize),

                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 2),

                // 3. 2-Line Items Table
                for (final item in document.lines) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          item.name,
                          style: pw.TextStyle(
                            font: pw.Font.helveticaBold(),
                            fontSize: itemFontSize,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        _money(item.lineTotalMinor, document.currencySymbol),
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: itemFontSize,
                        ),
                      ),
                    ],
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 2, top: 1),
                    child: pw.Text(
                      '${item.qty}${item.unit != null && item.unit!.trim().isNotEmpty ? ' ${item.unit!.trim()}' : ''} X ${_group(item.unitPriceMinor)}',
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: itemSubFontSize,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  if (item.discountMinor > 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 2, top: 1),
                      child: pw.Text(
                        'Diskon: -${_money(item.discountMinor, document.currencySymbol)}',
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: itemSubFontSize,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 3),
                ],

                pw.Divider(thickness: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 2),

                // 4. Summary & Totals
                if (document.config.showItemCount)
                  _pdfKv('ITEM', document.calculatedItemCount, metaFontSize),
                _pdfKv(
                  'Subtotal',
                  _money(document.subtotalMinor, document.currencySymbol),
                  metaFontSize,
                ),
                if (document.discountMinor > 0)
                  _pdfKv(
                    'Diskon',
                    '-${_money(document.discountMinor, document.currencySymbol)}',
                    metaFontSize,
                  ),
                if (document.taxMinor > 0)
                  _pdfKv(
                    'Pajak',
                    _money(document.taxMinor, document.currencySymbol),
                    metaFontSize,
                  ),
                if (document.shippingMinor > 0)
                  _pdfKv(
                    'Ongkir',
                    _money(document.shippingMinor, document.currencySymbol),
                    metaFontSize,
                  ),
                if (document.roundingMinor != 0)
                  _pdfKv(
                    'Pembulatan',
                    _money(document.roundingMinor, document.currencySymbol),
                    metaFontSize,
                  ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'JUMLAH TOTAL',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: totalFontSize,
                      ),
                    ),
                    pw.Text(
                      _money(document.grandTotalMinor, document.currencySymbol),
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: totalFontSize,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                _pdfKv(
                  document.paymentLabel.isNotEmpty
                      ? document.paymentLabel
                      : 'Dibayar',
                  _money(document.paidMinor, document.currencySymbol),
                  metaFontSize,
                ),
                if (document.changeMinor > 0)
                  _pdfKv(
                    'Kembali',
                    _money(document.changeMinor, document.currencySymbol),
                    metaFontSize,
                  ),
                if (document.dueMinor > 0)
                  _pdfKv(
                    'Sisa (piutang)',
                    _money(document.dueMinor, document.currencySymbol),
                    metaFontSize,
                  ),

                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 3),

                // 5. Footer Note
                if (document.effectiveFooter.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      document.effectiveFooter,
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: subFontSize,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),

                // 6. Signature Box & QR Code
                if (document.config.showSignature ||
                    document.config.showQr) ...[
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (document.config.showSignature)
                        pw.Column(
                          children: [
                            pw.Text(
                              'Tanda Tangan / Stempel',
                              style: pw.TextStyle(
                                font: pw.Font.helvetica(),
                                fontSize: 6,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              '(....................)',
                              style: pw.TextStyle(
                                font: pw.Font.helvetica(),
                                fontSize: 6,
                              ),
                            ),
                          ],
                        )
                      else
                        pw.SizedBox(),
                      if (document.config.showQr &&
                          document.effectiveQrPayload.isNotEmpty)
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: document.effectiveQrPayload,
                          width: is80mm ? 42 : 34,
                          height: is80mm ? 42 : 34,
                        )
                      else
                        pw.SizedBox(),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );
    } else {
      final font = pw.Font.courier();
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build:
              (context) => pw.Text(
                text ?? '',
                style: pw.TextStyle(font: font, fontSize: is80mm ? 9 : 8),
              ),
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _pdfKv(String k, String v, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            k,
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: fontSize,
              color: PdfColors.grey800,
            ),
          ),
          pw.Text(
            v,
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
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
