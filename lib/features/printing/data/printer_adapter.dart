import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bluetooth_printer_adapter.dart';

/// Connection type of a hardware thermal printer.
enum PrinterConnectionType { bluetooth, usb, network, mock }

/// Represents a discovered or connected thermal printer device.
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    this.type = PrinterConnectionType.bluetooth,
    this.address,
  });

  final String id;
  final String name;
  final PrinterConnectionType type;
  final String? address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Abstract contract for discovering, connecting to, and printing via thermal printers.
abstract class PrinterAdapter {
  /// Scans for available devices matching the connection type.
  Future<List<PrinterDevice>> scanDevices({PrinterConnectionType? type});

  /// Connects to the specified [device].
  Future<void> connect(PrinterDevice device);

  /// Disconnects from the current printer device.
  Future<void> disconnect();

  /// Sends raw ESC/POS byte payload to the connected printer.
  Future<void> printReceipt(Uint8List bytes);

  /// Currently connected device, or null if none.
  PrinterDevice? get currentConnectedDevice;

  /// Whether a printer is currently connected.
  bool get isConnected => currentConnectedDevice != null;
}

/// In-memory mock adapter used for tests and fallback simulation.
class MockPrinterAdapter implements PrinterAdapter {
  MockPrinterAdapter({List<PrinterDevice>? mockDevices})
      : mockDevices = mockDevices ?? const [];

  PrinterDevice? _connectedDevice;
  final List<Uint8List> printedPayloads = [];

  final List<PrinterDevice> mockDevices;

  @override
  Future<List<PrinterDevice>> scanDevices({PrinterConnectionType? type}) async {
    if (type != null) {
      return mockDevices.where((d) => d.type == type).toList();
    }
    return mockDevices;
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    _connectedDevice = device;
  }

  @override
  Future<void> disconnect() async {
    _connectedDevice = null;
  }

  @override
  Future<void> printReceipt(Uint8List bytes) async {
    printedPayloads.add(bytes);
  }

  @override
  PrinterDevice? get currentConnectedDevice => _connectedDevice;

  @override
  bool get isConnected => _connectedDevice != null;
}

/// Global provider for the active thermal printer adapter.
/// Uses [BluetoothPrinterAdapter] on real mobile devices (Android/iOS)
/// and [MockPrinterAdapter] on web, desktop host, or headless tests.
final printerAdapterProvider = Provider<PrinterAdapter>((ref) {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return MockPrinterAdapter();
  }
  return BluetoothPrinterAdapter();
});

/// Notifier holding the active paper size setting: 58 mm vs 80 mm.
class PaperSizeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // false = 58mm, true = 80mm

  void set80mm(bool is80) => state = is80;
}

final paperSizeProvider = NotifierProvider<PaperSizeNotifier, bool>(
  PaperSizeNotifier.new,
);
