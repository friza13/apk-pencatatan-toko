import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/business_clock.dart';
import '../../../core/money/money.dart';
import '../products/controllers/products_providers.dart';
import '../reports/controllers/report_providers.dart';
import '../reports/data/report_repository.dart' show ReportPeriod;

/// Beranda (DESAIN §9): menjawab 4 pertanyaan owner via KPI + insight.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(currentBusinessProvider);
    final repoAsync = ref.watch(reportRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(businessAsync.value?.name ?? 'Beranda')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-dash-nota',
        onPressed: () => context.push('/sales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Buat Nota'),
      ),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (repository) {
          final business = businessAsync.value;
          if (business == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final offset = BusinessClock.offsetMinutesFor(business.timezone);
          final (s, e) = repository.rangeFor(ReportPeriod.today, offset);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reportRepositoryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_greeting(), style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                FutureBuilder(
                  key: ValueKey('kpi-$s-$e'),
                  future: repository.salesSummary(
                    businessId: business.id,
                    startUtcMillis: s,
                    endUtcMillis: e,
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final sum = snap.data!;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _kpi(
                                context,
                                'Omzet hari ini',
                                formatMinor(sum.totalMinor),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _kpi(
                                context,
                                'Laba hari ini',
                                formatMinor(sum.profitMinor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _kpi(
                                context,
                                'Transaksi',
                                sum.transactionCount.toString(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FutureBuilder<int>(
                                future: repository.receivablesOutstanding(
                                  business.id,
                                ),
                                builder: (_, rs) => _kpi(
                                  context,
                                  'Piutang',
                                  formatMinor(rs.data ?? 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Aksi cepat', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Buat Nota'),
                      onPressed: () => context.push('/sales/new'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('Produk'),
                      onPressed: () => context.go('/products'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.request_quote_outlined,
                        size: 18,
                      ),
                      label: const Text('Piutang'),
                      onPressed: () => context.push('/more/piutang'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FutureBuilder<List<String>>(
                  future: repository.lowStockNames(business.id),
                  builder: (context, snap) {
                    final names = snap.data ?? const [];
                    if (names.isEmpty) return const SizedBox.shrink();
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                        ),
                        title: const Text('Stok menipis'),
                        subtitle: Text(names.join(', ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/more/stock'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi!';
    if (hour < 15) return 'Selamat siang!';
    return 'Selamat sore!';
  }

  Widget _kpi(BuildContext context, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}
