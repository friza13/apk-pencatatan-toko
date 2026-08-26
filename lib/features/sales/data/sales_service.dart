import 'package:drift/drift.dart';

import '../../../core/domain/money_policy.dart';
import '../../../core/error/failures.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';

/// Input for one sale line coming from the cart.
class SaleLineInput {
  SaleLineInput({
    required this.productId,
    required this.qtyMicro,
    required this.unitPriceMinor,
    this.lineDiscountPercentBp = 0,
    this.lineDiscountFixedMinor = 0,
    this.variantId,
  });

  final int productId;
  final int? variantId;
  final int qtyMicro;
  final int unitPriceMinor;
  final int lineDiscountPercentBp;
  final int lineDiscountFixedMinor;
}

class CheckoutInput {
  CheckoutInput({
    required this.lines,
    required this.accountId,
    this.customerId,
    this.salesmanId,
    this.paidNowMinor = 0,
    this.orderDiscountLevel1PercentBp = 0,
    this.orderDiscountLevel2PercentBp = 0,
    this.orderDiscountFixedMinor = 0,
    this.taxRateBp = 0,
    this.serviceChargeBp = 0,
    this.shippingFeeMinor = 0,
    this.denomination = 0,
    this.paymentMethod = 'cash',
    this.note,
  });

  final List<SaleLineInput> lines;
  final int accountId;
  final int? customerId;
  final int? salesmanId;

  /// Cash received now; remainder becomes receivable/credit.
  final int paidNowMinor;

  final int orderDiscountLevel1PercentBp;
  final int orderDiscountLevel2PercentBp;
  final int orderDiscountFixedMinor;
  final int taxRateBp;
  final int serviceChargeBp;
  final int shippingFeeMinor;
  final int denomination;
  final String paymentMethod;
  final String? note;
}

class CheckoutOutput {
  CheckoutOutput({
    required this.saleId,
    required this.number,
    required this.grandTotalMinor,
    required this.dueTotalMinor,
  });

  final int saleId;
  final String number;
  final int grandTotalMinor;
  final int dueTotalMinor;
}

class _PreparedLine {
  _PreparedLine({
    required this.productId,
    required this.variantId,
    required this.productNameSnapshot,
    required this.skuSnapshot,
    required this.unitNameSnapshot,
    required this.unitId,
    required this.qtyMicro,
    required this.qtyBaseMicro,
    required this.unitPriceMinor,
    required this.discountMinor,
    required this.costSnapshotMinor,
    required this.lineNetMinor,
    required this.tracked,
  });

  final int productId;
  final int? variantId;
  final String productNameSnapshot;
  final String? skuSnapshot;
  final String unitNameSnapshot;
  final int unitId;
  final int qtyMicro;
  final int qtyBaseMicro;
  final int unitPriceMinor;
  final int discountMinor;
  final int costSnapshotMinor;
  final int lineNetMinor;
  final bool tracked;
}

/// Sales application service - the atomic heart of NotaKit (DFD 11.3).
///
/// checkout() commits in ONE database transaction:
/// number -> sale -> lines(snapshot #7) -> stock movements + cache ->
/// payment + ledger -> receivable -> activity log.
class SalesService {
  SalesService(this._db);

  final AppDatabase _db;

