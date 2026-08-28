import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/printing/data/receipt_text_renderer.dart';

ReceiptTextRenderer r(int w) => ReceiptTextRenderer(widthChars: w);

String sample({required int width, String? footer}) => r(width).render(
  storeName: 'Toko Budi Jaya',
  number: 'INV00001',
  dateTimeLocal: '25/08/2026 14:30',
  lines: [
    const ReceiptLine(
      name: 'Kopi Arabica 200g',
      qty: '2',
      priceMinor: 12000,
      totalMinor: 24000,
    ),
    const ReceiptLine(
      name: 'Gula Pasir 1kg',
      qty: '1',
      priceMinor: 15000,
      totalMinor: 15000,
    ),
  ],
  subtotalMinor: 39000,
  discountMinor: 4000,

  shippingMinor: 5000,
  roundingMinor: -1000,
  grandTotalMinor: 39000,
  paidMinor: 39000,
  dueMinor: 0,
  paymentLabel: 'TUNAI',
  customerName: 'Ibu Sari',
  footerNote: footer,
);

void main() {
  test('58mm: every line <= 32 chars', () {
    final out = sample(width: 32, footer: 'Terima kasih!');
    for (final line in out.split('\n')) {
      expect(line.length, lessThanOrEqualTo(32), reason: 'line: "$line"');
    }
  });

  test('80mm: every line <= 48 chars', () {
    final out = sample(width: 48);
    for (final line in out.split('\n')) {
      expect(line.length, lessThanOrEqualTo(48), reason: 'line: "$line"');
    }
  });

  test('contains key numbers and labels', () {
    final out = sample(width: 32);
    expect(out, contains('Toko Budi Jaya'));
    expect(out, contains('INV00001'));
    expect(out, contains('TOTAL'));
    expect(out, contains('Rp39.000'));
    expect(out, contains('TUNAI'));
    expect(out, endsWith('\n'));
  });

  test('footer overrides default thanks line', () {
    final withFooter = sample(width: 32, footer: 'Sampai jumpa!');
    expect(withFooter, contains('Sampai jumpa!'));
    expect(withFooter, isNot(contains('Terima kasih!')));
  });

  test('long store name truncated to width', () {
    final out = r(32).render(
      storeName: 'Toko Sangat Panjang Sekali Namanya',
      number: 'X1',
      dateTimeLocal: '-',
      lines: const [],
      subtotalMinor: 0,
      grandTotalMinor: 0,
      paidMinor: 0,
      dueMinor: 0,
      paymentLabel: 'TUNAI',
    );
    for (final line in out.split('\n')) {
      expect(line.length, lessThanOrEqualTo(32));
    }
  });
}
