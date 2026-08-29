import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../database/app_database.dart';
import '../../finance/controllers/finance_providers.dart';
import '../../products/controllers/products_providers.dart';
import '../controllers/purchases_providers.dart';
import '../data/purchase_service.dart';

class _FormPurchaseLine {
  _FormPurchaseLine({
    required this.product,
    required this.qty,
    required this.unitCostMinor,
  });

  final Product product;
  double qty;
  int unitCostMinor;

  int get lineTotalMinor => (qty * unitCostMinor).round();
}

/// Screen to create and finalize a new purchase order / invoice.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _numberCtrl = TextEditingController();
  final _otherCostCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int? _selectedSupplierId;
  int? _selectedAccountId;
  final List<_FormPurchaseLine> _lines = [];
  bool _isSaving = false;

  int get _subtotalMinor {
    int total = 0;
    for (final l in _lines) {
      total += l.lineTotalMinor;
    }
    return total;
  }

  int get _otherCostMinor {
    return int.tryParse(_otherCostCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int get _grandTotalMinor => _subtotalMinor + _otherCostMinor;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _otherCostCtrl.dispose();
    _paidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addProductDialog() async {
    final business = await ref.read(currentBusinessProvider.future);
    final repo = await ref.read(productRepositoryProvider.future);
    final products = await repo.search(
      businessId: business.id,
    );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Produk untuk Dibeli', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in products)
                      ListTile(
                        title: Text(p.name),
                        subtitle: Text('Harga Modal: ${formatMinor(p.costPriceMinor)}'),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _lines.add(
                              _FormPurchaseLine(
                                product: p,
                                qty: 1.0,
                                unitCostMinor: p.costPriceMinor,
                              ),
                            );
                            _paidCtrl.text = '$_grandTotalMinor';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal satu produk.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final business = await ref.read(currentBusinessProvider.future);
      final service = await ref.read(purchaseServiceProvider.future);

      final paidNow = int.tryParse(_paidCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final inputLines = _lines.map((l) {
        return PurchaseLineInput(
          productId: l.product.id,
          qtyMicro: (l.qty * 1000000).round(),
          unitId: l.product.baseUnitId,
          conversionFactorMicro: 1000000,
          unitCostMinor: l.unitCostMinor,
        );
      }).toList();

      await service.createAndFinalizePurchase(
        businessId: business.id,
        supplierId: _selectedSupplierId,
        purchaseNumber: _numberCtrl.text.trim().isEmpty ? null : _numberCtrl.text.trim(),
        lines: inputLines,
        accountId: _selectedAccountId,
        paidNowMinor: paidNow,
        otherCostMinor: _otherCostMinor,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      ref
        ..invalidate(purchasesListProvider)
        ..invalidate(productsControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembelian berhasil disimpan & stok diperbarui!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catat Pembelian Baru')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _numberCtrl,
            decoration: const InputDecoration(
              labelText: 'No. Faktur / Surat Jalan Supplier (Opsional)',
            ),
          ),
          const SizedBox(height: 12),
          suppliersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const SizedBox(),
            data: (suppliers) => DropdownButtonFormField<int?>(
              initialValue: _selectedSupplierId,
              decoration: const InputDecoration(labelText: 'Supplier'),
              items: [
                const DropdownMenuItem<int?>(child: Text('Tanpa Supplier')),
                for (final s in suppliers)
                  DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _selectedSupplierId = v),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daftar Barang', style: Theme.of(context).textTheme.titleSmall),
              FilledButton.tonalIcon(
                onPressed: _addProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Belum ada produk ditambahkan.')),
              ),
            ),
          for (int i = 0; i < _lines.length; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _lines[i].product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _lines.removeAt(i);
                              _paidCtrl.text = '$_grandTotalMinor';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _lines[i].qty.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty (Pcs)'),
                            onChanged: (v) {
                              final parsed = double.tryParse(v) ?? 1;
                              setState(() {
                                _lines[i].qty = parsed;
                                _paidCtrl.text = '$_grandTotalMinor';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: '${_lines[i].unitCostMinor}',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Harga Beli (Rp)'),
                            onChanged: (v) {
                              final parsed = int.tryParse(v) ?? 0;
                              setState(() {
                                _lines[i].unitCostMinor = parsed;
                                _paidCtrl.text = '$_grandTotalMinor';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subtotal: ${formatMinor(_lines[i].lineTotalMinor)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _otherCostCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Biaya Lain / Ongkir (Rp)'),
            onChanged: (_) => setState(() => _paidCtrl.text = '$_grandTotalMinor'),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    formatMinor(_grandTotalMinor),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => const SizedBox(),
            data: (accounts) => DropdownButtonFormField<int?>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(labelText: 'Akun Kas / Pembayaran'),
              items: [
                const DropdownMenuItem<int?>(child: Text('Tanpa Akun (Hutang Penuh)')),
                for (final a in accounts)
                  DropdownMenuItem<int?>(
                    value: a.id,
                    child: Text('${a.name} (${formatMinor(a.currentBalanceMinor)})'),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedAccountId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Dibayar Sekarang (Rp)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan Pembelian'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan & Finalisasi Pembelian'),
          ),
        ],
      ),
    );
  }
}
