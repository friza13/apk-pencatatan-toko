import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
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
                                  icon: Icons.payments_outlined,
                                  accentColor: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _kpi(
                                  context,
                                  'Laba hari ini',
                                  formatMinor(sum.profitMinor),
                                  icon: Icons.trending_up,
                                  accentColor: AppColors.accent600,
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
                                  icon: Icons.receipt_long_outlined,
                                  accentColor: Colors.blueGrey,
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
                                    icon: Icons.account_balance_wallet_outlined,
                                    accentColor: AppColors.warning600,
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
                  Text(
                    'Aksi Cepat',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                      ActionChip(
                        avatar: const Icon(Icons.account_balance_outlined, size: 18),
                        label: const Text('Kas & Bank'),
                        onPressed: () => context.push('/more/kas'),
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
                        color: AppColors.warning50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.warning500),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning700,
                          ),
                          title: const Text(
                            'Stok menipis',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning700,
                            ),
                          ),
                          subtitle: Text(
                            names.join(', '),
                            style: const TextStyle(color: AppColors.neutral700),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.warning700,
                          ),
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

    Widget _kpi(
      BuildContext context,
      String label,
      String value, {
      IconData? icon,
      Color? accentColor,
    }) =>
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: accentColor),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
