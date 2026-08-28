import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/error/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../controllers/sales_providers.dart';
import '../data/sales_service.dart';
import '../../products/data/product_repository.dart';

/// Buat Nota — the money screen (DESAIN §11-12). One tap adds a product.
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _search = TextEditingController();
  List<Product> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    final business = await ref.read(currentBusinessProvider.future);
    final repo = await ref.read(productRepositoryProvider.future);
    final items = await repo.search(
      businessId: business.id,
      query: q,
      filter: ProductFilter.active,
    );
    if (!mounted) return;
    setState(() {
      _results = items;
      _searching = false;
    });
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final accountId = await ref.read(defaultAccountIdProvider.future);
    final business = await ref.read(currentBusinessProvider.future);
    final db = await ref.read(appDatabaseProvider.future);
    final customers =
        await (db.select(db.customers)
                ..where((t) => t.businessId.equals(business.id))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get()
          ..removeWhere((customer) => !customer.isActive);
    int? selectedCustomerId;
    final service = await ref.read(salesServiceProvider.future);
    final checkoutLines = [
      for (final l in cart.lines)
        SaleLineInput(
          productId: l.productId,
          qtyMicro: l.qtyMicro,
          unitPriceMinor: l.unitPriceMinor,
        ),
    ];
    int? resolvedTotal = await service.previewTotal(lines: checkoutLines);

    // Simple payment sheet: full-cash MVP with optional paid-amount edit.
    final paidC = TextEditingController(text: '$resolvedTotal');
    if (!mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
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
                'Pembayaran',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                resolvedTotal == null
                    ? 'Total: menghitung...'
                    : 'Total: ${formatMinor(resolvedTotal!)}',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: paidC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dibayar sekarang',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kurang dari total akan dicatat sebagai piutang.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              if (customers.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Pelanggan (untuk piutang)',
                  ),
                  items: [
                    DropdownMenuItem<int?>(child: Text('Tanpa pelanggan')),
                    for (final customer in customers)
                      DropdownMenuItem<int?>(
                        value: customer.id,
                        child: Text(customer.name),
                      ),
                  ],
                  onChanged: (value) async {
                    selectedCustomerId = value;
                    setSheetState(() => resolvedTotal = null);
                    try {
                      final total = await service.previewTotal(
                        lines: checkoutLines,
                        customerId: value,
                      );
                      if (!sheetContext.mounted) return;
                      paidC.text = '$total';
                      setSheetState(() => resolvedTotal = total);
                    } on Failure catch (failure) {
                      if (!sheetContext.mounted) return;
                      setSheetState(() => resolvedTotal = cart.subtotalMinor);
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(failure.message)));
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: resolvedTotal == null
                    ? null
                    : () => Navigator.pop(sheetContext, true),
                child: const Text('Simpan Nota'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final paidNow =
        int.tryParse(paidC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    try {
      final service = await ref.read(salesServiceProvider.future);
      final out = await service.checkout(
        CheckoutInput(
          lines: checkoutLines,
          accountId: accountId,
          customerId: selectedCustomerId,
          paidNowMinor: paidNow,
        ),
      );
      ref
        ..read(cartProvider.notifier).clear()
        ..invalidate(productsControllerProvider)
        ..invalidate(salesListProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nota tersimpan'),
          content: Text(
            'Nomor: ${out.number}\nTotal: ${formatMinor(out.grandTotalMinor)}'
            '${out.dueTotalMinor > 0 ? '\nPiutang: ${formatMinor(out.dueTotalMinor)}' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/sales');
    } on Failure catch (f) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Nota')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari produk untuk ditambahkan...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _runSearch,
              onChanged: (v) {
                if (v.length >= 2) _runSearch(v);
              },
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_results.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: Text(formatMinor(p.salePriceMinor)),
                      trailing: Icon(
                        Icons.add_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () => ref.read(cartProvider.notifier).add(p),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cari produk di atas,\nlalu ketuk untuk menambah.',
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      for (final l in cart.lines)
                        ListTile(
                          title: Text(l.name),
                          subtitle: Text(
                            '${microToDecimalString(l.qtyMicro)} x '
                            '${formatMinor(l.unitPriceMinor)}'
                            '${l.tracked ? '' : ' (jasa)'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => ref
                                    .read(cartProvider.notifier)
                                    .decrement(l.productId),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(microToDecimalString(l.qtyMicro)),
                              IconButton(
                                onPressed: () => ref
                                    .read(cartProvider.notifier)
                                    .increment(l.productId),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: cart.isEmpty
                  ? Theme.of(context).disabledColor
                  : null,
            ),
            onPressed: cart.isEmpty ? null : _checkout,
            child: Text(
              cart.isEmpty
                  ? 'Keranjang kosong'
                  : 'Bayar - ${formatMinor(cart.subtotalMinor)}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
