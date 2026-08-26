import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../../products/controllers/products_providers.dart';
import '../../printing/presentation/print_sheet.dart';
import '../controllers/sales_providers.dart';

/// Detail nota + void action.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(saleDetailProvider(saleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Nota')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Nota tidak ditemukan.'));
          }
          final s = data.sale;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(s.number ?? '-', style: Theme.of(context).textTheme.headlineSmall),
                _StatusChip(status: s.status),
              ]),
              const SizedBox(height: 8),
              Text('Total: ${formatMinor(s.grandTotalMinor)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (s.dueTotalMinor > 0)
                Text('Piutang: ${formatMinor(s.dueTotalMinor)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              const Divider(),
              for (final l in data.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.productNameSnapshot),
                  subtitle: Text(
                      '${microToDecimalString(l.qtyMicro)} x '
                      '${formatMinor(l.unitPriceMinor)}'),
                  trailing:
                      Text(formatMinor(l.lineTotalMinor)),
                ),
              const Divider(),
              _kv(context, 'Subtotal', formatMinor(s.subtotalMinor)),
              if (s.discountTotalMinor > 0)
                _kv(context, 'Diskon', '-${formatMinor(s.discountTotalMinor)}'),
              if (s.taxTotalMinor > 0)
                _kv(context, 'Pajak', formatMinor(s.taxTotalMinor)),
              if (s.shippingFeeMinor > 0)
                _kv(context, 'Ongkir', formatMinor(s.shippingFeeMinor)),
              _kv(context, 'Dibayar', formatMinor(s.paidTotalMinor)),
              if (s.note != null && s.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(s.note!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_outlined),
                  label: const Text('Cetak / PDF'),
                  onPressed: () {
                    final business =
                        ref.read(currentBusinessProvider).value;
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => PrintSheet(
                        storeName: business?.name ?? 'NotaKit',
                        sale: s,
                        lines: data.lines,
                        customerName: null,
                        paymentLabel:
                            s.paidTotalMinor > 0 ? 'TUNAI/KREDIT' : '-',
                        footerNote: business?.footerNote,
                      ),
                    );
                  },
                ),
              if (s.status != 'voided')
                OutlinedButton.icon(
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Void Nota'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _voidDialog(context, ref),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _voidDialog(BuildContext context, WidgetRef ref) async {
    final reasonC = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Nota?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Stok akan dikembalikan. Tindakan ini tercatat di audit.'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonC,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Alasan *'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Void')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final reason = reasonC.text.trim();
    if (reason.isEmpty) return;

    await ref.read(salesServiceProvider.future);
    // Service instance via provider future then call voidSale through it:
    final service = await ref.read(salesServiceProvider.future);
    await service.voidSale(saleId, reason);
    ref
      ..invalidate(saleDetailProvider(saleId))
      ..invalidate(salesListProvider)
      ..invalidate(productsControllerProvider);
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(k), Text(v)],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final map = {
      'paid': ('Lunas', Theme.of(context).colorScheme.secondaryContainer),
      'partially_paid':
          ('Sebagian', const Color(0xFFFFFBEB)),
      'credit': ('Kredit', const Color(0xFFEFF6FF)),
      'voided': ('VOID', Theme.of(context).colorScheme.errorContainer),
      'confirmed': ('Terkonfirmasi',
          Theme.of(context).colorScheme.primaryContainer),
    };
    final entry = map[status] ?? (status, Theme.of(context).colorScheme.surfaceContainerHighest);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: entry.$2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(entry.$1, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
