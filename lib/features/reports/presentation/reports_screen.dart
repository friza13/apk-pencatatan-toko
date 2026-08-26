import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/csv/csv_builder.dart';
import '../../../core/domain/business_clock.dart';
import '../../../core/money/money.dart';
import '../../products/controllers/products_providers.dart';
import '../controllers/report_providers.dart';
import '../data/report_repository.dart';

/// Laporan (DESAIN §16): KPI periode, grafik bar 7 hari, produk terlaris,
/// export CSV 30 hari via share sheet.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(reportRepositoryProvider);
    final businessAsync = ref.watch(currentBusinessProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: repoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (repo) {
          final business = businessAsync.value;
          if (business == null) return const SizedBox.shrink();

          final offset =
              BusinessClock.offsetMinutesFor(business.timezone);
          final (s, e) = repo.rangeFor(_period, offset);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final p in ReportPeriod.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (p) {
                            ReportPeriod.today => 'Hari ini',
                            ReportPeriod.yesterday => 'Kemarin',
                            ReportPeriod.last7 => '7 hari',
                            ReportPeriod.last30 => '30 hari',
                            ReportPeriod.thisMonth => 'Bulan ini',
                          }),
                          selected: _period == p,
                          onSelected: (_) => setState(() => _period = p),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<SalesSummary>(
                future: repo.salesSummary(
                    businessId: business.id,
                    startUtcMillis: s,
                    endUtcMillis: e),
                builder: (context, snap) {
                  final sum = snap.data;
                  if (sum == null) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  return Column(children: [
                    _row(context, 'Omzet', formatMinor(sum.totalMinor)),
                    _row(context, 'Laba kotor', formatMinor(sum.profitMinor)),
                    _row(context, 'Transaksi', '${sum.transactionCount}'),
                    if (sum.dueMinor > 0)
                      _row(context, 'Piutang baru',
                          formatMinor(sum.dueMinor)),
                  ]);
                },
              ),
              const SizedBox(height: 20),
              Text('Penjualan 7 hari terakhir',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder(
                future: repo.dailyTotals(
                  businessId: business.id,
                  days: 7,
                  offsetMinutes: offset,
                ),
                builder: (context, AsyncSnapshot<List<DayTotal>> snap) {
                  final data = snap.data ?? const <DayTotal>[];
                  var maxVal = 1;
                  for (final d in data) {
                    if (d.totalMinor > maxVal) maxVal = d.totalMinor;
                  }
                  return SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in data)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 4 +
                                        100 * (d.totalMinor / maxVal),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .8),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('E', 'id_ID')
                                        .format(d.dayLocalStartUtc),
                                    style: theme.textTheme.labelSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Produk terlaris', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              FutureBuilder<List<TopProductRow>>(
                future: repo.topProducts(
                    businessId: business.id,
                    startUtcMillis: s,
                    endUtcMillis: e),
                builder: (context, snap) {
                  final top = snap.data ?? const <TopProductRow>[];
                  if (top.isEmpty) {
                    return Text('Belum ada data pada periode ini.',
                        style: theme.textTheme.bodySmall);
                  }
                  return Column(children: [
                    for (var i = 0; i < top.length; i++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child:
                              Text('${i + 1}', style: theme.textTheme.labelSmall),
                        ),
                        title: Text(top[i].name),
                        trailing: Text(formatMinor(top[i].totalMinor)),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 20),
              FutureBuilder<int>(
                future: repo.stockValuationMinor(business.id),
                builder: (context, snap) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: const Text('Nilai stok'),
                    subtitle: const Text('Stok saat ini x harga modal'),
                    trailing: Text(formatMinor(snap.data ?? 0),
                        style: theme.textTheme.titleMedium),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share),
                label:
                    const Text('Export CSV (omzet harian 30 hari)'),
                onPressed: () =>
                    _exportCsv(context, ref, repo, business.id, offset),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref,
      ReportRepository repo, int businessId, int offsetMinutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final rows = await repo.dailyTotals(
      businessId: businessId,
      days: 30,
      offsetMinutes: offsetMinutes,
    );

    final csv = CsvBuilder()..row(['Tanggal', 'Total Omzet']);
    for (final r in rows) {
      csv.row([
        DateFormat('yyyy-MM-dd').format(r.dayLocalStartUtc.toLocal()),
        r.totalMinor.toString(),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/laporan-penjualan-30hari.csv');
    await file.writeAsString(csv.build());

    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    messenger.showSnackBar(const SnackBar(content: Text('CSV dibuat.')));
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
      );
}
