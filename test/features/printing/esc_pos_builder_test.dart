import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/printing/data/esc_pos_builder.dart';
import 'package:notakit/features/printing/data/printer_adapter.dart';
import 'package:notakit/features/printing/domain/receipt_document.dart';

void main() {
  ReceiptDocument createTestDocument({bool is80mm = false}) {
    return ReceiptDocument(
      storeName: 'Puri Abadi',
      tagline: 'Grosir dan wholesale',
      transactionId: 'TRS3031787723961',
      invoiceNumber: '#INV00001646',
      dateTimeLocal: '26/08/2026 14:07',
      customerName: 'TOKO ACE ARS',
      operatorName: 'admin',
      lines: const [
        ReceiptItem(
          name: 'teh botol pet 350ml',
          qty: '75',
          unit: 'crt',
          unitPriceMinor: 44800,
          lineTotalMinor: 3360000,
        ),
        ReceiptItem(
          name: 'fruittea pet 350ml',
          qty: '30',
          unit: 'crt',
          unitPriceMinor: 44800,
          lineTotalMinor: 1344000,
        ),
      ],
      subtotalMinor: 4704000,
      grandTotalMinor: 4704000,
      paidMinor: 5000000,
      changeMinor: 296000,
      paymentLabel: 'TUNAI',
    );
  }

  group('EscPosBuilder', () {
    test('builds valid ESC/POS byte sequence with initialize and cut commands', () {
      final doc = createTestDocument();
      final builder = EscPosBuilder(is80mm: false);
      final bytes = builder.build(doc);

      expect(bytes, isNotEmpty);
      // Starts with ESC @ (0x1B, 0x40) to initialize printer
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      // Ends with feed and cut sequence (0x1D, 0x56)
      expect(bytes, containsAllInOrder([0x1D, 0x56, 0x41]));
    });

    test('includes store name, invoice number, items, and totals in raw text payload', () {
      final doc = createTestDocument();
      final builder = EscPosBuilder(is80mm: false);
      final bytes = builder.build(doc);
      final rawText = String.fromCharCodes(bytes);

      expect(rawText, contains('Puri Abadi'));
      expect(rawText, contains('Grosir dan wholesale'));
      expect(rawText, contains('#INV00001646'));
      expect(rawText, contains('TOKO ACE ARS'));
      expect(rawText, contains('teh botol pet 350ml'));
      expect(rawText, contains('75 crt X 44.800'));
      expect(rawText, contains('ITEM'));
      expect(rawText, contains('JUMLAH TOTAL'));
      expect(rawText, contains('Rp4.704.000'));
    });

    test('generates valid test print payload', () {
      final builder = EscPosBuilder(is80mm: false);
      final testBytes = builder.buildTestPrint(storeName: 'Puri Abadi');

      expect(testBytes, isNotEmpty);
      final rawText = String.fromCharCodes(testBytes);
      expect(rawText, contains('TEST PRINT NOTAKIT'));
      expect(rawText, contains('Puri Abadi'));
      expect(rawText, contains('58 mm'));
    });
  });

  group('PrinterAdapter Contract & Mock', () {
    test('MockPrinterAdapter records printed bytes and tracks connection state', () async {
      final adapter = MockPrinterAdapter(
        mockDevices: const [
          PrinterDevice(
            id: 'dev_1',
            name: 'Mock BT Printer',
            address: '11:22:33:44:55:66',
          ),
        ],
      );
      expect(adapter.currentConnectedDevice, isNull);

      final devices = await adapter.scanDevices();
      expect(devices, isNotEmpty);

      final device = devices.first;
      await adapter.connect(device);
      expect(adapter.currentConnectedDevice, equals(device));
      expect(adapter.isConnected, isTrue);

      final testBytes = Uint8List.fromList([1, 2, 3, 4]);
      await adapter.printReceipt(testBytes);
      expect(adapter.printedPayloads, hasLength(1));
      expect(adapter.printedPayloads.first, equals(testBytes));

      await adapter.disconnect();
      expect(adapter.currentConnectedDevice, isNull);
      expect(adapter.isConnected, isFalse);
    });
  });
}
