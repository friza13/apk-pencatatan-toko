import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/features/printing/data/bluetooth_printer_adapter.dart';
import 'package:notakit/features/printing/data/printer_adapter.dart';

void main() {
  group('BluetoothPrinterAdapter & Provider Platform Guard', () {
    test('printerAdapterProvider returns MockPrinterAdapter on desktop/host test environment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final adapter = container.read(printerAdapterProvider);
      expect(adapter, isA<MockPrinterAdapter>());
    });

    test('BluetoothPrinterAdapter throws ArgumentError on connect when device address is empty', () async {
      final adapter = BluetoothPrinterAdapter();

      const invalidDevice = PrinterDevice(
        id: '',
        name: 'No MAC Printer',
        address: '',
      );

      expect(
        () => adapter.connect(invalidDevice),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BluetoothPrinterAdapter returns empty list when scanning non-bluetooth type', () async {
      final adapter = BluetoothPrinterAdapter();

      final devices = await adapter.scanDevices(type: PrinterConnectionType.usb);
      expect(devices, isEmpty);
    });
  });
}
