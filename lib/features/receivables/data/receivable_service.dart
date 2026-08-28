import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import '../../../database/app_database.dart';
import '../../finance/data/finance_result.dart';

/// Receivable settlement (FR-AR-001, amendment #14).
class ReceivableService {
  ReceivableService(this._db);

  final AppDatabase _db;

  /// Lists receivables joined with customer name, earliest due first.
  Future<List<ReceivableWithCustomer>> list(int businessId) async {
    final rows =
        await (_db.select(_db.receivables).join([
                innerJoin(
                  _db.customers,
                  _db.customers.id.equalsExp(_db.receivables.customerId),
                ),
              ])
              ..where(_db.receivables.businessId.equals(businessId))
              ..orderBy([OrderingTerm.asc(_db.receivables.dueDate)]))
            .get();
    return rows
        .map(
          (r) => (
            receivable: r.readTable(_db.receivables),
            customerName: r.readTable(_db.customers).name,
          ),
        )
        .toList();
  }

  /// Records a payment against [receivableId], atomically:
  /// Payment(receivable_settlement) + junction + receivable update +
  /// ledger debit + account balance.
  Future<FinanceResult> recordPayment({
    required int receivableId,
    required int accountId,
    required int amountMinor,
    String method = 'cash',
    String? note,
  }) async {
    if (amountMinor <= 0) {
      return const FinanceResult.failure(
        Failure(code: ErrorCodes.invalidPayment, message: 'Nominal harus > 0'),
      );
    }

    return _db
        .transaction(() async {
          final r = await (_db.select(
            _db.receivables,
          )..where((t) => t.id.equals(receivableId))).getSingle();

          if (r.remainingAmountMinor <= 0) {
            return const FinanceResult.failure(
              Failure(
                code: ErrorCodes.invalidPayment,
                message: 'Piutang sudah lunas.',
              ),
            );
          }
          if (amountMinor > r.remainingAmountMinor) {
            return FinanceResult.failure(
              Failure(
                code: ErrorCodes.invalidPayment,
                message: 'Melebihi sisa piutang (${r.remainingAmountMinor}).',
              ),
            );
          }

          // Payment row referencing the original sale (#14 traceability).
          final paymentId = await _db
              .into(_db.payments)
              .insert(
                PaymentsCompanion.insert(
                  businessId: r.businessId,
                  direction: 'in',
                  purpose: 'receivable_settlement',
                  accountId: Value(accountId),
                  amountMinor: amountMinor,
                  method: Value(method),
                  saleId: Value(r.saleId),
                  note: Value(note),
                ),
              );

          // Allocation junction.
          await _db
              .into(_db.receivablePayments)
              .insert(
                ReceivablePaymentsCompanion.insert(
                  receivableId: receivableId,
                  paymentId: paymentId,
                  amountAppliedMinor: amountMinor,
                ),
              );

          // Receivable state.
          final newPaid = r.paidAmountMinor + amountMinor;
          final newRemaining = r.remainingAmountMinor - amountMinor;
          final fullyPaid = newRemaining <= 0;
          await (_db.update(
            _db.receivables,
          )..where((t) => t.id.equals(receivableId))).write(
            ReceivablesCompanion(
              paidAmountMinor: Value(newPaid),
              remainingAmountMinor: Value(newRemaining),
              status: Value(fullyPaid ? 'paid' : 'partial'),
              closedAt: fullyPaid
                  ? Value(DateTime.now().toUtc())
                  : const Value(null),
            ),
          );

          // Ledger debit (money in) + account balance cache.
          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  accountId: Value(accountId),
                  sourceType: 'payment',
                  sourceId: Value('$paymentId'),
                  entryType: 'debit',
                  amountMinor: amountMinor,
                  note: Value('Pelunasan piutang'),
                ),
              );
          final acc = await (_db.select(
            _db.accounts,
          )..where((t) => t.id.equals(accountId))).getSingle();
          await (_db.update(
            _db.accounts,
          )..where((t) => t.id.equals(accountId))).write(
            AccountsCompanion(
              currentBalanceMinor: Value(acc.currentBalanceMinor + amountMinor),
            ),
          );

          // Audit.
          await _db
              .into(_db.activityLogs)
              .insert(
                ActivityLogsCompanion.insert(
                  businessId: r.businessId,
                  actorType: 'owner',
                  action: 'receivable.paid',
                  entityType: 'receivable',
                  entityId: Value('$receivableId'),
                  afterJson: Value('{"amount":$amountMinor}'),
                ),
              );

          return const FinanceResult.success();
        })
        .catchError((Object e) {
          return FinanceResult.failure(
            Failure(code: ErrorCodes.databaseError, message: e.toString()),
          );
        });
  }
}

typedef ReceivableWithCustomer = ({Receivable receivable, String customerName});
