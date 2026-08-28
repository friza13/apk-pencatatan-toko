import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';

/// Result wrapper for inventory operations.
class InventoryResult {
  const InventoryResult.success(this.newStockMicro) : failure = null;
  const InventoryResult.failure(this.failure) : newStockMicro = null;

  final int? newStockMicro;
  final Failure? failure;

  bool get isSuccess => failure == null;
}

/// Inventory application service (FR-STOCK-001/002, D-014).
///
/// The movement ledger is the source of truth; the cached stock balance is
/// updated in the same transaction as the movement.
class InventoryService {
  InventoryService(this._db);

  final AppDatabase _db;

  Future<InventoryResult> setOpeningBalance(
    int productId,
    int qtyMicro, {
    int? variantId,
  }) async {
    if (qtyMicro < 0) {
      return const InventoryResult.failure(
        Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Stok awal tidak boleh negatif',
        ),
      );
    }
    final existing = await (_db.select(
      _db.stockMovements,
    )..where((t) => t.productId.equals(productId))).get();
    if (existing.any((movement) => movement.variantId == variantId)) {
      return const InventoryResult.failure(
        Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Stok awal sudah pernah diatur. Gunakan penyesuaian.',
        ),
      );
    }
    return _apply(
      productId,
      'opening_balance',
      qtyMicro,
      variantId: variantId,
      note: 'Stok awal',
    );
  }

  Future<InventoryResult> adjustStock(
    int productId,
    int deltaMicro,
    String note, {
    int? variantId,
  }) async {
    if (deltaMicro == 0) {
      return const InventoryResult.failure(
        Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Penyesuaian tidak boleh nol.',
        ),
      );
    }
    return _apply(
      productId,
      deltaMicro > 0 ? 'adjustment_in' : 'adjustment_out',
      deltaMicro,
      variantId: variantId,
      note: note.trim().isEmpty ? 'Penyesuaian' : note.trim(),
    );
  }

  Future<InventoryResult> stockOpname(
    int productId,
    int countedQtyMicro,
    String note, {
    int? variantId,
  }) async {
    if (countedQtyMicro < 0) {
      return const InventoryResult.failure(
        Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Hasil hitung tidak boleh negatif.',
        ),
      );
    }
    final current = await _cachedStock(productId, variantId: variantId);
    final delta = countedQtyMicro - current;
    if (delta == 0) {
      return InventoryResult.success(current);
    }
    return _apply(
      productId,
      'stock_opname',
      delta,
      variantId: variantId,
      note:
          'Opname: hitung=${microToDecimalString(countedQtyMicro)}, '
          'sistem=${microToDecimalString(current)}'
          '${note.trim().isEmpty ? '' : ' — ${note.trim()}'}',
    );
  }

  Future<List<StockMovement>> movementsFor(
    int productId, {
    int? variantId,
  }) async {
    final rows =
        await (_db.select(_db.stockMovements)
              ..where((t) => t.productId.equals(productId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
            .get();
    return rows.where((movement) => movement.variantId == variantId).toList();
  }

  Future<int> _cachedStock(int productId, {int? variantId}) async {
    if (variantId != null) {
      final variant = await (_db.select(
        _db.productVariants,
      )..where((t) => t.id.equals(variantId))).getSingle();
      return variant.stockQuantityMicro;
    }
    final row = await (_db.select(
      _db.products,
    )..where((t) => t.id.equals(productId))).getSingle();
    return row.stockQuantityMicro;
  }

  Future<InventoryResult> _apply(
    int productId,
    String movementType,
    int signedQtyMicro, {
    required String note,
    int? variantId,
  }) {
    return _db
        .transaction(() async {
          final product = await (_db.select(
            _db.products,
          )..where((t) => t.id.equals(productId))).getSingle();
          final variant = variantId == null
              ? null
              : await (_db.select(_db.productVariants)..where(
                      (t) =>
                          t.id.equals(variantId) &
                          t.productId.equals(productId),
                    ))
                    .getSingleOrNull();
          if (variantId != null && variant == null) {
            throw const Failure(
              code: ErrorCodes.productNotFound,
              message: 'Varian produk tidak ditemukan.',
            );
          }
          final currentStock =
              variant?.stockQuantityMicro ?? product.stockQuantityMicro;
          final newStock = currentStock + signedQtyMicro;
          if (newStock < 0) {
            throw const StockInsufficientException();
          }

          await _db
              .into(_db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  businessId: product.businessId,
                  productId: productId,
                  variantId: Value(variantId),
                  movementType: movementType,
                  qtyBaseMicro: signedQtyMicro,
                  unitCostMinor: Value(
                    variant?.costPriceMinor ?? product.costPriceMinor,
                  ),
                  referenceNumber: const Value(null),
                  note: Value(note),
                ),
              );

          if (variant != null) {
            await (_db.update(
              _db.productVariants,
            )..where((t) => t.id.equals(variant.id))).write(
              ProductVariantsCompanion(stockQuantityMicro: Value(newStock)),
            );
          } else {
            await (_db.update(_db.products)
                  ..where((t) => t.id.equals(productId)))
                .write(ProductsCompanion(stockQuantityMicro: Value(newStock)));
          }

          return InventoryResult.success(newStock);
        })
        .catchError((Object e) {
          if (e is StockInsufficientException) {
            return InventoryResult.failure(
              const Failure(
                code: ErrorCodes.stockInsufficient,
                message: 'Stok tidak cukup untuk perubahan ini.',
              ),
            );
          }
          if (e is Failure) {
            return InventoryResult.failure(e);
          }
          return InventoryResult.failure(
            Failure(code: ErrorCodes.databaseError, message: e.toString()),
          );
        });
  }
}

class StockInsufficientException implements Exception {
  const StockInsufficientException();
}
