import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import '../../../database/app_database.dart';

class SalesReturnLineInput {
  const SalesReturnLineInput({
    required this.saleLineId,
    required this.qtyBaseMicro,
  });

  final int saleLineId;
  final int qtyBaseMicro;
}

class SalesReturnInput {
  const SalesReturnInput({
    required this.saleId,
    required this.lines,
    required this.reason,
    this.refundMethod = 'cash',
  });

  final int saleId;
  final List<SalesReturnLineInput> lines;
  final String reason;
  final String refundMethod;
}

class SalesReturnOutput {
  const SalesReturnOutput({
    required this.returnId,
    required this.number,
    required this.totalMinor,
  });

  final int returnId;
  final String number;
  final int totalMinor;
}

/// Applies a sale return as one atomic reversal transaction.
class SalesReturnService {
  SalesReturnService(this._db);

  final AppDatabase _db;

  Future<SalesReturnOutput> createReturn(SalesReturnInput input) {
    return _db.transaction(() async {
      if (input.lines.isEmpty) {
        throw const Failure(
          code: ErrorCodes.invalidQuantity,
          message: 'Item retur belum dipilih.',
        );
      }

      final sale = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(input.saleId))).getSingle();
      if (sale.status == 'draft' || sale.status == 'voided') {
        throw const Failure(
          code: ErrorCodes.saleCannotReturn,
          message: 'Nota belum dapat diretur.',
        );
      }

      final saleLines = await (_db.select(
        _db.saleLines,
      )..where((t) => t.saleId.equals(input.saleId))).get();
      final byId = {for (final line in saleLines) line.id: line};
      final existing = await (_db.select(_db.salesReturnLines).join([
        innerJoin(
          _db.salesReturns,
          _db.salesReturns.id.equalsExp(_db.salesReturnLines.salesReturnId),
        ),
      ])..where(_db.salesReturns.saleId.equals(input.saleId))).get();
      final returnedByLine = <int, int>{};
      for (final row in existing) {
        final line = row.readTable(_db.salesReturnLines);
        returnedByLine.update(
          line.saleLineId,
          (value) => value + line.qtyBaseMicro,
          ifAbsent: () => line.qtyBaseMicro,
        );
      }

      var total = 0;
      final resolved = <({SaleLine line, int qty, int amount})>[];
      for (final request in input.lines) {
        final line = byId[request.saleLineId];
        if (line == null) {
          throw const Failure(
            code: ErrorCodes.saleCannotReturn,
            message: 'Baris nota tidak ditemukan.',
          );
        }
        if (request.qtyBaseMicro <= 0) {
          throw const Failure(
            code: ErrorCodes.invalidQuantity,
            message: 'Jumlah retur tidak valid.',
          );
        }
        final alreadyReturned = returnedByLine[line.id] ?? 0;
        final available = line.qtyBaseMicro - alreadyReturned;
        if (request.qtyBaseMicro > available) {
          throw const Failure(
            code: ErrorCodes.invalidQuantity,
            message: 'Jumlah retur melebihi jumlah terjual.',
          );
        }
        final amount =
            (line.lineTotalMinor * request.qtyBaseMicro) ~/ line.qtyBaseMicro;
        total += amount;
        resolved.add((line: line, qty: request.qtyBaseMicro, amount: amount));
      }

      final number =
          'RET-${sale.number ?? sale.id}-${DateTime.now().microsecondsSinceEpoch}';
      final returnId = await _db
          .into(_db.salesReturns)
          .insert(
            SalesReturnsCompanion.insert(
              businessId: sale.businessId,
              saleId: sale.id,
              number: number,
              reason: Value(input.reason),
              totalMinor: Value(total),
            ),
          );

      for (final item in resolved) {
        final source = item.line;
        final productId = source.productId;
        if (productId == null) {
          throw const Failure(
            code: ErrorCodes.saleCannotReturn,
            message: 'Produk pada baris nota tidak tersedia.',
          );
        }
        await _db
            .into(_db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                businessId: sale.businessId,
                productId: productId,
                variantId: Value(source.variantId),
                saleId: Value(sale.id),
                movementType: 'sales_return_in',
                qtyBaseMicro: item.qty,
                unitCostMinor: Value(source.costPriceSnapshotMinor),
                referenceNumber: Value(number),
                note: Value('Retur nota ${sale.number ?? sale.id}'),
              ),
            );
        final product = await (_db.select(
          _db.products,
        )..where((t) => t.id.equals(productId))).getSingle();
        await (_db.update(
          _db.products,
        )..where((t) => t.id.equals(product.id))).write(
          ProductsCompanion(
            stockQuantityMicro: Value(product.stockQuantityMicro + item.qty),
          ),
        );
        await _db
            .into(_db.salesReturnLines)
            .insert(
              SalesReturnLinesCompanion.insert(
                salesReturnId: returnId,
                saleLineId: source.id,
                productId: productId,
                variantId: Value(source.variantId),
                qtyBaseMicro: item.qty,
                amountMinor: item.amount,
              ),
            );
      }

