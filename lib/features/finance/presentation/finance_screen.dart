import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../products/controllers/products_providers.dart';
import '../controllers/finance_providers.dart';

/// Kas & Bank (DESAIN §18): account cards + quick actions + cash timeline.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final flow = ref.watch(cashFlowStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Kas & Bank')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-finance-actions',
        onPressed: () => _actionSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 120,
            child: accounts.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada akun.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final a = accounts[i];
                      return Container(
                        width: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: i == 0
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              formatMinor(a.currentBalanceMinor),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: i == 0
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.south_west),
                  label: const Text('Pemasukan'),
                  onPressed: () => _manualSheet(context, ref, isIncome: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.north_east),
                  label: const Text('Pengeluaran'),
                  onPressed: () => _manualSheet(context, ref, isIncome: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer Antar Akun'),
            onPressed: () => _transferSheet(context, ref),
          ),
          const SizedBox(height: 20),
          Text('Arus Kas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (flow.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada transaksi kas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...flow.map((e) {
              final positive = e.entryType == 'debit';
              final df = DateFormat('dd MMM HH:mm', 'id_ID');
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  positive ? Icons.arrow_downward : Icons.arrow_upward,
                  color: positive
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(e.note ?? e.sourceType),
                subtitle: Text(df.format(e.occurredAt.toLocal())),
                trailing: Text(
                  '${positive ? '+' : '-'}${formatMinor(e.amountMinor)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: positive
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _actionSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.south_west),
              title: const Text('Catat Pemasukan'),
              onTap: () {
                Navigator.pop(sheetContext);
                _manualSheet(context, ref, isIncome: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.north_east),
              title: const Text('Catat Pengeluaran'),
              onTap: () {
                Navigator.pop(sheetContext);
                _manualSheet(context, ref, isIncome: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Transfer Antar Akun'),
              onTap: () {
                Navigator.pop(sheetContext);
                _transferSheet(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manualSheet(
    BuildContext context,
    WidgetRef ref, {
    required bool isIncome,
  }) async {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Buat akun terlebih dahulu (otomatis ada saat onboarding).',
          ),
        ),
      );
      return;
    }
    int selected = accounts.first.id;
    final amountC = TextEditingController();
    final categoryC = TextEditingController();
    final noteC = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isIncome ? 'Pemasukan' : 'Pengeluaran',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selected,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => selected = v!),
                decoration: const InputDecoration(labelText: 'Akun'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nominal *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryC,
                decoration: InputDecoration(
                  labelText: isIncome
                      ? 'Sumber (mis. Bunga)'
                      : 'Kategori (mis. Listrik)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final amount =
        int.tryParse(amountC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;

    final business = await ref.read(currentBusinessProvider.future);
    final service = await ref.read(financeServiceProvider.future);
    final r = await service.recordManual(
      businessId: business.id,
      accountId: selected,
      isIncome: isIncome,
      amountMinor: amount,
      category: categoryC.text.trim().isEmpty ? null : categoryC.text.trim(),
      note: noteC.text.trim().isEmpty ? null : noteC.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.isSuccess ? 'Tersimpan.' : r.failure!.message)),
    );
  }

  Future<void> _transferSheet(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    if (accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer butuh minimal dua akun.')),
      );
      return;
    }
    int from = accounts.first.id;
    int to = accounts.last.id;
    final amountC = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Transfer Antar Akun',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: from,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => from = v!),
                decoration: const InputDecoration(labelText: 'Dari'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: to,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => to = v!),
                decoration: const InputDecoration(labelText: 'Ke'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nominal *'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final amount =
        int.tryParse(amountC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;

    final service = await ref.read(financeServiceProvider.future);
    final r = await service.transfer(
      fromAccountId: from,
      toAccountId: to,
      amountMinor: amount,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.isSuccess ? 'Transfer tersimpan.' : r.failure!.message),
      ),
    );
  }
}
