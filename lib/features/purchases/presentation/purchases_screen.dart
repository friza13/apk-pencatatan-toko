import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../controllers/purchases_providers.dart';

/// Screen listing purchase orders and purchase invoices.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembelian & Kulakan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(purchasesListProvider),
          ),
        ],
      ),
      body: purchasesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat: $err')),
        data: (purchases) {
          if (purchases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('Belum ada data pembelian.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/purchases/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat Pembelian Baru'),
                  ),
                ],
              ),
            );
          }

          int totalPurchasesMinor = 0;
          int totalDueMinor = 0;
          for (final p in purchases) {
            totalPurchasesMinor += p.grandTotalMinor;
            totalDueMinor += p.dueTotalMinor;
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(purchasesListProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Pembelian'),
                              const SizedBox(height: 4),
                              Text(
                                formatMinor(totalPurchasesMinor),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: totalDueMinor > 0
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hutang Usaha'),
                              const SizedBox(height: 4),
                              Text(
                                formatMinor(totalDueMinor),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: totalDueMinor > 0
                                      ? Theme.of(context).colorScheme.onErrorContainer
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final p in purchases)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_outlined),
                      title: Text(p.number ?? 'Nota #${p.id}'),
                      subtitle: Text(
                        'Total: ${formatMinor(p.grandTotalMinor)}'
                        '${p.dueTotalMinor > 0 ? ' • Sisa Hutang: ${formatMinor(p.dueTotalMinor)}' : ' • Lunas'}',
                      ),
                      trailing: Chip(
                        label: Text(p.status.toUpperCase()),
                        backgroundColor: p.status == 'finalized'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/purchases/new'),
        icon: const Icon(Icons.add),
        label: const Text('Beli / Kulakan'),
      ),
    );
  }
}