      final receivable = await (_db.select(
        _db.receivables,
      )..where((t) => t.saleId.equals(sale.id))).getSingleOrNull();
      final payments =
          await (_db.select(_db.payments)..where(
                (t) =>
                    t.saleId.equals(sale.id) & t.purpose.equals('sale_payment'),
              ))
              .get();
      var receivableReversal = 0;
      if (receivable != null && receivable.remainingAmountMinor > 0) {
        receivableReversal = total < receivable.remainingAmountMinor
            ? total
            : receivable.remainingAmountMinor;
        final remaining = receivable.remainingAmountMinor - receivableReversal;
        await (_db.update(
          _db.receivables,
        )..where((t) => t.id.equals(receivable.id))).write(
          ReceivablesCompanion(
            remainingAmountMinor: Value(remaining),
            status: Value(remaining == 0 ? 'paid' : receivable.status),
            closedAt: remaining == 0
                ? Value(DateTime.now().toUtc())
                : const Value.absent(),
          ),
        );
      }
      final cashRefund = total - receivableReversal;
      if (cashRefund > 0) {
        if (payments.length != 1 || payments.single.accountId == null) {
          throw const Failure(
            code: ErrorCodes.saleCannotReturn,
            message: 'Akun refund sale tidak dapat ditentukan.',
          );
        }
        final original = payments.single;
        final refundId = await _db
            .into(_db.payments)
            .insert(
              PaymentsCompanion.insert(
                businessId: sale.businessId,
                direction: 'out',
                purpose: 'refund',
                accountId: Value(original.accountId),
                amountMinor: cashRefund,
                method: Value(input.refundMethod),
                saleId: Value(sale.id),
                refundOfPaymentId: Value(original.id),
                referenceNumber: Value(number),
                note: Value(input.reason),
              ),
            );
        await (_db.update(_db.salesReturns)
              ..where((t) => t.id.equals(returnId)))
            .write(SalesReturnsCompanion(refundPaymentId: Value(refundId)));
        await _db
            .into(_db.ledgerEntries)
            .insert(
              LedgerEntriesCompanion.insert(
                accountId: Value(original.accountId),
                sourceType: 'payment',
                sourceId: Value('$refundId'),
                entryType: 'credit',
                amountMinor: cashRefund,
                note: Value('Refund $number'),
              ),
            );
        final account = await (_db.select(
          _db.accounts,
        )..where((t) => t.id.equals(original.accountId!))).getSingle();
        await (_db.update(
          _db.accounts,
        )..where((t) => t.id.equals(account.id))).write(
          AccountsCompanion(
            currentBalanceMinor: Value(
              account.currentBalanceMinor - cashRefund,
            ),
          ),
        );
      }

      await _db
          .into(_db.activityLogs)
          .insert(
            ActivityLogsCompanion.insert(
              businessId: sale.businessId,
              actorType: 'owner',
              action: 'sale.returned',
              entityType: 'sales_return',
              entityId: Value('$returnId'),
              afterJson: Value('{"sale_id":${sale.id},"total":$total}'),
            ),
          );
      return SalesReturnOutput(
        returnId: returnId,
        number: number,
        totalMinor: total,
      );
    });
  }
}
