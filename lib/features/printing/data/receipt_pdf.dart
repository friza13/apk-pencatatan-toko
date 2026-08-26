import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a shareable/printable PDF of the receipt using a monospace font so
/// column alignment matches the text renderer.
class ReceiptPdf {
  ReceiptPdf._();

  /// Returns PDF bytes sized to the receipt width (58/80 mm).
  static Future<List<int>> build({
    required String text,
    required bool is80mm,
  }) async {
    final doc = pw.Document();
    final widthMm = is80mm ? 80.0 : 58.0;
    final font = pw.Font.courier();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(widthMm, 297, marginAll: 5 * 72 / 25.4),        build: (context) => pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      ),
    );
    return doc.save();
  }
}

