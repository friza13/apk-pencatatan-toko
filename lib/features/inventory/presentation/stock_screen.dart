import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../controllers/inventory_providers.dart';

/// Stok screen (DESAIN §15): list produk + aksi Stok Awal / Penyesuaian /
/// Opname, dan kartu stok per produk.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

enum _StockAction { opening, adjustIn, adjustOut, opname }

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

  Future<void> _openActionSheet(Product p, _StockAction action) async {
    final hasMovements = await _hasAnyMovement(p.id);
    if (!mounted) return;
    if ((action == _StockAction.opening) && hasMovements) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stok awal sudah pernah diatur untuk produk ini.')));
      return;
    }

    final controller = TextEditingController();
    final label = switch (action) {
      _StockAction.opening => 'Stok awal (${p.type == 'goods' ? 'pcs dasar' : ''})',
      _StockAction.adjustIn => 'Tambah stok (+)',
      _StockAction.adjustOut => 'Kurangi stok (-)',
      _StockAction.opname => 'Hasil hitung fisik',
    };

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_actionName(action)} — ${p.name}',
              style: Theme.of(sheetContext).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Stok saat ini: ${microToDecimalString(p.stockQuantityMicro)}',
              style: Theme.of(sheetContext).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(sheetContext, true),
            child: const Text('Simpan'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    int qtyMicro;
    try {
      qtyMicro = toMicro(raw);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Angka tidak valid: $raw')));
      return;
    }

    final service = await ref.read(inventoryServiceProvider.future);
    final r = switch (action) {
      _StockAction.opening => await service.setOpeningBalance(p.id, qtyMicro),
      _StockAction.adjustIn => await service.adjustStock(p.id, qtyMicro.abs(), 'Penyesuaian tambah'),
      _StockAction.adjustOut => await service.adjustStock(p.id, -qtyMicro.abs(), 'Penyesuaian kurang'),
      _StockAction.opname => await service.stockOpname(p.id, qtyMicro, ''),
    };

    if (!mounted) return;
    if (!r.isSuccess) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.failure!.message)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Stok sekarang ${microToDecimalString(r.newStockMicro!)}')));
    await _reload(_search.text);
  }

  Future<bool> _hasAnyMovement(int productId) async {
    final db = await ref.read(appDatabaseProvider.future);
    final rows = await (db.select(db.stockMovements)
          ..where((t) => t.productId.equals(productId)))
        .get();
    return rows.isNotEmpty;
  }

  String _actionName(_StockAction a) => switch (a) {
        _StockAction.opening => 'Stok Awal',
        _StockAction.adjustIn => 'Penyesuaian Tambah',
        _StockAction.adjustOut => 'Penyesuaian Kurang',
        _StockAction.opname => 'Stock Opname',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: Column(children: [
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
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Theme.of(context).dividerColor),
                      itemBuilder: (context, i) {
                        final p = _items[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                              'Min: ${microToDecimalString(p.minStockMicro)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              microToDecimalString(p.stockQuantityMicro),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<_StockAction>(
                              onSelected: (a) => _openActionSheet(p, a),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: _StockAction.opening,
                                    child: Text('Stok awal')),
                                const PopupMenuItem(
                                    value: _StockAction.adjustIn,
                                    child: Text('Tambah (penyesuaian)')),
                                const PopupMenuItem(
                                    value: _StockAction.adjustOut,
                                    child: Text('Kurangi (penyesuaian)')),
                                const PopupMenuItem(
                                    value: _StockAction.opname,
                                    child: Text('Stock opname')),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long_outlined),
                              tooltip: 'Kartu stok',
                              onPressed: () =>
                                  context.push('/more/stock/${p.id}'),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
