import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/receipt_text_renderer.dart';

/// Screen allowing the shop owner to customize receipt layouts, toggles, and footer notes.
class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen> {
  late TextEditingController _taglineCtrl;
  late TextEditingController _footerCtrl;
  bool _is80mm = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(receiptConfigProvider);
    _taglineCtrl = TextEditingController(text: 'Grosir dan wholesale');
    _footerCtrl = TextEditingController(text: config.customFooter);
  }

  @override
  void dispose() {
    _taglineCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  ReceiptDocument _buildPreviewDoc(ReceiptConfig config) {
    return ReceiptDocument(
      storeName: 'Puri Abadi',
      tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
      transactionId: 'TRX-100234',
      invoiceNumber: '#INV/2026/08/001',
      dateTimeLocal: '26/08/2026 14:07',
      customerName: 'Toko Sumber Rejeki',
      operatorName: 'admin (kasir 1)',
      lines: const [
        ReceiptItem(
          name: 'Teh Botol Sosro 350ml',
          qty: '75',
          unit: 'crt',
          unitPriceMinor: 44800,
          lineTotalMinor: 3360000,
        ),
        ReceiptItem(
          name: 'Fruit Tea Apel 350ml',
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
      footerNote: _footerCtrl.text.trim(),
      config: config,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(receiptConfigProvider);
    final notifier = ref.read(receiptConfigProvider.notifier);
    final previewDoc = _buildPreviewDoc(config);
    final renderer = ReceiptTextRenderer(widthChars: _is80mm ? 48 : 32);
    final previewText = renderer.renderDocument(previewDoc);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desain & Format Nota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan Desain',
            onPressed: () {
              notifier.setCustomFooter(_footerCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan desain nota disimpan!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Elemen & Informasi Nota',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _taglineCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Slogan / Tagline Toko (Header)',
                      hintText: 'Contoh: Grosir dan wholesale',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pesan Footer / Penutup Nota',
                      hintText: 'Contoh: TERIMA KASIH TELAH BELANJA DI KAMI',
                    ),
                    onChanged: (v) {
                      notifier.setCustomFooter(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tampilkan Bagian Nota',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Slogan / Tagline Header'),
                  subtitle: const Text('Tampilkan subtitle di bawah nama toko'),
                  value: config.showTagline,
                  onChanged: (v) {
                    notifier.toggleTagline(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Nama Kasir / Operator'),
                  subtitle: const Text('Tampilkan nama kasir yang melayani'),
                  value: config.showOperator,
                  onChanged: (v) {
                    notifier.toggleOperator(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Jumlah Total ITEM'),
                  subtitle: const Text('Tampilkan total kuantitas barang fisik'),
                  value: config.showItemCount,
                  onChanged: (v) {
                    notifier.toggleItemCount(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Kotak Tanda Tangan / Stempel'),
                  subtitle: const Text('Kolom tanda tangan toko pada struk'),
                  value: config.showSignature,
                  onChanged: (v) {
                    notifier.toggleSignature(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('QR Code Nota (Dynamic QR)'),
                  subtitle: const Text('Cetak QR Code nota verifikasi di akhir struk'),
                  value: config.showQr,
                  onChanged: (v) {
                    notifier.toggleQr(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Preview Nota Thermal',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('58mm')),
                  ButtonSegment(value: true, label: Text('80mm')),
                ],
                selected: {_is80mm},
                onSelectionChanged: (s) => setState(() => _is80mm = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  previewText,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
