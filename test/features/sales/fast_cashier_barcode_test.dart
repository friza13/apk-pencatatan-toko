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

    testWidgets('captures keystrokes ending with Tab suffix', (tester) async {
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

      for (final char in '123456'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(
            LogicalKeyboardKey.digit0.keyId + int.parse(char),
          ),
          character: char,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(scannedBarcode, equals('123456'));
    });

    testWidgets('does not capture or fire when enabled is false', (
      tester,
    ) async {
      String? scannedBarcode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarcodeScannerListener(
              enabled: false,
              onBarcodeScanned: (code) => scannedBarcode = code,
              child: const Text('POS Body'),
            ),
          ),
        ),
      );

      for (final char in '123456'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(
            LogicalKeyboardKey.digit0.keyId + int.parse(char),
          ),
          character: char,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(scannedBarcode, isNull);
    });

    testWidgets(
      'consumes fast burst keystrokes so barcode is scanned cleanly',
      (tester) async {
        String? scannedBarcode;
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BarcodeScannerListener(
                onBarcodeScanned: (code) {
                  scannedBarcode = code;
                  controller.clear();
                },
                child: TextField(
                  controller: controller,
                  autofocus: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        for (final char in '899123'.split('')) {
          await tester.sendKeyEvent(
            LogicalKeyboardKey(
              LogicalKeyboardKey.digit0.keyId + int.parse(char),
            ),
            character: char,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(scannedBarcode, equals('899123'));
        expect(controller.text, isEmpty);
      },
    );
  });
}
