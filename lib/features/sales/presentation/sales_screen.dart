import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../controllers/sales_providers.dart';

/// Daftar nota (DESAIN §8 Penjualan).
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesList = ref.watch(salesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-new-sale',
        onPressed: () => context.push('/sales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Buat Nota'),
      ),
      body: salesList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada nota'),
                  const SizedBox(height: 8),
                  const Text('Buat nota pertama lewat tombol Buat Nota.'),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                leading: _statusChip(context, s.status),
                title: Text(s.number ?? '(tanpa nomor)'),
                subtitle: Text(_fmtDate(s.createdAt)),
                trailing: Text(
                  formatMinor(s.grandTotalMinor),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => context.push('/sales/${s.id}'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final Map<String, (Color, String)> map = {
      'paid': (Theme.of(context).colorScheme.secondaryContainer, 'Lunas'),
      'partially_paid': (const Color(0xFFFFFBEB), 'Sebagian'),
      'credit': (const Color(0xFFEFF6FF), 'Kredit'),
      'voided': (Theme.of(context).colorScheme.errorContainer, 'Void'),
      'confirmed': (
        Theme.of(context).colorScheme.primaryContainer,
        'Terkonfirmasi',
      ),
      'draft': (Theme.of(context).colorScheme.surfaceContainerHighest, 'Draft'),
    };
    final entry =
        map[status] ??
        (Theme.of(context).colorScheme.surfaceContainerHighest, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entry.$1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(entry.$2, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String _fmtDate(DateTime utc) {
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
