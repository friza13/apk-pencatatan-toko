import 'package:drift/drift.dart';

import '../../../core/domain/money_policy.dart';
import '../../../core/domain/pricing_engine.dart';
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
    this.unitId,
    this.useWholesale = false,
  });

  final int productId;
  final int? variantId;
  final int? unitId;
  final bool useWholesale;
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
    required this.conversionFactorMicro,
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
  final int conversionFactorMicro;
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

  Future<List<_PreparedLine>> _prepareLines(CheckoutInput input) async {
    // ---- Prepare lines with snapshots + validate.
    final prepared = <_PreparedLine>[];
    for (final line in input.lines) {
      final p = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(line.productId))).getSingleOrNull();
      if (p == null) {
        throw const Failure(
          code: ErrorCodes.productNotFound,
          message: 'Produk tidak ditemukan',
        );
      }
      if (!p.isActive) {
        throw Failure(
          code: ErrorCodes.productInactive,
          message: '${p.name} nonaktif',
        );
      }
      if (line.qtyMicro <= 0) {
        throw Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Qty ${p.name} tidak valid',
        );
      }

      final variant = line.variantId == null
          ? null
          : await (_db.select(_db.productVariants)..where(
                  (t) =>
                      t.id.equals(line.variantId!) & t.productId.equals(p.id),
                ))
                .getSingleOrNull();
      if (line.variantId != null && variant == null) {
        throw const Failure(
          code: ErrorCodes.productNotFound,
          message: 'Varian produk tidak ditemukan.',
        );
      }
      final soldUnitId = line.unitId ?? p.baseUnitId;
      var conversionFactorMicro = quantityScale;
      if (soldUnitId != p.baseUnitId) {
        final productUnit =
            await (_db.select(_db.productUnits)..where(
                  (t) => t.productId.equals(p.id) & t.unitId.equals(soldUnitId),
                ))
                .getSingleOrNull();
        if (productUnit == null) {
          throw const Failure(
            code: ErrorCodes.invalidQuantity,
            message: 'Konversi unit produk tidak ditemukan.',
          );
        }
        conversionFactorMicro = productUnit.conversionToBaseMicro;
      }
      final customer = input.customerId == null
          ? null
          : await (_db.select(
              _db.customers,
            )..where((t) => t.id.equals(input.customerId!))).getSingleOrNull();
      final customerType = customer?.customerTypeId == null
          ? null
          : await (_db.select(_db.customerTypes)
                  ..where((t) => t.id.equals(customer!.customerTypeId!)))
                .getSingleOrNull();
      final candidates = <PriceCandidate>[];
      if (customer != null) {
        final rows =
            await (_db.select(_db.customerPrices)..where(
                  (t) =>
                      t.customerId.equals(customer.id) &
                      t.productId.equals(p.id),
                ))
                .get();
        candidates.addAll(
          rows.map(
            (row) => PriceCandidate(
              priceMinor: row.priceMinor,
              source: PriceSource.customerOverride,
              variantId: row.variantId,
              unitId: row.unitId,
              minQtyMicro: row.minQtyMicro,
              validFromMillis: row.validFrom.millisecondsSinceEpoch,
              validToMillis: row.validTo?.millisecondsSinceEpoch,
            ),
          ),
        );
      }
      final tierRows = await (_db.select(
        _db.productPrices,
      )..where((t) => t.productId.equals(p.id))).get();
      for (final row in tierRows) {
        final tier = row.priceTierId == null
            ? null
            : await (_db.select(
                _db.priceTiers,
              )..where((t) => t.id.equals(row.priceTierId!))).getSingleOrNull();
        if (row.priceTierId != null &&
            customerType?.defaultPriceTierId != row.priceTierId) {
          continue;
        }
        if (row.customerTypeId != null &&
            customer?.customerTypeId != row.customerTypeId) {
          continue;
        }
        candidates.add(
          PriceCandidate(
            priceMinor: row.priceMinor,
            source: PriceSource.tierOrCustomerType,
            variantId: row.variantId,
            unitId: row.unitId,
            minQtyMicro: row.minQtyMicro,
            validFromMillis: row.validFrom.millisecondsSinceEpoch,
            validToMillis: row.validTo?.millisecondsSinceEpoch,
            tierPriority: tier?.priority ?? 100,
          ),
        );
      }
      final unitOverride = soldUnitId == p.baseUnitId
          ? null
          : (await (_db.select(_db.productUnits)..where(
                      (t) =>
                          t.productId.equals(p.id) &
                          t.unitId.equals(soldUnitId),
                    ))
                    .getSingle())
                .salePriceOverrideMinor;
      final resolvedPrice = PricingEngine.resolve(
        request: PricingRequest(
          nowMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
          quantityMicro: line.qtyMicro,
          productId: p.id,
          variantId: line.variantId,
          unitId: soldUnitId,
          customerTierId: customerType?.defaultPriceTierId,
          customerTypeId: customer?.customerTypeId,
          useWholesale: line.useWholesale,
        ),
        candidates: candidates,
        standardPriceMinor:
            unitOverride ?? variant?.salePriceMinor ?? p.salePriceMinor,
        wholesalePriceMinor: p.wholesalePriceMinor,
      );
      final unitPriceMinor = resolvedPrice.unitPriceMinor;
      final gross = MoneyPolicy.lineGrossMinor(line.qtyMicro, unitPriceMinor);
      final net = MoneyPolicy.lineNetMinor(
        gross,
        line.lineDiscountPercentBp,
        line.lineDiscountFixedMinor,
      );

      final baseNumerator = line.qtyMicro * conversionFactorMicro;
      if (baseNumerator % quantityScale != 0) {
        throw Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Konversi unit ${p.name} menghasilkan pecahan unit dasar.',
        );
      }
      final qtyBaseMicro = baseNumerator ~/ quantityScale;
      final availableStock =
          variant?.stockQuantityMicro ?? p.stockQuantityMicro;
      if (p.trackStock && p.type == 'goods' && qtyBaseMicro > availableStock) {
        throw Failure(
          code: ErrorCodes.stockInsufficient,
          message:
              'Stok ${p.name} tidak cukup (${microToDecimalString(availableStock)} tersedia)',
        );
      }

      final baseUnit = await (_db.select(
        _db.units,
      )..where((t) => t.id.equals(soldUnitId))).getSingle();

      prepared.add(
        _PreparedLine(
          productId: p.id,
          variantId: line.variantId,
          productNameSnapshot: p.name,
          skuSnapshot: p.sku,
          unitNameSnapshot: baseUnit.code,
          unitId: soldUnitId,
          qtyMicro: line.qtyMicro,
          qtyBaseMicro: qtyBaseMicro,
          conversionFactorMicro: conversionFactorMicro,
          unitPriceMinor: unitPriceMinor,
          discountMinor: gross - net,
          costSnapshotMinor: variant?.costPriceMinor ?? p.costPriceMinor,
          lineNetMinor: net,
          tracked: p.trackStock && p.type == 'goods',
        ),
      );
    }

    return prepared;
  }

  Future<int> previewTotal({
    required List<SaleLineInput> lines,
    int? customerId,
  }) async {
    return _db.transaction(() async {
      final prepared = await _prepareLines(
        CheckoutInput(lines: lines, accountId: 0, customerId: customerId),
      );
      final totals = computeSaleTotals(
        SaleTotalsInput(
          lineNetTotalsMinor: prepared.map((l) => l.lineNetMinor).toList(),
        ),
      );
      return totals.grandTotalMinor;
    });
  }

  Future<CheckoutOutput> checkout(CheckoutInput input) {
    return _db.transaction(() async {
      if (input.lines.isEmpty) {
        throw ArgumentError('Nota tanpa item');
      }

      final business = await (_db.select(_db.businesses)..limit(1)).getSingle();

      final prepared = await _prepareLines(input);

      // ---- Totals (central policy D-011).
      final totals = computeSaleTotals(
        SaleTotalsInput(
          lineNetTotalsMinor: prepared.map((l) => l.lineNetMinor).toList(),
          orderDiscountLevel1PercentBp: input.orderDiscountLevel1PercentBp,
          orderDiscountLevel2PercentBp: input.orderDiscountLevel2PercentBp,
          orderDiscountFixedMinor: input.orderDiscountFixedMinor,
          serviceChargeBp: input.serviceChargeBp,
          taxRateBp: input.taxRateBp,
          shippingFeeMinor: input.shippingFeeMinor,
          denomination: input.denomination,
        ),
      );

      // ---- Payment split -> status (D-009).
      if (input.paidNowMinor < 0 ||
          input.paidNowMinor > totals.grandTotalMinor) {
        throw const Failure(
          code: ErrorCodes.invalidPayment,
          message: 'Jumlah pembayaran tidak valid.',
        );
      }
      final paid = input.paidNowMinor;
      final due = totals.grandTotalMinor - paid;
      if (due > 0 && input.customerId == null) {
        throw const Failure(
          code: ErrorCodes.customerRequiredForCredit,
          message: 'Pelanggan wajib dipilih untuk pembayaran tertunda.',
        );
      }
      var status = 'paid';
      if (due > 0) {
        status = paid > 0 ? 'partially_paid' : 'credit';
      }

      // ---- Number + sale header.
      final nextSeq = business.invoiceSequence + 1;
      final number =
          '${business.invoicePrefix}${nextSeq.toString().padLeft(5, '0')}';

      final saleId = await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
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
            ),
          );

      await (_db.update(_db.businesses)..where((t) => t.id.equals(business.id)))
          .write(BusinessesCompanion(invoiceSequence: Value(nextSeq)));

      // ---- Lines with full transaction-time snapshot (#7).
      for (final l in prepared) {
        await _db
            .into(_db.saleLines)
            .insert(
              SaleLinesCompanion.insert(
                saleId: saleId,
                productId: Value(l.productId),
                variantId: Value(l.variantId),
                productNameSnapshot: l.productNameSnapshot,
                skuSnapshot: Value(l.skuSnapshot),
                unitNameSnapshot: l.unitNameSnapshot,
                unitId: Value(l.unitId),
                qtyMicro: l.qtyMicro,
                conversionFactorMicro: l.conversionFactorMicro,
                qtyBaseMicro: l.qtyBaseMicro,
                unitPriceMinor: l.unitPriceMinor,
                discountAmountMinor: Value(l.discountMinor),
                costPriceSnapshotMinor: Value(l.costSnapshotMinor),
                lineTotalMinor: l.lineNetMinor,
              ),
            );
      }

      // ---- Stock movements + cached balance sync (D-014).
      for (final l in prepared) {
        if (!l.tracked || l.qtyBaseMicro == 0) continue;
        await _db
            .into(_db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                businessId: business.id,
                productId: l.productId,
                variantId: Value(l.variantId),
                movementType: 'sale_out',
                qtyBaseMicro: -l.qtyBaseMicro,
                unitCostMinor: Value(l.costSnapshotMinor),
                referenceNumber: Value(number),
              ),
            );
        if (l.variantId != null) {
          final variant = await (_db.select(
            _db.productVariants,
          )..where((t) => t.id.equals(l.variantId!))).getSingle();
          await (_db.update(
            _db.productVariants,
          )..where((t) => t.id.equals(variant.id))).write(
            ProductVariantsCompanion(
              stockQuantityMicro: Value(
                variant.stockQuantityMicro - l.qtyBaseMicro,
              ),
            ),
          );
        } else {
          final fresh = await (_db.select(
            _db.products,
          )..where((t) => t.id.equals(l.productId))).getSingle();
          await (_db.update(
            _db.products,
          )..where((t) => t.id.equals(l.productId))).write(
            ProductsCompanion(
              stockQuantityMicro: Value(
                fresh.stockQuantityMicro - l.qtyBaseMicro,
              ),
            ),
          );
        }
      }

      // ---- Payment + ledger (FR-CASH-001).
      if (paid > 0) {
        final paymentId = await _db
            .into(_db.payments)
            .insert(
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
        await _db
            .into(_db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                accountId: Value(input.accountId),
                sourceType: 'payment',
                sourceId: Value('$paymentId'),
                entryType: 'debit',
                amountMinor: paid,
                note: Value('Pembayaran $number'),
              ),
            );
        final acc = await (_db.select(
          _db.accounts,
        )..where((t) => t.id.equals(input.accountId))).getSingle();
        await (_db.update(
          _db.accounts,
        )..where((t) => t.id.equals(input.accountId))).write(
          AccountsCompanion(
            currentBalanceMinor: Value(acc.currentBalanceMinor + paid),
          ),
        );
      }

      // ---- Receivable (FR-AR-001).
      if (due > 0 && input.customerId != null) {
        await _db
            .into(_db.receivables)
            .insert(
              ReceivablesCompanion.insert(
                businessId: business.id,
                saleId: saleId,
                customerId: input.customerId!,
                originalAmountMinor: due,
                remainingAmountMinor: due,
                dueDate: DateTime.now().toUtc().add(const Duration(days: 7)),
              ),
            );
      }

      // ---- Audit (FR-AUDIT-001).
      await _db
          .into(_db.activityLogs)
          .insert(
            ActivityLogsCompanion.insert(
              businessId: business.id,
              actorType: 'owner',
              action: 'sale.created',
              entityType: 'sale',
              entityId: Value('$saleId'),
              afterJson: Value(
                '{"number":"$number","total":${totals.grandTotalMinor}}',
              ),
            ),
          );

      return CheckoutOutput(
        saleId: saleId,
        number: number,
        grandTotalMinor: totals.grandTotalMinor,
        dueTotalMinor: due,
      );
    });
  }

  /// Voids a finalized sale only when it has no financial side effects.
  ///
  /// Refund and receivable reversal documents are not implemented yet, so
  /// refusing such a void is safer than leaving cash or AR inconsistent.
  Future<void> voidSale(int saleId, String reason) {
    return _db.transaction(() async {
      final sale = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(saleId))).getSingle();
      if (sale.status == 'voided') return;
      final payments = await (_db.select(
        _db.payments,
      )..where((t) => t.saleId.equals(saleId))).get();
      final receivables = await (_db.select(
        _db.receivables,
      )..where((t) => t.saleId.equals(saleId))).get();
      if (payments.isNotEmpty || receivables.isNotEmpty) {
        throw const Failure(
          code: ErrorCodes.saleCannotVoid,
          message:
              'Nota dengan pembayaran atau piutang belum dapat dibatalkan.',
        );
      }

      final lines = await (_db.select(
        _db.saleLines,
      )..where((t) => t.saleId.equals(saleId))).get();

      for (final l in lines) {
        final pid = l.productId;
        if (pid == null) continue;
        final p = await (_db.select(
          _db.products,
        )..where((t) => t.id.equals(pid))).getSingle();
        if (!p.trackStock || p.type != 'goods') continue;
        final variant = l.variantId == null
            ? null
            : await (_db.select(_db.productVariants)..where(
                    (t) => t.id.equals(l.variantId!) & t.productId.equals(pid),
                  ))
                  .getSingleOrNull();
        if (l.variantId != null && variant == null) {
          throw const Failure(
            code: ErrorCodes.productNotFound,
            message: 'Varian produk tidak ditemukan.',
          );
        }
        await _db
            .into(_db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                businessId: p.businessId,
                productId: pid,
                variantId: Value(l.variantId),
                movementType: 'adjustment_in',
                qtyBaseMicro: l.qtyBaseMicro,
                unitCostMinor: Value(l.costPriceSnapshotMinor),
                referenceNumber: Value('VOID-${sale.number ?? saleId}'),
                note: Value('Void nota: $reason'),
              ),
            );
        if (variant != null) {
          await (_db.update(
            _db.productVariants,
          )..where((t) => t.id.equals(variant.id))).write(
            ProductVariantsCompanion(
              stockQuantityMicro: Value(
                variant.stockQuantityMicro + l.qtyBaseMicro,
              ),
            ),
          );
        } else {
          await (_db.update(
            _db.products,
          )..where((t) => t.id.equals(pid))).write(
            ProductsCompanion(
              stockQuantityMicro: Value(p.stockQuantityMicro + l.qtyBaseMicro),
            ),
          );
        }
      }

      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(
          status: const Value('voided'),
          voidedAt: Value(DateTime.now().toUtc()),
          note: Value(
            sale.note == null
                ? 'Void: $reason'
                : '${sale.note} | Void: $reason',
          ),
        ),
      );

      await _db
          .into(_db.activityLogs)
          .insert(
            ActivityLogsCompanion.insert(
              businessId: sale.businessId,
              actorType: 'owner',
              action: 'sale.voided',
              entityType: 'sale',
              entityId: Value('$saleId'),
              afterJson: Value('{"reason":"$reason"}'),
            ),
          );
    });
  }
}
