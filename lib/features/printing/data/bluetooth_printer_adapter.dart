import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_adapter.dart';

/// Real hardware Bluetooth thermal printer adapter using [PrintBluetoothThermal].
class BluetoothPrinterAdapter implements PrinterAdapter {
  BluetoothPrinterAdapter();

  PrinterDevice? _connectedDevice;

  @override
  PrinterDevice? get currentConnectedDevice => _connectedDevice;

  @override
  bool get isConnected => _connectedDevice != null;

  @override
  Future<List<PrinterDevice>> scanDevices({PrinterConnectionType? type}) async {
    if (type != null && type != PrinterConnectionType.bluetooth) {
      return [];
    }

    final bool isGranted =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!isGranted) {
      return [];
    }

    final List<BluetoothInfo> paired =
        await PrintBluetoothThermal.pairedBluetooths;

    return paired.map((b) {
      final name = b.name.trim();
      final mac = b.macAdress.trim();
      return PrinterDevice(
        id: mac.isNotEmpty ? mac : name,
        name: name.isNotEmpty ? name : 'Printer Thermal ($mac)',
        address: mac,
      );
    }).toList();
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    final mac = device.address ?? device.id;
    if (mac.isEmpty) {
      throw ArgumentError('Alamat MAC printer tidak valid.');
    }

    final bool connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: mac,
    );
    if (connected) {
      _connectedDevice = device;
    } else {
      throw StateError(
        'Gagal menyambungkan ke printer "${device.name}". '
        'Pastikan printer aktif dan Bluetooth menyala.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    _connectedDevice = null;
  }

  @override
  Future<void> printReceipt(Uint8List bytes) async {
    final bool status = await PrintBluetoothThermal.connectionStatus;
    if (!status) {
      _connectedDevice = null;
      throw StateError('Printer thermal belum terhubung.');
    }

    final bool success = await PrintBluetoothThermal.writeBytes(bytes);
    if (!success) {
      throw StateError('Gagal mengirim data struk ke printer thermal.');
    }
  }
}
