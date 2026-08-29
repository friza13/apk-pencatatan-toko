import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/sales/presentation/widgets/barcode_scanner_listener.dart';

void main() {
  group('BarcodeScannerListener', () {
    testWidgets('captures keystroke stream and fires onBarcodeScanned on Enter', (
      tester,
    ) async {
      String? scannedBarcode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarcodeScannerListener(
              onBarcodeScanned: (code) => scannedBarcode = code,
              child: const Text('POS Body'),
            ),
          ),
        ),
      );

      // Simulate typing barcode "8991234567890" followed by Enter
      for (final char in '8991234567890'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(
            LogicalKeyboardKey.digit0.keyId + int.parse(char),
          ),
          character: char,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(scannedBarcode, equals('8991234567890'));
    });
  });
}
