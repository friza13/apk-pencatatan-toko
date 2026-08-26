import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../core/units/quantity.dart';
import '../controllers/products_providers.dart';

/// Product detail with accordion sections (DESAIN §13).
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk'), actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
          onPressed: () async {
            await context.push('/products/$productId/edit');
            // refresh after edit
            // ignore: unawaited_futures
            ref.invalidate(productsControllerProvider);
          },
        ),
      ]),
      body: repo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (repository) => FutureBuilder(
          future: repository.detail(productId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final detail = snap.data;
            if (detail == null) {
              return const Center(child: Text('Produk tidak ditemukan.'));
            }
            final p = detail.product;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  [
                    if (p.sku != null && p.sku!.isNotEmpty) 'SKU ${p.sku}',
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      p.barcode!,
                    switch (p.type) {
                      'goods' => 'Barang',
                      'service' => 'Jasa',
                      _ => 'Non-stok',
                    },
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (!p.isActive)
                  Chip(
                    label: const Text('Nonaktif'),
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                const SizedBox(height: 8),
                _Accordion(
                  title: 'Harga',
                  initiallyExpanded: true,
                  children: [
                    _kv('Harga jual', formatMinor(p.salePriceMinor)),
                    _kv('Harga grosir', p.wholesalePriceMinor == null
                        ? '-'
                        : formatMinor(p.wholesalePriceMinor!)),
                    _kv('Harga beli/modal', formatMinor(p.costPriceMinor)),
                  ],
                ),
                _Accordion(
                  title: 'Stok',
                  children: [
                    _kv(
                      'Stok saat ini',
                      p.trackStock
                          ? microToDecimalString(p.stockQuantityMicro)
                          : 'Tidak dilacak',
                    ),
                    if (p.trackStock)
                      _kv('Batas minimum',
                          microToDecimalString(p.minStockMicro)),
                  ],
                ),
                if (detail.variants.isNotEmpty)
                  _Accordion(
                    title: 'Varian',
                    children: [
                      for (final v in detail.variants)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(v.name),
                          trailing: Text(formatMinor(v.salePriceMinor ?? 0)),
                        ),
                    ],
                  ),
                if (detail.units.isNotEmpty)
                  _Accordion(
                    title: 'Satuan konversi',
                    children: [
                      for (final u in detail.units)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(u.unitName),
                          trailing: Text(
                              '1 ${u.unitCode} = '
                              '${microToDecimalString(u.entry.conversionToBaseMicro)}'),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: Icon(p.isActive ? Icons.archive_outlined : Icons.unarchive_outlined),
                  label: Text(p.isActive ? 'Arsipkan produk' : 'Aktifkan kembali'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final notifier =
                        ref.read(productsControllerProvider.notifier);
                    await notifier.toggleActive(p);
                    ref.invalidate(productsControllerProvider);
                    navigator.pop();
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Status produk diperbarui.')));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _Accordion extends StatelessWidget {
  const _Accordion({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const Border(),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        children: children,
      ),
    );
  }
}
