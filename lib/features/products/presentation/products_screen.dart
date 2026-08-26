import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../database/app_database.dart';
import '../controllers/products_providers.dart';
import '../data/product_repository.dart';

/// Produk tab — list with search + filter chips (DESAIN §13).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-add-product',
        onPressed: () async {
          await context.push('/products/new');
          await ref.read(productsControllerProvider.notifier).refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari nama, SKU, atau barcode…',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (q) =>
                  ref.read(productsControllerProvider.notifier).setQuery(q),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in ProductFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(f)),
                      selected: state.value?.filter == f,
                      onSelected: (_) => ref
                          .read(productsControllerProvider.notifier)
                          .setFilter(f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat produk.\n$e',
                  textAlign: TextAlign.center)),
              data: (s) {
                if (s.items.isEmpty) {
                  return _EmptyProducts(hasQuery: s.query.isNotEmpty);
                }
                return RefreshIndicator(
                  onRefresh:
                      ref.read(productsControllerProvider.notifier).refresh,
                  child: ListView.separated(
                    itemCount: s.items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (context, i) {
                      final p = s.items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          child: Icon(Icons.inventory_2_outlined,
                              color: theme.colorScheme.primary, size: 20),
                        ),
                        title: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (p.sku != null && p.sku!.isNotEmpty) p.sku!,
                            formatMinor(p.salePriceMinor),
                          ].join(' • '),
                        ),
                        trailing: _StockChip(product: p),
                        onTap: () async {
                          await context.push('/products/${p.id}');
                          await ref
                              .read(productsControllerProvider.notifier)
                              .refresh();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(ProductFilter f) => switch (f) {
        ProductFilter.all => 'Semua',
        ProductFilter.active => 'Aktif',
        ProductFilter.inactive => 'Nonaktif',
        ProductFilter.lowStock => 'Stok rendah',
        ProductFilter.outOfStock => 'Habis',
      };
}

/// Stok status chip — never color-only (DESAIN §15/§29).
class _StockChip extends StatelessWidget {
  const _StockChip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!product.trackStock) {
      return Chip(
        label: const Text('Jasa'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    final int micro = product.stockQuantityMicro;
    final int minMicro = product.minStockMicro;

    String label;
    IconData icon;
    Color bg;
    Color fg;
    if (micro <= 0) {
      label = 'Habis';
      icon = Icons.block;
      bg = theme.colorScheme.errorContainer;
      fg = theme.colorScheme.onErrorContainer;
    } else if (minMicro > 0 && micro <= minMicro / 2) {
      label = 'Kritis';
      icon = Icons.priority_high;
      bg = theme.colorScheme.errorContainer;
      fg = theme.colorScheme.onErrorContainer;
    } else if (minMicro > 0 && micro <= minMicro) {
      label = 'Menipis';
      icon = Icons.warning_amber_outlined;
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    } else {
      label = 'Aman';
      icon = Icons.check_circle_outline;
      bg = theme.colorScheme.secondaryContainer;
      fg = theme.colorScheme.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    if (hasQuery) {
      return const Center(child: Text('Tidak ada produk yang cocok.'));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Belum ada produk'),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan produk pertama agar kamu bisa mulai membuat nota.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
