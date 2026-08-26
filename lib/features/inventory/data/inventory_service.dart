import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';

/// Result wrapper for inventory operations.
class InventoryResult {
  const InventoryResult.success(this.newStockMicro)
      : failure = null;
  const InventoryResult.failure(this.failure) : newStockMicro = null;

  final int? newStockMicro;
  final Failure? failure;

  bool get isSuccess => failure == null;
}

/// Inventory application service (FR-STOCK-001/002, D-014).
///
/// The movement ledger is the source of truth; the cached
/// `products.stock_quantity_micro` is a materialized balance that is updated
/// in the SAME transaction as the movement — never independently.
class InventoryService {
  InventoryService(this._db);

  final AppDatabase _db;

  /// Sets the initial stock via an OPENING_BALANCE movement. Only allowed
  /// while no movements exist for the product yet (opening happens once).
  Future<InventoryResult> setOpeningBalance(
    int productId,
    int qtyMicro,
  ) async {
    if (qtyMicro < 0) {
      return const InventoryResult.failure(
          Failure(code: ErrorCodes.invalidQuantity, message: 'Stok awal tidak boleh negatif'));
    }
    final existing = await (_db.select(_db.stockMovements)
          ..where((t) => t.productId.equals(productId)))
        .get();
    if (existing.isNotEmpty) {
      return const InventoryResult.failure(
          Failure(code: ErrorCodes.invalidQuantity, message: 'Stok awal sudah pernah diatur. Gunakan penyesuaian.'));
    }
    return _apply(productId, 'opening_balance', qtyMicro,
        note: 'Stok awal');
  }

  /// Adds (positive) or removes (negative) stock with an ADJUSTMENT movement.
  Future<InventoryResult> adjustStock(
    int productId,
    int deltaMicro,
    String note,
  ) async {
    if (deltaMicro == 0) {
      return const InventoryResult.failure(
          Failure(code: ErrorCodes.invalidQuantity, message: 'Penyesuaian tidak boleh nol.'));
    }
    return _apply(
      productId,
      deltaMicro > 0 ? 'adjustment_in' : 'adjustment_out',
      deltaMicro,
      note: note.trim().isEmpty ? 'Penyesuaian' : note.trim(),
    );
  }

  /// Physical count reconciliation: delta = counted − current.
  Future<InventoryResult> stockOpname(
    int productId,
    int countedQtyMicro,
    String note,
  ) async {
    if (countedQtyMicro < 0) {
      return const InventoryResult.failure(
          Failure(code: ErrorCodes.invalidQuantity, message: 'Hasil hitung tidak boleh negatif.'));
    }
    final current = await _cachedStock(productId);
    final delta = countedQtyMicro - current;
    if (delta == 0) {
      return InventoryResult.success(current);
    }
    final type = delta > 0 ? 'stock_opname' : 'stock_opname';
    return _apply(
      productId,
      type,
      delta,
      note:
          'Opname: hitung=${microToDecimalString(countedQtyMicro)}, '
          'sistem=${microToDecimalString(current)}'
          '${note.trim().isEmpty ? '' : ' — ${note.trim()}'}',
    );
  }

  /// Kartu stok: newest-first movement history for one product.
  Future<List<StockMovement>> movementsFor(int productId) =>
      (_db.select(_db.stockMovements)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .get();

  Future<int> _cachedStock(int productId) async {
    final row = await (_db.select(_db.products)
          ..where((t) => t.id.equals(productId)))
        .getSingle();
    return row.stockQuantityMicro;
  }

  Future<InventoryResult> _apply(
    int productId,
    String movementType,
    int signedQtyMicro, {
    required String note,
  }) {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)
            ..where((t) => t.id.equals(productId)))
          .getSingle();

      final newStock = product.stockQuantityMicro + signedQtyMicro;
      if (newStock < 0) {
        // Rollback by throwing inside the transaction.
        throw const StockInsufficientException();
      }

      await _db.into(_db.stockMovements).insert(StockMovementsCompanion.insert(
            businessId: product.businessId,
            productId: productId,
            variantId: const Value(null),
            movementType: movementType,
            qtyBaseMicro: signedQtyMicro,
            unitCostMinor: Value(product.costPriceMinor),
            referenceNumber: const Value(null),
            note: Value(note),
          ));

      await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
          .write(ProductsCompanion(
        stockQuantityMicro: Value(newStock),
      ));

      return InventoryResult.success(newStock);
    }).catchError((Object e) {
      if (e is StockInsufficientException) {
        return InventoryResult.failure(Failure(
          code: ErrorCodes.stockInsufficient,
          message: 'Stok tidak cukup untuk perubahan ini.',
        ));
      }
      return InventoryResult.failure(Failure(
        code: ErrorCodes.databaseError,
        message: e.toString(),
      ));
    });
  }
}

class StockInsufficientException implements Exception {
  const StockInsufficientException();
}
