import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';
import '../data/esc_pos_builder.dart';
import '../data/printer_adapter.dart';
import '../data/receipt_pdf.dart';
import '../data/receipt_text_renderer.dart';

/// Bottom sheet pilih lebar struk, preview teks, bagikan PDF / cetak.
class PrintSheet extends ConsumerStatefulWidget {
  const PrintSheet({
    super.key,
    required this.storeName,
    required this.sale,
    required this.lines,
    required this.customerName,
    required this.paymentLabel,
    required this.footerNote,
  });

  final String storeName;
  final Sale sale;
  final List<SaleLine> lines;
  final String? customerName;
  final String paymentLabel;
  final String? footerNote;

  @override
  ConsumerState<PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends ConsumerState<PrintSheet> {
  bool _is80 = false;

  ReceiptDocument get _document {
    return ReceiptDocument(
      storeName: widget.storeName,
      invoiceNumber: widget.sale.number ?? '-',
      dateTimeLocal: _fmt(widget.sale.createdAt.toLocal()),
      customerName: widget.customerName,
      lines: [
        for (final l in widget.lines)
          ReceiptItem(
            name: l.productNameSnapshot,
            qty: microToDecimalString(l.qtyBaseMicro),
            unitPriceMinor: l.unitPriceMinor,
            lineTotalMinor: l.lineTotalMinor,
          ),
      ],
      subtotalMinor: widget.sale.subtotalMinor,
      discountMinor: widget.sale.discountTotalMinor,
      taxMinor: widget.sale.taxTotalMinor,
      shippingMinor: widget.sale.shippingFeeMinor,
      roundingMinor: widget.sale.roundingMinor,
      grandTotalMinor: widget.sale.grandTotalMinor,
      paidMinor: widget.sale.paidTotalMinor,
      dueMinor: widget.sale.dueTotalMinor,
      paymentLabel: widget.paymentLabel,
      footerNote: widget.footerNote,
      config: ref.read(receiptConfigProvider),
    );
  }

  String get _text {
    final r = ReceiptTextRenderer(widthChars: _is80 ? 48 : 32);
    return r.renderDocument(_document);
  }

  String _fmt(DateTime local) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<Uint8List> _buildPdfBytes() async {
    final bytes = await ReceiptPdf.build(document: _document, is80mm: _is80);
    return Uint8List.fromList(bytes);
  }

  Future<void> _sharePdf() async {
    final bytes = await _buildPdfBytes();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'nota-${widget.sale.number ?? widget.sale.id}.pdf',
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _print() async {
    final messenger = ScaffoldMessenger.of(context);
    final adapter = ref.read(printerAdapterProvider);

    if (adapter.isConnected) {
      try {
        final builder = EscPosBuilder(is80mm: _is80);
        final bytes = builder.build(_document);
        await adapter.printReceipt(bytes);
        messenger.showSnackBar(
          const SnackBar(content: Text('Nota berhasil dikirim ke printer!')),
        );
        if (mounted) Navigator.pop(context);
        return;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal mencetak ke printer thermal: $e')),
        );
      }
    }

    try {
      // Membuka dialog cetak sistem (pilih printer terpasang).
      await Printing.layoutPdf(onLayout: (_) => _buildPdfBytes());
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada printer. Gunakan Bagikan PDF untuk membagikan nota.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final adapter = ref.watch(printerAdapterProvider);
    final connected = adapter.currentConnectedDevice;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cetak Nota', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('58 mm')),
                  ButtonSegment(value: true, label: Text('80 mm')),
                ],
                selected: {_is80},
                onSelectionChanged: (s) => setState(() => _is80 = s.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: connected != null
                  ? AppColors.accent50
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: connected != null
                    ? AppColors.accent500
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  connected != null ? Icons.bluetooth_connected : Icons.print_outlined,
                  size: 18,
                  color: connected != null
                      ? AppColors.accent700
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected != null
                        ? 'Thermal: ${connected.name}'
                        : 'Belum terhubung printer thermal (Cetak sistem aktif)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: connected != null
                          ? AppColors.accent700
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Bagikan PDF'),
                  onPressed: _sharePdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Cetak'),
                  onPressed: _print,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
