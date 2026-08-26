import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';
import '../controllers/inventory_providers.dart';

/// Kartu stok: riwayat pergerakan satu produk (terbaru dulu).
class StockCardScreen extends ConsumerWidget {
  const StockCardScreen({super.key, required this.productId});

  final int productId;

  String _typeLabel(String t) => switch (t) {
        'opening_balance' => 'Stok awal',
        'purchase_in' => 'Pembelian',
        'sale_out' => 'Penjualan',
        'sales_return_in' => 'Retur penjualan',
        'purchase_return_out' => 'Retur pembelian',
        'adjustment_in' => 'Penyesuaian (+)',
        'adjustment_out' => 'Penyesuaian (-)',
        'stock_opname' => 'Opname',
        _ => t,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsFuture = ref
        .watch(inventoryServiceProvider.future)
        .then((service) => service.movementsFor(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Kartu Stok')),
      body: FutureBuilder<List<StockMovement>>(
        future: movementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final movements = snapshot.data ?? const <StockMovement>[];
          if (movements.isEmpty) {
            return const Center(child: Text('Belum ada pergerakan stok.'));
          }
          final df = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
          return ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Theme.of(context).dividerColor),
            itemBuilder: (context, i) {
              final m = movements[i];
              final qtyMicro = m.qtyBaseMicro;
              final occurredAt = m.occurredAt.toLocal();
              final note = m.note ?? '';
              final positive = qtyMicro > 0;
              return ListTile(
                leading: Icon(
                  positive
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: positive
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.error,
                ),
                isThreeLine: note.isNotEmpty,
                title: Text(_typeLabel(m.movementType)),
                subtitle: Text(
                  [
                    df.format(occurredAt),
                    if (note.isNotEmpty) note,
                  ].join('\n'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${positive ? '+' : ''}${microToDecimalString(qtyMicro)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: positive
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.error,
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
