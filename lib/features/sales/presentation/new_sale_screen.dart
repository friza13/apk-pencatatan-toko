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
import 'widgets/barcode_scanner_listener.dart';

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
  bool _isSheetOpen = false;

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

  Future<void> _handleBarcodeScanned(String barcode) async {
    _search.clear();
    setState(() {
      _results = [];
      _searching = false;
    });
    final business = await ref.read(currentBusinessProvider.future);
    final repo = await ref.read(productRepositoryProvider.future);
    final items = await repo.search(
      businessId: business.id,
      query: barcode,
      filter: ProductFilter.active,
    );
    if (!mounted) return;
    if (items.isNotEmpty) {
      final p = items.first;
      await _onSelectProduct(p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ditambahkan: ${p.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode "$barcode" tidak ditemukan.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _onSelectProduct(Product p) async {
    final repo = await ref.read(productRepositoryProvider.future);
    final detail = await repo.detail(p.id);
    if (!mounted) return;

    final variants = detail?.variants ?? [];
    final units = detail?.units ?? [];

    if (variants.isEmpty && units.isEmpty) {
      ref.read(cartProvider.notifier).add(p);
      return;
    }

    setState(() => _isSheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Varian / Satuan',
                      style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name,
                      style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(p.name),
                      subtitle: Text(
                        'Harga: ${formatMinor(p.salePriceMinor)}'
                        '${p.trackStock ? ' • Stok: ${microToDecimalString(p.stockQuantityMicro)}' : ''}',
                      ),
                      onTap: () {
                        ref.read(cartProvider.notifier).add(p);
                        Navigator.pop(sheetCtx);
                      },
                    ),
                    if (variants.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Varian',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      for (final v in variants)
                        ListTile(
                          leading: const Icon(Icons.style_outlined),
                          title: Text(v.name),
                          subtitle: Text(
                            'Harga: ${formatMinor(v.salePriceMinor ?? p.salePriceMinor)}'
                            '${p.trackStock ? ' • Stok: ${microToDecimalString(v.stockQuantityMicro)}' : ''}',
                          ),
                          onTap: () {
                            ref
                                .read(cartProvider.notifier)
                                .addVariantOrUnit(
                                  product: p,
                                  variantId: v.id,
                                  variantName: v.name,
                                  unitPriceMinor:
                                      v.salePriceMinor ?? p.salePriceMinor,
                                  currentStockMicro: v.stockQuantityMicro,
                                );
                            Navigator.pop(sheetCtx);
                          },
                        ),
                    ],
                    if (units.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Satuan Lain',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      for (final u in units)
                        ListTile(
                          leading: const Icon(Icons.straighten_outlined),
                          title: Text('Satuan: ${u.unitName}'),
                          subtitle: Text(
                            '1 ${u.unitName} = ${microToDecimalString(u.entry.conversionToBaseMicro)} base • '
                            'Harga: ${formatMinor(u.entry.salePriceOverrideMinor ?? ((p.salePriceMinor * u.entry.conversionToBaseMicro) ~/ quantityScale))}',
                          ),
                          onTap: () {
                            final price =
                                u.entry.salePriceOverrideMinor ??
                                ((p.salePriceMinor *
                                        u.entry.conversionToBaseMicro) ~/
                                    quantityScale);
                            ref
                                .read(cartProvider.notifier)
                                .addVariantOrUnit(
                                  product: p,
                                  unitId: u.entry.unitId,
                                  unitName: u.unitName,
                                  conversionFactorMicro:
                                      u.entry.conversionToBaseMicro,
                                  unitPriceMinor: price,
                                );
                            Navigator.pop(sheetCtx);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    } finally {
      if (mounted) setState(() => _isSheetOpen = false);
    }
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
          variantId: l.variantId,
          unitId: l.unitId,
          qtyMicro: l.qtyMicro,
          unitPriceMinor: l.unitPriceMinor,
        ),
    ];
    int? resolvedTotal = await service.previewTotal(lines: checkoutLines);

    // Simple payment sheet: full-cash MVP with optional paid-amount edit.
    final paidC = TextEditingController(text: '$resolvedTotal');
    if (!mounted) return;

    setState(() => _isSheetOpen = true);
    bool? confirmed;
    try {
      confirmed = await showModalBottomSheet<bool>(
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('Uang Pas'),
                    onPressed: () {
                      if (resolvedTotal != null) {
                        paidC.text = '$resolvedTotal';
                        setSheetState(() {});
                      }
                    },
                  ),
                  for (final amount in [10000, 20000, 50000, 100000])
                    if ((resolvedTotal ?? 0) <= amount)
                      ActionChip(
                        label: Text(formatMinor(amount)),
                        onPressed: () {
                          paidC.text = '$amount';
                          setSheetState(() {});
                        },
                      ),
                ],
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
    } finally {
      if (mounted) setState(() => _isSheetOpen = false);
    }
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
      setState(() => _isSheetOpen = true);
      try {
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Nota tersimpan'),
            content: Text(
              'Nomor: ${out.number}\nTotal: ${formatMinor(out.grandTotalMinor)}'
              '${out.dueTotalMinor > 0 ? '\nPiutang: ${formatMinor(out.dueTotalMinor)}' : ''}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _isSheetOpen = false);
      }
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
      body: BarcodeScannerListener(
        enabled: !_isSheetOpen,
        onBarcodeScanned: _handleBarcodeScanned,
        child: Column(
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
                        onTap: () => _onSelectProduct(p),
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
                            title: Text(l.displayName),
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
                                      .decrementByKey(l.cartKey),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(microToDecimalString(l.qtyMicro)),
                                IconButton(
                                  onPressed: () => ref
                                      .read(cartProvider.notifier)
                                      .incrementByKey(l.cartKey),
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