  Future<CheckoutOutput> checkout(CheckoutInput input) {
    return _db.transaction(() async {
      if (input.lines.isEmpty) {
        throw ArgumentError('Nota tanpa item');
      }

      final business =
          await (_db.select(_db.businesses)..limit(1)).getSingle();

      // ---- Prepare lines with snapshots + validate.
      final prepared = <_PreparedLine>[];
      for (final line in input.lines) {
        final p = await (_db.select(_db.products)
              ..where((t) => t.id.equals(line.productId)))
            .getSingleOrNull();
        if (p == null) {
          throw const Failure(
              code: ErrorCodes.productNotFound,
              message: 'Produk tidak ditemukan');
        }
        if (!p.isActive) {
          throw Failure(
              code: ErrorCodes.productInactive, message: '${p.name} nonaktif');
        }
        if (line.qtyMicro <= 0) {
          throw Failure(
              code: ErrorCodes.invalidQuantity,
              message: 'Qty ${p.name} tidak valid');
        }

        final gross =
            MoneyPolicy.lineGrossMinor(line.qtyMicro, line.unitPriceMinor);
        final net = MoneyPolicy.lineNetMinor(
            gross, line.lineDiscountPercentBp, line.lineDiscountFixedMinor);

        final qtyBaseMicro = line.qtyMicro; // base-unit cart (MVP)
        if (p.trackStock && p.type == 'goods') {
          if (qtyBaseMicro > p.stockQuantityMicro) {
            throw Failure(
              code: ErrorCodes.stockInsufficient,
              message:
                  'Stok ${p.name} tidak cukup (${microToDecimalString(p.stockQuantityMicro)} tersedia)',
            );
          }
        }

        final baseUnit = await (_db.select(_db.units)
              ..where((t) => t.id.equals(p.baseUnitId)))
            .getSingle();

        prepared.add(_PreparedLine(
          productId: p.id,
          variantId: line.variantId,
          productNameSnapshot: p.name,
          skuSnapshot: p.sku,
          unitNameSnapshot: baseUnit.code,
          unitId: p.baseUnitId,
          qtyMicro: line.qtyMicro,
          qtyBaseMicro: qtyBaseMicro,
          unitPriceMinor: line.unitPriceMinor,
          discountMinor: gross - net,
          costSnapshotMinor: p.costPriceMinor,
          lineNetMinor: net,
          tracked: p.trackStock && p.type == 'goods',
        ));
      }

      // ---- Totals (central policy D-011).
      final totals = computeSaleTotals(SaleTotalsInput(
        lineNetTotalsMinor: prepared.map((l) => l.lineNetMinor).toList(),
        orderDiscountLevel1PercentBp: input.orderDiscountLevel1PercentBp,
        orderDiscountLevel2PercentBp: input.orderDiscountLevel2PercentBp,
        orderDiscountFixedMinor: input.orderDiscountFixedMinor,
        serviceChargeBp: input.serviceChargeBp,
        taxRateBp: input.taxRateBp,
        shippingFeeMinor: input.shippingFeeMinor,
        denomination: input.denomination,
      ));

      // ---- Payment split -> status (D-009).
      final paid = input.paidNowMinor.clamp(0, totals.grandTotalMinor);
      final due = totals.grandTotalMinor - paid;
      var status = 'paid';
      if (due > 0) {
        status = paid > 0 ? 'partially_paid' : 'credit';
      }

      // ---- Number + sale header.
      final nextSeq = business.invoiceSequence + 1;
      final number =
          '${business.invoicePrefix}${nextSeq.toString().padLeft(5, '0')}';

      final saleId = await _db.into(_db.sales).insert(SalesCompanion.insert(
            businessId: business.id,
            customerId: Value(input.customerId),
            salesmanId: Value(input.salesmanId),
            number: Value(number),
            status: Value(status),
            subtotalMinor: Value(totals.subtotalMinor),
            discountTotalMinor: Value(totals.discountTotalMinor),
            taxTotalMinor: Value(totals.taxTotalMinor),
            serviceChargeMinor: Value(totals.serviceChargeMinor),
            shippingFeeMinor: Value(totals.shippingFeeMinor),
            roundingMinor: Value(totals.roundingMinor),
            grandTotalMinor: Value(totals.grandTotalMinor),
            paidTotalMinor: Value(paid),
            dueTotalMinor: Value(due),
            note: Value(input.note),
            finalizedAt: Value(DateTime.now().toUtc()),
          ));

      await (_db.update(_db.businesses)
            ..where((t) => t.id.equals(business.id)))
          .write(BusinessesCompanion(invoiceSequence: Value(nextSeq)));

      // ---- Lines with full transaction-time snapshot (#7).
      for (final l in prepared) {
        await _db.into(_db.saleLines).insert(SaleLinesCompanion.insert(
              saleId: saleId,
              productId: Value(l.productId),
              variantId: Value(l.variantId),
              productNameSnapshot: l.productNameSnapshot,
              skuSnapshot: Value(l.skuSnapshot),
              unitNameSnapshot: l.unitNameSnapshot,
              unitId: Value(l.unitId),
              qtyMicro: l.qtyMicro,
              conversionFactorMicro: quantityScale,
              qtyBaseMicro: l.qtyBaseMicro,
              unitPriceMinor: l.unitPriceMinor,
              discountAmountMinor: Value(l.discountMinor),
              costPriceSnapshotMinor: Value(l.costSnapshotMinor),
              lineTotalMinor: l.lineNetMinor,
            ));
      }

      // ---- Stock movements + cached balance sync (D-014).
      for (final l in prepared) {
        if (!l.tracked || l.qtyBaseMicro == 0) continue;
        await _db.into(_db.stockMovements).insert(StockMovementsCompanion.insert(
              businessId: business.id,
              productId: l.productId,
              variantId: Value(l.variantId),
              movementType: 'sale_out',
              qtyBaseMicro: -l.qtyBaseMicro,
              unitCostMinor: Value(l.costSnapshotMinor),
              referenceNumber: Value(number),
            ));
        final fresh = await (_db.select(_db.products)
              ..where((t) => t.id.equals(l.productId)))
            .getSingle();
        await (_db.update(_db.products)..where((t) => t.id.equals(l.productId)))
            .write(ProductsCompanion(
          stockQuantityMicro:
              Value(fresh.stockQuantityMicro - l.qtyBaseMicro),
        ));
      }

      // ---- Payment + ledger (FR-CASH-001).
      if (paid > 0) {
        final paymentId = await _db.into(_db.payments).insert(
              PaymentsCompanion.insert(
                businessId: business.id,
                direction: 'in',
                purpose: 'sale_payment',
                accountId: Value(input.accountId),
                amountMinor: paid,
                method: Value(input.paymentMethod),
                saleId: Value(saleId),
              ),
            );
        await _db.into(_db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
              accountId: Value(input.accountId),
              sourceType: 'payment',
              sourceId: Value('$paymentId'),
              entryType: 'debit',
              amountMinor: paid,
              note: Value('Pembayaran $number'),
            ));
        final acc = await (_db.select(_db.accounts)
              ..where((t) => t.id.equals(input.accountId)))
            .getSingle();
        await (_db.update(_db.accounts)
              ..where((t) => t.id.equals(input.accountId)))
            .write(AccountsCompanion(
          currentBalanceMinor: Value(acc.currentBalanceMinor + paid),
        ));
      }

      // ---- Receivable (FR-AR-001).
      if (due > 0 && input.customerId != null) {
        await _db.into(_db.receivables).insert(ReceivablesCompanion.insert(
              businessId: business.id,
              saleId: saleId,
              customerId: input.customerId!,
              originalAmountMinor: due,
              remainingAmountMinor: due,
              dueDate: DateTime.now().toUtc().add(const Duration(days: 7)),
            ));
      }

      // ---- Audit (FR-AUDIT-001).
      await _db.into(_db.activityLogs).insert(ActivityLogsCompanion.insert(
            businessId: business.id,
            actorType: 'owner',
            action: 'sale.created',
            entityType: 'sale',
            entityId: Value('$saleId'),
            afterJson:
                Value('{"number":"$number","total":${totals.grandTotalMinor}}'),
          ));

      return CheckoutOutput(
        saleId: saleId,
        number: number,
        grandTotalMinor: totals.grandTotalMinor,
        dueTotalMinor: due,
      );
    });
  }

  /// Voids a finalized sale: restores stock, marks voided, writes audit.
  /// Cash reversal flows through refunds (P7+) - documented MVP simplification.
  Future<void> voidSale(int saleId, String reason) {
    return _db.transaction(() async {
      final sale = await (_db.select(_db.sales)
            ..where((t) => t.id.equals(saleId)))
          .getSingle();
      if (sale.status == 'voided') return;

      final lines = await (_db.select(_db.saleLines)
            ..where((t) => t.saleId.equals(saleId)))
          .get();

      for (final l in lines) {
        final pid = l.productId;
        if (pid == null) continue;
        final p = await (_db.select(_db.products)
              ..where((t) => t.id.equals(pid)))
            .getSingle();
        if (!p.trackStock || p.type != 'goods') continue;
        await _db.into(_db.stockMovements).insert(StockMovementsCompanion.insert(
              businessId: p.businessId,
              productId: pid,
              movementType: 'adjustment_in',
              qtyBaseMicro: l.qtyBaseMicro,
              unitCostMinor: Value(l.costPriceSnapshotMinor),
              referenceNumber: Value('VOID-${sale.number ?? saleId}'),
              note: Value('Void nota: $reason'),
            ));
        await (_db.update(_db.products)..where((t) => t.id.equals(pid))).write(
          ProductsCompanion(
            stockQuantityMicro:
                Value(p.stockQuantityMicro + l.qtyBaseMicro),
          ),
        );
      }

      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(
          status: const Value('voided'),
          voidedAt: Value(DateTime.now().toUtc()),
          note: Value(sale.note == null
              ? 'Void: $reason'
              : '${sale.note} | Void: $reason'),
        ),
      );

      await _db.into(_db.activityLogs).insert(ActivityLogsCompanion.insert(
            businessId: sale.businessId,
            actorType: 'owner',
            action: 'sale.voided',
            entityType: 'sale',
            entityId: Value('$saleId'),
            afterJson: Value('{"reason":"$reason"}'),
          ));
    });
  }
}
