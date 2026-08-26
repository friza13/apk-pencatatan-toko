import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../database/app_database.dart';
import '../../finance/controllers/finance_providers.dart';
import '../../products/controllers/products_providers.dart';

import '../data/receivable_service.dart';

/// Piutang (DESAIN §19) — actionable list + Catat Pembayaran.
class ReceivablesScreen extends ConsumerStatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  ConsumerState<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

enum _Segment { all, open, overdue, paid }

class _ReceivablesScreenState extends ConsumerState<ReceivablesScreen> {
  _Segment _segment = _Segment.open;
  List<ReceivableWithCustomer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final business = await ref.read(currentBusinessProvider.future);
    final service = await ref.read(receivableServiceProvider.future);
    final items = await service.list(business.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  bool _isOverdue(Receivable r, DateTime nowUtc) =>
      r.remainingAmountMinor > 0 &&
      r.dueDate.isBefore(nowUtc);

  List<ReceivableWithCustomer> get _filtered {
    final now = DateTime.now().toUtc();
    switch (_segment) {
      case _Segment.all:
        return _items;
      case _Segment.open:
        return _items.where((i) => i.receivable.remainingAmountMinor > 0).toList();
      case _Segment.overdue:
        return _items
            .where((i) => _isOverdue(i.receivable, now))
            .toList();
      case _Segment.paid:
        return _items
            .where((i) => i.receivable.remainingAmountMinor <= 0)
            .toList();
    }
  }

  Future<void> _pay(ReceivableWithCustomer item) async {
    final r = item.receivable;
    final amountC = TextEditingController(text: '${r.remainingAmountMinor}');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Catat Pembayaran',
              style: Theme.of(sheetContext).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${item.customerName} — sisa ${formatMinor(r.remainingAmountMinor)}'),
          const SizedBox(height: 12),
          TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nominal bayar'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: const Text('Simpan Pembayaran'),
          ),
        ]),
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount =
        int.tryParse(amountC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final business = await ref.read(currentBusinessProvider.future);
    final service = await ref.read(receivableServiceProvider.future);
    if (!mounted) return;
    // MVP: pembayaran piutang selalu ke akun kas pertama.
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Belum ada akun kas. Buka Kas & Bank dulu.')));
      return;
    }
    final accountId = accounts.first.id;
    final result = await service.recordPayment(
      receivableId: r.id,
      accountId: accountId,
      amountMinor: amount,
      note: 'Piutang ${item.customerName}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isSuccess
            ? 'Pembayaran dicatat.'
            : result.failure!.message)));
    await _reload();
    // keep business var used
    // ignore: unnecessary_statements
    business.id;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Piutang')),
      body: Column(children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final s in _Segment.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(switch (s) {
                      _Segment.all => 'Semua',
                      _Segment.open => 'Belum lunas',
                      _Segment.overdue => 'Jatuh tempo',
                      _Segment.paid => 'Lunas',
                    }),
                    selected: _segment == s,
                    onSelected: (_) => setState(() => _segment = s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(child: Text('Tidak ada piutang di segmen ini.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1, color: Theme.of(context).dividerColor),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final r = item.receivable;
                        final overdue = _isOverdue(r, now);
                        final paid = r.remainingAmountMinor <= 0;
                        return ListTile(
                          leading: Icon(
                            paid
                                ? Icons.check_circle_outline
                                : overdue
                                    ? Icons.notification_important_outlined
                                    : Icons.schedule_outlined,
                            color: paid
                                ? Theme.of(context).colorScheme.secondary
                                : overdue
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                          ),
                          title: Text(item.customerName),
                          subtitle: Text(
                              'Jatuh tempo ${r.dueDate.toLocal().toString().split(' ').first}'),
                          trailing: Text(
                            formatMinor(r.remainingAmountMinor),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          onTap: paid ? null : () => _pay(item),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
