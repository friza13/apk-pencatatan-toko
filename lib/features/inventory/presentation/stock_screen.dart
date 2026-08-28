import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import 'widgets/stock_action_sheet.dart';

/// Stok screen (DESAIN §15): list produk + aksi Stok Awal / Penyesuaian /
/// Opname, dan kartu stok per produk.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _search = TextEditingController();
  List<Product> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
    // Ensure defaults seeded before first use.
    // ignore: unawaited_futures
    ref.read(masterDataSeedProvider.future);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload([String q = '']) async {
    setState(() => _loading = true);
    final business = await ref.read(currentBusinessProvider.future);
    final repo = await ref.read(productRepositoryProvider.future);
    final items = await repo.search(businessId: business.id, query: q);
    if (!mounted) return;
    setState(() {
      _items = items.where((p) => p.trackStock).toList();
      _loading = false;
    });
  }

  Future<void> _openSheet(
    Product p, [
    StockAction action = StockAction.adjustIn,
  ]) async {
    final repo = await ref.read(productRepositoryProvider.future);
    final detail = await repo.detail(p.id);
    if (!mounted) return;
    await showStockActionSheet(
      context: context,
      ref: ref,
      product: p,
      variants: detail?.variants ?? const [],
      initialAction: action,
      onUpdated: () => _reload(_search.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _reload,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('Belum ada produk berstok.'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    itemBuilder: (context, i) {
                      final p = _items[i];
                      return ListTile(
                        onTap: () => _openSheet(p),
                        title: Text(p.name),
                        subtitle: Text(
                          'Min: ${microToDecimalString(p.minStockMicro)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              microToDecimalString(p.stockQuantityMicro),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<StockAction>(
                              onSelected: (a) => _openSheet(p, a),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: StockAction.opening,
                                  child: Text('Stok awal'),
                                ),
                                const PopupMenuItem(
                                  value: StockAction.adjustIn,
                                  child: Text('Tambah (penyesuaian)'),
                                ),
                                const PopupMenuItem(
                                  value: StockAction.adjustOut,
                                  child: Text('Kurangi (penyesuaian)'),
                                ),
                                const PopupMenuItem(
                                  value: StockAction.opname,
                                  child: Text('Stock opname'),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long_outlined),
                              tooltip: 'Kartu stok',
                              onPressed: () =>
                                  context.push('/more/stock/${p.id}'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
