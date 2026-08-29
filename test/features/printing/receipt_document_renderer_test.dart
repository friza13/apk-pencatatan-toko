import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/printing/data/receipt_pdf.dart';
import 'package:notakit/features/printing/data/receipt_text_renderer.dart';

void main() {
  ReceiptDocument createSampleDoc({
    ReceiptConfig config = const ReceiptConfig(),
    String? tagline = 'Grosir Sembako & Kebutuhan',
    String? transactionId = 'TRX-100234',
    String? customerName = 'Ibu Sari',
    String? operatorName = 'admin',
    String? footerNote,
    List<ReceiptItem>? lines,
    int subtotalMinor = 3375000,
    int discountMinor = 15000,
    int taxMinor = 0,
    int shippingMinor = 0,
    int roundingMinor = 0,
    int grandTotalMinor = 3360000,
    int paidMinor = 3400000,
    int dueMinor = 0,
    int changeMinor = 40000,
    String paymentLabel = 'TUNAI',
  }) {
    return ReceiptDocument(
      storeName: 'Puri Abadi',
      tagline: tagline,
      transactionId: transactionId,
      invoiceNumber: '#INV/2026/08/001',
      dateTimeLocal: '25/08/2026 14:30',
      customerName: customerName,
      operatorName: operatorName,
      lines: lines ??
          const [
            ReceiptItem(
              name: 'Minyak Goreng Sania 2L',
              qty: '75',
              unit: 'crt',
              unitPriceMinor: 44800,
              lineTotalMinor: 3360000,
            ),
            ReceiptItem(
              name: 'Gula Pasir Gulaku 1kg',
              qty: '1',
              unit: 'kg',
              unitPriceMinor: 15000,
              lineTotalMinor: 15000,
              discountMinor: 15000,
            ),
          ],
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
      footerNote: footerNote,
      config: config,
    );
  }

  group('ReceiptConfig', () {
    test('default configuration values', () {
      const config = ReceiptConfig();
      expect(config.showTagline, isTrue);
      expect(config.showOperator, isTrue);
      expect(config.showItemCount, isTrue);
      expect(config.showSignature, isTrue);
      expect(config.showQr, isTrue);
      expect(config.customFooter, 'TERIMA KASIH TELAH BELANJA DI KAMI');
      expect(config.qrPayload, isNull);
    });

    test('copyWith updates config fields', () {
      const config = ReceiptConfig();
      final updated = config.copyWith(
        showTagline: false,
        showSignature: false,
        customFooter: 'Sampai Jumpa Lagi!',
        qrPayload: 'https://notakit.app/v/123',
      );
      expect(updated.showTagline, isFalse);
      expect(updated.showOperator, isTrue);
      expect(updated.showSignature, isFalse);
      expect(updated.customFooter, 'Sampai Jumpa Lagi!');
      expect(updated.qrPayload, 'https://notakit.app/v/123');
    });
  });

  group('ReceiptDocument', () {
    test('calculates item count correctly from line quantities', () {
      final doc = createSampleDoc();
      expect(doc.calculatedItemCount, '76');
    });

    test('uses totalItemCount override when provided', () {
      final doc = ReceiptDocument(
        storeName: 'Toko Budi',
        invoiceNumber: 'INV-1',
        dateTimeLocal: '25/08/2026 10:00',
        lines: const [],
        subtotalMinor: 0,
        grandTotalMinor: 0,
        paidMinor: 0,
        paymentLabel: 'TUNAI',
        totalItemCount: '99',
      );
      expect(doc.calculatedItemCount, '99');
    });

    test('effectiveFooter falls back to config customFooter', () {
      final doc = createSampleDoc();
      expect(doc.effectiveFooter, 'TERIMA KASIH TELAH BELANJA DI KAMI');

      final customDoc = createSampleDoc(footerNote: 'Barang yang dibeli tidak dapat ditukar');
      expect(customDoc.effectiveFooter, 'Barang yang dibeli tidak dapat ditukar');
    });

    test('effectiveQrPayload defaults to invoiceNumber', () {
      final doc = createSampleDoc();
      expect(doc.effectiveQrPayload, '#INV/2026/08/001');

      final docWithCustomQr = createSampleDoc(
        config: const ReceiptConfig(qrPayload: 'https://example.com/inv/1'),
      );
      expect(docWithCustomQr.effectiveQrPayload, 'https://example.com/inv/1');
    });
  });

  group('ReceiptTextRenderer 2-Line Canonical Rendering', () {
    test('renders header with store name and tagline', () {
      final doc = createSampleDoc();
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      expect(text, contains('Puri Abadi'));
      expect(text, contains('Grosir Sembako'));
    });

    test('omits tagline when showTagline is false', () {
      final doc = createSampleDoc(
        config: const ReceiptConfig(showTagline: false),
      );
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      expect(text, contains('Puri Abadi'));
      expect(text, isNot(contains('Grosir Sembako')));
    });

    test('renders metadata grid with ref, invoice number, date, customer, cashier', () {
      final doc = createSampleDoc();
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      expect(text, contains('No. Ref'));
      expect(text, contains('TRX-100234'));
      expect(text, contains('No. Nota'));
      expect(text, contains('#INV/2026/08/001'));
      expect(text, contains('Tanggal'));
      expect(text, contains('25/08/2026 14:30'));
      expect(text, contains('Pelanggan'));
      expect(text, contains('Ibu Sari'));
      expect(text, contains('Kasir'));
      expect(text, contains('admin'));
    });

    test('renders 2-line item layout matching Puri Abadi sample', () {
      final doc = createSampleDoc();
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      // Line 1: Product name and right aligned line total
      expect(text, contains('Minyak Goreng'));
      expect(text, contains('Rp3.360.000'));

      // Line 2: [Qty] [Unit] X [UnitPrice] (e.g. 75 crt X 44.800)
      expect(text, contains('75 crt X 44.800'));

      // Line 3: Discount if applicable
      expect(text, contains('Diskon'));
      expect(text, contains('-Rp15.000'));
    });

    test('renders summary totals with ITEM count, subtotal, discount, grand total, paid, change', () {
      final doc = createSampleDoc();
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      expect(text, contains('ITEM'));
      expect(text, contains('76'));
      expect(text, contains('Subtotal'));
      expect(text, contains('Rp3.375.000'));
      expect(text, contains('Diskon'));
      expect(text, contains('-Rp15.000'));
      expect(text, contains('JUMLAH TOTAL'));
      expect(text, contains('Rp3.360.000'));
      expect(text, contains('TUNAI'));
      expect(text, contains('Rp3.400.000'));
      expect(text, contains('Kembali'));
      expect(text, contains('Rp40.000'));
    });

    test('renders signature box and QR text placeholder when enabled', () {
      final doc = createSampleDoc();
      final renderer = ReceiptTextRenderer(widthChars: 32);
      final text = renderer.renderDocument(doc);

      expect(text, contains('Tanda Tangan / Stempel'));
      expect(text, contains('QR: #INV/2026/08/001'));
    });

    test('58mm and 80mm widths never exceed maximum line lengths', () {
      final doc = createSampleDoc();
      final r58 = ReceiptTextRenderer(widthChars: 32);
      final text58 = r58.renderDocument(doc);
      for (final line in text58.split('\n')) {
        expect(line.length, lessThanOrEqualTo(32), reason: 'Line too long for 58mm: "$line"');
      }

      final r80 = ReceiptTextRenderer(widthChars: 48);
      final text80 = r80.renderDocument(doc);
      for (final line in text80.split('\n')) {
        expect(line.length, lessThanOrEqualTo(48), reason: 'Line too long for 80mm: "$line"');
      }
    });
  });

  group('ReceiptPdf High-Res Thermal Slip', () {
    test('generates valid PDF bytes for 58mm and 80mm with ReceiptDocument', () async {
      final doc = createSampleDoc();

      final bytes58 = await ReceiptPdf.build(document: doc, is80mm: false);
      expect(bytes58, isNotEmpty);
      final header58 = String.fromCharCodes(Uint8List.fromList(bytes58).take(5));
      expect(header58, '%PDF-');

      final bytes80 = await ReceiptPdf.build(document: doc, is80mm: true);
      expect(bytes80, isNotEmpty);
      final header80 = String.fromCharCodes(Uint8List.fromList(bytes80).take(5));
      expect(header80, '%PDF-');
    });

    test('supports fallback monospace PDF from text', () async {
      final bytes = await ReceiptPdf.build(text: 'Sample Monospace Receipt', is80mm: false);
      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(Uint8List.fromList(bytes).take(5));
      expect(header, '%PDF-');
    });
  });
}
