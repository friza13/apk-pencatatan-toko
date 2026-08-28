import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/quantity.dart';
import '../controllers/products_providers.dart';
import '../data/product_repository.dart';

/// Create/edit product. Layout follows DESAIN section 41: simple fields first,
/// advanced sections collapsed. Stock quantity is NOT editable here (D-014).
/// it changes only through inventory movements (P5).
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _costPrice = TextEditingController();
  final _salePrice = TextEditingController();
  final _wholesalePrice = TextEditingController();
  final _minStock = TextEditingController();

  int? _categoryId;
  String _type = 'goods';
  bool _trackStock = true;

  /// Conversion rows for non-base units: unitId -> factor text.
  final Map<int, TextEditingController> _unitFactors = {};

  /// Variant rows: (name, price) controllers.
  final List<(TextEditingController, TextEditingController)> _variants = [];

  bool _loadingExisting = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    await ref.read(unitsStreamProvider.future);
    if (widget.productId != null) {
      final detail = await (await ref.read(
        productRepositoryProvider.future,
      )).detail(widget.productId!);
      if (detail != null && mounted) {
        final p = detail.product;
        _name.text = p.name;
        _sku.text = p.sku ?? '';
        _barcode.text = p.barcode ?? '';
        if (p.costPriceMinor > 0) _costPrice.text = '${p.costPriceMinor}';
        if (p.salePriceMinor > 0) _salePrice.text = '${p.salePriceMinor}';
        if (p.wholesalePriceMinor != null) {
          _wholesalePrice.text = '${p.wholesalePriceMinor}';
        }
        _minStock.text = microToDecimalString(p.minStockMicro);
        _categoryId = p.categoryId;
        _type = p.type;
        _trackStock = p.trackStock;
        for (final u in detail.units) {
          _unitFactors[u.entry.unitId] = TextEditingController(
            text: microToDecimalString(u.entry.conversionToBaseMicro),
          );
        }
        for (final v in detail.variants) {
          _variants.add((
            TextEditingController(text: v.name),
            TextEditingController(
              text: v.salePriceMinor == 0 ? '' : '${v.salePriceMinor}',
            ),
          ));
        }
      }
    }
    if (mounted) {
      setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _barcode,
      _costPrice,
      _salePrice,
      _wholesalePrice,
      _minStock,
    ]) {
      c.dispose();
    }
    for (final c in _unitFactors.values) {
      c.dispose();
    }
    for (final (n, p) in _variants) {
      n.dispose();
      p.dispose();
    }
    super.dispose();
  }

  int? _parseMoney(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.isEmpty ? null : int.tryParse(cleaned);
  }

  bool get _canSave =>
      !_saving &&
      _name.text.trim().isNotEmpty &&
      (_parseMoney(_salePrice.text) ?? 0) > 0;

  Future<void> _save() async {
    final unitsList = ref.read(unitsStreamProvider).value ?? const [];
    if (unitsList.isEmpty) {
      setState(() => _error = 'Satuan dasar belum tersedia.');
      return;
    }
    if (!_canSave) {
      setState(() => _error = 'Lengkapi nama dan harga jual.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final business = await ref.read(currentBusinessProvider.future);
      final draft = ProductDraft(
        businessId: business.id,
        name: _name.text.trim(),
        categoryId: _categoryId,
        type: _type,
        sku: _textOrNull(_sku),
        barcode: _textOrNull(_barcode),
        baseUnitId: unitsList.first.id,
        costPriceMinor: _parseMoney(_costPrice.text) ?? 0,
        salePriceMinor: _parseMoney(_salePrice.text)!,
        wholesalePriceMinor: _parseMoney(_wholesalePrice.text),
        minStockMicro: toMicro(
          _minStock.text.trim().isEmpty ? '0' : _minStock.text.trim(),
        ),
        trackStock: _trackStock && _type == 'goods',
      );

      // Non-base unit conversions (skip empty factors).
      for (final entry in _unitFactors.entries) {
        final factorText = entry.value.text.trim();
        if (factorText.isEmpty) continue;
        if (toMicro(factorText) <= quantityScale) continue; // must be > 1 base
        draft.units.add(
          ProductUnitInput(unitId: entry.key, conversionToBase: factorText),
        );
      }

      // Variants (skip empty names).
      for (final (n, p) in _variants) {
        final name = n.text.trim();
        if (name.isEmpty) continue;
        draft.variants.add(
          VariantInput(name: name, salePriceMinor: _parseMoney(p.text)),
        );
      }

      await ref
          .read(productsControllerProvider.notifier)
          .saveProduct(widget.productId, draft);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  String? _textOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? [];
    final units = ref.watch(unitsStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Tambah Produk' : 'Edit Produk'),
      ),
      body: _loadingExisting || units.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama produk *'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'goods', label: Text('Barang')),
                    ButtonSegment(value: 'service', label: Text('Jasa')),
                    ButtonSegment(value: 'non_stock', label: Text('Non-stok')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    DropdownMenuItem<int?>(child: Text('- Tanpa kategori -')),
                    ...categories.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sku,
                        decoration: const InputDecoration(labelText: 'SKU'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _barcode,
                        decoration: const InputDecoration(labelText: 'Barcode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Harga', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _costPrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga beli/modal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _salePrice,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga jual *',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wholesalePrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga grosir (opsional)',
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lacak stok'),
                  subtitle: Text(
                    _type == 'goods'
                        ? 'Stok berkurang saat penjualan.'
                        : 'Hanya barang yang dilacak stoknya.',
                  ),
                  value: _trackStock && _type == 'goods',
                  onChanged: _type != 'goods'
                      ? null
                      : (v) => setState(() => _trackStock = v),
                ),
                if (_trackStock && _type == 'goods') ...[
                  TextField(
                    controller: _minStock,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Batas stok minimum',
                      helperText: 'Contoh: 5 (pcs). Untuk notifikasi menipis.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jumlah stok diisi lewat menu Stok (stok awal / penyesuaian).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Satuan konversi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Satuan dasar: ${units.first.code}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ...units.skip(1).map((u) {
                  _unitFactors.putIfAbsent(u.id, TextEditingController.new);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _unitFactors[u.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '1 ${u.code} = ... ${units.first.code}',
                        hintText:
                            'Isi jumlah ${units.first.code} dalam 1 ${u.code}',
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: _variants.isNotEmpty,
                  title: Text(
                    'Varian (${_variants.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  children: [
                    for (var i = 0; i < _variants.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _variants[i].$1,
                              decoration: const InputDecoration(
                                labelText: 'Nama varian',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _variants[i].$2,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Harga jual',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _variants.removeAt(i)),
                          ),
                        ],
                      ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _variants.add((
                            TextEditingController(),
                            TextEditingController(),
                          ));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah varian'),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _canSave && !_loadingExisting ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _saving
                        ? 'Menyimpan...'
                        : widget.productId == null
                        ? 'Simpan Produk'
                        : 'Update Produk',
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
