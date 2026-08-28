import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/units/quantity.dart';
import '../../../../database/app_database.dart';
import '../../../products/controllers/products_providers.dart';
import '../../../security/providers.dart';
import '../../controllers/inventory_providers.dart';

enum StockAction { opening, adjustIn, adjustOut, opname }

Future<void> showStockActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Product product,
  List<ProductVariant> variants = const [],
  StockAction initialAction = StockAction.adjustIn,
  VoidCallback? onUpdated,
}) async {
  final db = await ref.read(appDatabaseProvider.future);
  final allMovements = await (db.select(
    db.stockMovements,
  )..where((t) => t.productId.equals(product.id))).get();

  if (!context.mounted) return;

  StockAction selectedAction = initialAction;
  int? selectedVariantId;
  final qtyController = TextEditingController();
  final noteController = TextEditingController();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final currentStockMicro = selectedVariantId == null
            ? product.stockQuantityMicro
            : (variants
                      .where((v) => v.id == selectedVariantId)
                      .firstOrNull
                      ?.stockQuantityMicro ??
                  0);

        final hasOpening = allMovements.any(
          (m) =>
              m.variantId == selectedVariantId &&
              m.movementType == 'opening_balance',
        );

        final label = switch (selectedAction) {
          StockAction.opening => 'Jumlah stok awal',
          StockAction.adjustIn => 'Jumlah tambah (+)',
          StockAction.adjustOut => 'Jumlah kurangi (-)',
          StockAction.opname => 'Hasil hitung fisik sebenarnya',
        };

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Atur Stok — ${product.name}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Stok saat ini: ${microToDecimalString(currentStockMicro)}',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah'),
                      selected: selectedAction == StockAction.adjustIn,
                      onSelected: (s) {
                        if (s) {
                          setSheetState(
                            () => selectedAction = StockAction.adjustIn,
                          );
                        }
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.remove, size: 18),
                      label: const Text('Kurang'),
                      selected: selectedAction == StockAction.adjustOut,
                      onSelected: (s) {
                        if (s) {
                          setSheetState(
                            () => selectedAction = StockAction.adjustOut,
                          );
                        }
                      },
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('Opname'),
                      selected: selectedAction == StockAction.opname,
                      onSelected: (s) {
                        if (s) {
                          setSheetState(
                            () => selectedAction = StockAction.opname,
                          );
                        }
                      },
                    ),
                    if (!hasOpening)
                      ChoiceChip(
                        avatar: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Stok Awal'),
                        selected: selectedAction == StockAction.opening,
                        onSelected: (s) {
                          if (s) {
                            setSheetState(
                              () => selectedAction = StockAction.opening,
                            );
                          }
                        },
                      ),
                  ],
                ),
                if (variants.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedVariantId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Varian',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        child: Text('Semua / Produk Utama'),
                      ),
                      for (final v in variants)
                        DropdownMenuItem<int?>(
                          value: v.id,
                          child: Text(
                            '${v.name} (Stok: ${microToDecimalString(v.stockQuantityMicro)})',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      setSheetState(() {
                        selectedVariantId = v;
                        if (hasOpening &&
                            selectedAction == StockAction.opening) {
                          selectedAction = StockAction.adjustIn;
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    helperText: selectedAction == StockAction.opname
                        ? 'Sistem akan menghitung selisih otomatis.'
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Alasan (opsional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Simpan Perubahan Stok'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final rawQty = qtyController.text.trim();
  if (rawQty.isEmpty) return;

  int qtyMicro;
  try {
    qtyMicro = toMicro(rawQty);
  } catch (_) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Angka tidak valid: $rawQty')));
    return;
  }

  final note = noteController.text.trim();
  final service = await ref.read(inventoryServiceProvider.future);

  final res = switch (selectedAction) {
    StockAction.opening => await service.setOpeningBalance(
      product.id,
      qtyMicro,
      variantId: selectedVariantId,
    ),
    StockAction.adjustIn => await service.adjustStock(
      product.id,
      qtyMicro.abs(),
      note.isEmpty ? 'Penyesuaian tambah' : note,
      variantId: selectedVariantId,
    ),
    StockAction.adjustOut => await service.adjustStock(
      product.id,
      -qtyMicro.abs(),
      note.isEmpty ? 'Penyesuaian kurang' : note,
      variantId: selectedVariantId,
    ),
    StockAction.opname => await service.stockOpname(
      product.id,
      qtyMicro,
      note,
      variantId: selectedVariantId,
    ),
  };

  if (!context.mounted) return;

  if (!res.isSuccess) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(res.failure!.message)));
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Stok berhasil diperbarui: ${microToDecimalString(res.newStockMicro!)}',
      ),
    ),
  );

  ref.invalidate(productsControllerProvider);
  onUpdated?.call();
}
