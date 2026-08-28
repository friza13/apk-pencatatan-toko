import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../data/finance_service.dart';
import '../../receivables/data/receivable_service.dart';

final FutureProvider<FinanceService> financeServiceProvider =
    FutureProvider<FinanceService>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      return FinanceService(db);
    });

final FutureProvider<ReceivableService> receivableServiceProvider =
    FutureProvider<ReceivableService>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      return ReceivableService(db);
    });

/// Account list for pickers/cards.
final StreamProvider<List<Account>> accountsStreamProvider =
    StreamProvider<List<Account>>((ref) async* {
      final business = await ref.watch(currentBusinessProvider.future);
      final db = await ref.watch(appDatabaseProvider.future);
      yield* (db.select(db.accounts)
            ..where((t) => t.businessId.equals(business.id))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();
    });

/// Cash-flow timeline (newest first).
final StreamProvider<List<LedgerEntry>> cashFlowStreamProvider =
    StreamProvider<List<LedgerEntry>>((ref) async* {
      final business = await ref.watch(currentBusinessProvider.future);
      final db = await ref.watch(appDatabaseProvider.future);
      final accountIds = await (db.select(
        db.accounts,
      )..where((t) => t.businessId.equals(business.id))).map((a) => a.id).get();
      if (accountIds.isEmpty) {
        yield const <LedgerEntry>[];
        return;
      }
      yield* (db.select(db.ledgerEntries)
            ..where((t) => t.accountId.isIn(accountIds))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
            ..limit(100))
          .watch();
    });
