import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
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
        builder: (sheetContext, setSheetState) {
          final int enteredPaid =
              int.tryParse(paidC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final int targetTotal = resolvedTotal ?? 0;
          final int change = enteredPaid - targetTotal;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Pembayaran',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  resolvedTotal == null
                      ? 'Total: menghitung...'
                      : 'Total Tagihan: ${formatMinor(resolvedTotal!)}',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                if (resolvedTotal != null && enteredPaid > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: change >= 0
                          ? AppColors.accent50
                          : AppColors.danger50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: change >= 0
                            ? AppColors.accent500
                            : AppColors.danger500,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          change >= 0 ? 'Kembalian:' : 'Sisa (Piutang):',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: change >= 0
                                ? AppColors.accent700
                                : AppColors.danger700,
                          ),
                        ),
                        Text(
                          formatMinor(change.abs()),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: change >= 0
                                ? AppColors.accent700
                                : AppColors.danger700,
                            fontFeatures: AppTypography.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: paidC,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nominal Bayar (Rp)',
                    suffixIcon: paidC.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              paidC.clear();
                              setSheetState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Uang Pas'),
                      onPressed: () {
                        if (resolvedTotal != null) {
                          paidC.text = '$resolvedTotal';
                          setSheetState(() {});
                        }
                      },
                    ),
                    ActionChip(
                      label: const Text('+Rp10.000'),
                      onPressed: () {
                        final cur = int.tryParse(
                                paidC.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                            0;
                        paidC.text = '${cur + 10000}';
                        setSheetState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('+Rp20.000'),
                      onPressed: () {
                        final cur = int.tryParse(
                                paidC.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                            0;
                        paidC.text = '${cur + 20000}';
                        setSheetState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('Rp50.000'),
                      onPressed: () {
                        paidC.text = '50000';
                        setSheetState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('Rp100.000'),
                      onPressed: () {
                        paidC.text = '100000';
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
        );
      },
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
                decoration: InputDecoration(
                  hintText: 'Cari produk untuk ditambahkan...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _search.clear();
                            setState(() {
                              _results = [];
                              _searching = false;
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: _runSearch,
                onChanged: (v) {
                  setState(() {});
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
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          formatMinor(p.salePriceMinor),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final l in cart.lines)
                          ListTile(
                            title: Text(
                              l.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${microToDecimalString(l.qtyMicro)} x '
                              '${formatMinor(l.unitPriceMinor)}'
                              '${l.tracked ? '' : ' (jasa)'}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .decrementByKey(l.cartKey),
                                    icon: Icon(
                                      l.qtyMicro <= quantityScale
                                          ? Icons.delete_outline
                                          : Icons.remove,
                                      size: 18,
                                      color: l.qtyMicro <= quantityScale
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Text(
                                      microToDecimalString(l.qtyMicro),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .incrementByKey(l.cartKey),
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: cart.isEmpty
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
              ),
              onPressed: cart.isEmpty ? null : _checkout,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                cart.isEmpty
                    ? 'Keranjang kosong'
                    : 'Bayar - ${formatMinor(cart.subtotalMinor)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
