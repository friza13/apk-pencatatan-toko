import 'package:drift/drift.dart';

import '../../../core/error/failures.dart';
import 'finance_result.dart';
import '../../../database/app_database.dart';

/// Cash operations: manual income/expense and inter-account transfers
/// (FR-CASH-001, D-007b generic payment model).
class FinanceService {
  FinanceService(this._db);

  final AppDatabase _db;

  /// Manual income (direction=in) or expense (direction=out).
  Future<FinanceResult> recordManual({
    required int businessId,
    required int accountId,
    required bool isIncome,
    required int amountMinor,
    String? category,
    String? note,
    String method = 'cash',
  }) async {
    if (amountMinor <= 0) {
      return const FinanceResult.failure(
        Failure(code: ErrorCodes.invalidPayment, message: 'Nominal harus > 0'),
      );
    }

    return _db
        .transaction(() async {
          final acc = await (_db.select(
            _db.accounts,
          )..where((t) => t.id.equals(accountId))).getSingle();

          final paymentId = await _db
              .into(_db.payments)
              .insert(
                PaymentsCompanion.insert(
                  businessId: businessId,
                  direction: isIncome ? 'in' : 'out',
                  purpose: isIncome ? 'other_income' : 'other_expense',
                  accountId: Value(accountId),
                  amountMinor: amountMinor,
                  method: Value(method),
                  category: Value(category),
                  note: Value(note),
                ),
              );

          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  accountId: Value(accountId),
                  sourceType: 'payment',
                  sourceId: Value('$paymentId'),
                  entryType: isIncome ? 'debit' : 'credit',
                  amountMinor: amountMinor,
                  note: Value(
                    note ??
                        category ??
                        (isIncome ? 'Pemasukan' : 'Pengeluaran'),
                  ),
                ),
              );

          await (_db.update(
            _db.accounts,
          )..where((t) => t.id.equals(accountId))).write(
            AccountsCompanion(
              currentBalanceMinor: Value(
                acc.currentBalanceMinor +
                    (isIncome ? amountMinor : -amountMinor),
              ),
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

  /// Inter-account transfer: one Payment row with counter account + TWO
  /// paired ledger entries + both balances updated, atomically.
  Future<FinanceResult> transfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      return const FinanceResult.failure(
        Failure(
          code: ErrorCodes.invalidPayment,
          message: 'Akun asal dan tujuan sama.',
        ),
      );
    }
    if (amountMinor <= 0) {
      return const FinanceResult.failure(
        Failure(code: ErrorCodes.invalidPayment, message: 'Nominal harus > 0'),
      );
    }

    return _db
        .transaction(() async {
          final from = await (_db.select(
            _db.accounts,
          )..where((t) => t.id.equals(fromAccountId))).getSingle();
          final to = await (_db.select(
            _db.accounts,
          )..where((t) => t.id.equals(toAccountId))).getSingle();

          final paymentId = await _db
              .into(_db.payments)
              .insert(
                PaymentsCompanion.insert(
                  businessId: from.businessId,
                  direction: 'out',
                  purpose: 'transfer',
                  accountId: Value(fromAccountId),
                  counterAccountId: Value(toAccountId),
                  amountMinor: amountMinor,
                  note: Value(note ?? 'Transfer ke ${to.name}'),
                ),
              );

          // Out of source.
          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  accountId: Value(fromAccountId),
                  sourceType: 'transfer',
                  sourceId: Value('$paymentId'),
                  entryType: 'credit',
                  amountMinor: amountMinor,
                  note: Value('Transfer ke ${to.name}'),
                ),
              );
          await (_db.update(
            _db.accounts,
          )..where((t) => t.id.equals(fromAccountId))).write(
            AccountsCompanion(
              currentBalanceMinor: Value(
                from.currentBalanceMinor - amountMinor,
              ),
            ),
          );

          // Into destination.
          await _db
              .into(_db.ledgerEntries)
              .insert(
                LedgerEntriesCompanion.insert(
                  accountId: Value(toAccountId),
                  sourceType: 'transfer',
                  sourceId: Value('$paymentId'),
                  entryType: 'debit',
                  amountMinor: amountMinor,
                  note: Value('Transfer dari ${from.name}'),
                ),
              );
          await (_db.update(
            _db.accounts,
          )..where((t) => t.id.equals(toAccountId))).write(
            AccountsCompanion(
              currentBalanceMinor: Value(to.currentBalanceMinor + amountMinor),
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

  /// Recent cash-flow timeline across all accounts of the business.
  Future<List<LedgerEntry>> cashFlow(int businessId, {int limit = 100}) async {
    final accountIds = await (_db.select(
      _db.accounts,
    )..where((t) => t.businessId.equals(businessId))).map((a) => a.id).get();
    if (accountIds.isEmpty) return [];
    return (_db.select(_db.ledgerEntries)
          ..where((t) => t.accountId.isIn(accountIds))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
  }
}
