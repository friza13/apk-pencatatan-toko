import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/csv/csv_builder.dart';

void main() {
  group('CsvBuilder (RFC4180, D-015)', () {
    test('plain cells joined by comma, CRLF rows', () {
      final csv = CsvBuilder()
        ..row(['Tanggal', 'Nota', 'Total'])
        ..row(['2026-08-25', 'INV00001', 36000]);
      expect(
        csv.build(includeBom: false),
        'Tanggal,Nota,Total\r\n2026-08-25,INV00001,36000',
      );
    });

    test('quotes doubled; comma forces quoting', () {
      final csv = CsvBuilder()..row(['Kopi "Arabica", 200g']);
      expect(csv.build(includeBom: false), '"Kopi ""Arabica"", 200g"');
    });

    test('newline inside cell forces quoting and is preserved', () {
      final csv = CsvBuilder()..row(['baris1\nbaris2']);
      expect(csv.build(includeBom: false), '"baris1\nbaris2"');
    });

    test('null becomes empty cell', () {
      final csv = CsvBuilder()..row([null, 'x', null]);
      expect(csv.build(includeBom: false), ',x,');
    });

    test('UTF-8 BOM included by default for Excel compatibility', () {
      final csv = CsvBuilder()..row(['é']);
      expect(csv.build().codeUnitAt(0), 0xFEFF);
    });
  });
}
