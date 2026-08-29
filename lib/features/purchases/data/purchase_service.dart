import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import '../../../database/app_database.dart';

class PurchaseLineInput {
  const PurchaseLineInput({
    required this.productId,
    this.variantId,
    required this.qtyMicro,
    required this.unitId,
    required this.conversionFactorMicro,
    required this.unitCostMinor,
    this.discountAmountMinor = 0,
  });

  final int productId;
  final int? variantId;
  final int qtyMicro;
  final int unitId;
  final int conversionFactorMicro;
  final int unitCostMinor;
  final int discountAmountMinor;

  int get qtyBaseMicro =>
      ((qtyMicro * conversionFactorMicro) / 1000000).round();

  int get lineTotalMinor =>
      (((qtyMicro / 1000000) * unitCostMinor).round()) - discountAmountMinor;
}

class PurchaseService {
  const PurchaseService(this._db);

  final AppDatabase _db;

  /// Creates, finalizes purchase, updates stock, recalculates WAC cost, and records payments.
  Future<Purchase> createAndFinalizePurchase({
    required int businessId,
    int? supplierId,
    String? purchaseNumber,
    required List<PurchaseLineInput> lines,
    int? accountId,
    int paidNowMinor = 0,
    int otherCostMinor = 0,
    int discountTotalMinor = 0,
    int taxTotalMinor = 0,
    String? note,
  }) async {
    if (lines.isEmpty) {
      throw const Failure(
        code: ErrorCodes.invalidQuantity,
        message: 'Pembelian harus memiliki minimal satu barang.',
      );
    }

    return _db.transaction(() async {
      final now = DateTime.now().toUtc();

      // 1. Calculate totals
      int subtotalMinor = 0;
      for (final line in lines) {
        subtotalMinor += line.lineTotalMinor;
      }

      final grandTotalMinor =
          subtotalMinor - discountTotalMinor + taxTotalMinor + otherCostMinor;
      final paidTotalMinor = paidNowMinor.clamp(0, grandTotalMinor);
      final dueTotalMinor = grandTotalMinor - paidTotalMinor;

      // 2. Generate purchase number if not provided
      final finalNumber = purchaseNumber ?? 'PB-${now.millisecondsSinceEpoch}';

      // 3. Insert Purchases record
      final purchaseId = await _db.into(_db.purchases).insert(
        PurchasesCompanion.insert(
          businessId: businessId,
          supplierId: Value(supplierId),
          number: Value(finalNumber),
          status: const Value('finalized'),
          subtotalMinor: Value(subtotalMinor),
          discountTotalMinor: Value(discountTotalMinor),
          taxTotalMinor: Value(taxTotalMinor),
          otherCostMinor: Value(otherCostMinor),
          grandTotalMinor: Value(grandTotalMinor),
          paidTotalMinor: Value(paidTotalMinor),
          dueTotalMinor: Value(dueTotalMinor),
          note: Value(note),
          finalizedAt: Value(now),
        ),
      );

      // 4. Insert lines, increase stock, and calculate WAC
      for (final line in lines) {
        await _db.into(_db.purchaseLines).insert(
          PurchaseLinesCompanion.insert(
            purchaseId: purchaseId,
            productId: line.productId,
            variantId: Value(line.variantId),
            qtyMicro: line.qtyMicro,
            unitId: line.unitId,
            conversionFactorMicro: line.conversionFactorMicro,
            qtyBaseMicro: line.qtyBaseMicro,
            unitCostMinor: line.unitCostMinor,
            discountAmountMinor: Value(line.discountAmountMinor),
            lineTotalMinor: line.lineTotalMinor,
          ),
        );

        // Fetch current product or variant
        final product = await (_db.select(_db.products)..where((t) => t.id.equals(line.productId))).getSingle();
        final currentStockMicro = product.stockQuantityMicro;
        final currentCostMinor = product.costPriceMinor;

        final incomingQtyMicro = line.qtyBaseMicro;
        final incomingCostPerBaseMinor = (line.lineTotalMinor / (incomingQtyMicro / 1000000)).round();

        // Calculate new Weighted Average Cost (WAC)
        int newCostPriceMinor;
        if (currentStockMicro <= 0) {
          newCostPriceMinor = incomingCostPerBaseMinor;
        } else {
          final oldTotalValue = (currentStockMicro / 1000000) * currentCostMinor;
          final incomingTotalValue = (incomingQtyMicro / 1000000) * incomingCostPerBaseMinor;
          final newTotalStock = (currentStockMicro + incomingQtyMicro) / 1000000;
          newCostPriceMinor = ((oldTotalValue + incomingTotalValue) / newTotalStock).round();
        }

        final newStockMicro = currentStockMicro + incomingQtyMicro;

        // Update product stock and WAC cost
        await (_db.update(_db.products)..where((t) => t.id.equals(line.productId))).write(
          ProductsCompanion(
            stockQuantityMicro: Value(newStockMicro),
            costPriceMinor: Value(newCostPriceMinor),
            updatedAt: Value(now),
          ),
        );

        // Record stock movement
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            businessId: businessId,
            productId: line.productId,
            variantId: Value(line.variantId),
            purchaseId: Value(purchaseId),
            movementType: 'purchase_in',
            qtyBaseMicro: incomingQtyMicro,
            unitCostMinor: Value(incomingCostPerBaseMinor),
            referenceNumber: Value(finalNumber),
            note: Value('Pembelian $finalNumber'),
            occurredAt: Value(now),
          ),
        );
      }

      // 5. If paidNowMinor > 0, deduct account balance and insert payment
      if (paidTotalMinor > 0 && accountId != null) {
        final account = await (_db.select(_db.accounts)..where((t) => t.id.equals(accountId))).getSingle();
        final newBalance = account.currentBalanceMinor - paidTotalMinor;

        await (_db.update(_db.accounts)..where((t) => t.id.equals(accountId))).write(
          AccountsCompanion(
            currentBalanceMinor: Value(newBalance),
          ),
        );

        await _db.into(_db.payments).insert(
          PaymentsCompanion.insert(
            businessId: businessId,
            direction: 'out',
            purpose: 'purchase_payment',
            accountId: Value(accountId),
            amountMinor: paidTotalMinor,
            purchaseId: Value(purchaseId),
            note: Value('Pembelian $finalNumber'),
            paidAt: Value(now),
          ),
        );
      }

      return (_db.select(_db.purchases)..where((t) => t.id.equals(purchaseId))).getSingle();
    });
  }

  /// Lists purchases for a business.
  Future<List<Purchase>> listPurchases({
    required int businessId,
    String? status,
  }) async {
    final query = _db.select(_db.purchases)
      ..where((t) => t.businessId.equals(businessId));
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }
}
