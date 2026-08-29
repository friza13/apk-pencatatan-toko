import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/esc_pos_builder.dart';
import '../data/printer_adapter.dart';

/// Screen for managing Bluetooth and USB thermal printers, paper sizes, and test prints.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isScanning = false;
  List<PrinterDevice> _devices = [];

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    try {
      final adapter = ref.read(printerAdapterProvider);
      final devices = await adapter.scanDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _testPrint() async {
    final adapter = ref.read(printerAdapterProvider);
    final is80 = ref.read(paperSizeProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (!adapter.isConnected) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan hubungkan printer thermal terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    try {
      final builder = EscPosBuilder(is80mm: is80);
      final bytes = builder.buildTestPrint(storeName: 'Toko Saya');
      await adapter.printReceipt(bytes);
      messenger.showSnackBar(
        const SnackBar(content: Text('Test print berhasil dikirim!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengirim test print: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  Widget build(BuildContext context) {
    final adapter = ref.watch(printerAdapterProvider);
    final is80 = ref.watch(paperSizeProvider);
    final connected = adapter.currentConnectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Thermal'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scan,
            tooltip: 'Pindai Ulang',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ukuran Kertas Struk',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('58 mm (Standard)'),
                      ),
                      ButtonSegment(value: true, label: Text('80 mm (Lebar)')),
                    ],
                    selected: {is80},
                    onSelectionChanged: (s) {
                      ref.read(paperSizeProvider.notifier).set80mm(s.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (connected != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(connected.name),
                subtitle: Text(
                  'Terhubung • ${connected.type.name.toUpperCase()} ${connected.address ?? ''}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await adapter.disconnect();
                    setState(() {});
                  },
                  child: const Text('Putus'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Perangkat Tersedia',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_devices.isEmpty && !_isScanning)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tidak ada printer terdeteksi. Tekan tombol refresh di atas.'),
              ),
            ),
          for (final d in _devices)
            Card(
              child: ListTile(
                leading: Icon(
                  d.type == PrinterConnectionType.bluetooth
                      ? Icons.bluetooth
                      : Icons.usb,
                ),
                title: Text(d.name),
                subtitle: Text('${d.type.name.toUpperCase()} • ${d.address ?? '-'}'),
                trailing: connected?.id == d.id
                    ? const Chip(label: Text('Aktif'))
                    : FilledButton.tonal(
                        onPressed: () async {
                          await adapter.connect(d);
                          setState(() {});
                        },
                        child: const Text('Hubungkan'),
                      ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.print_outlined),
            label: const Text('Cetak Uji Coba (Test Print)'),
            onPressed: _testPrint,
          ),
        ],
      ),
    );
  }
}
