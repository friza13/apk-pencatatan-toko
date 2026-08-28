import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/customers/data/party_repositories.dart';
import 'package:notakit/features/finance/data/finance_service.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/receivables/data/receivable_service.dart';
import 'package:notakit/features/sales/data/sales_service.dart';

void main() {
  late AppDatabase db;
  late SalesService sales;
  late FinanceService finance;
  late ReceivableService receivables;
  late int businessId;
  late int kasId;
  late int bankId;
  late int customerId;
  late int jasaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sales = SalesService(db);
    finance = FinanceService(db);
    receivables = ReceivableService(db);

    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'));

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    final pcs = (await refs.unitByCode(businessId, 'pcs'))!.id;

    kasId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(businessId: businessId, name: 'Kas'));
    bankId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            businessId: businessId,
            name: 'Bank',
            type: const Value('bank'),
          ),
        );

    final custRepo = CustomerRepository(db);
    customerId = await custRepo.create(
      businessId: businessId,
      name: 'Ibu Sari',
    );

    jasaId = await ProductRepository(db).createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Jasa Kirim',
        type: 'service',
        trackStock: false,
        baseUnitId: pcs,
        salePriceMinor: 5000,
      ),
    );
  });

  tearDown(() async => db.close());

  /// Creates one full-credit sale worth [grandMinor] and returns its
  /// receivable id.
  Future<int> makeReceivable(int grandMinor) async {
    final qtyUnits = grandMinor ~/ 5000;
    await sales.checkout(
      CheckoutInput(
        lines: [
          SaleLineInput(
            productId: jasaId,
            qtyMicro: qtyUnits * 1000000,
            unitPriceMinor: 5000,
          ),
        ],
        accountId: kasId,
        customerId: customerId,
      ),
    );
    final r = await (db.select(db.receivables)).getSingle();
    return r.id;
  }

  Future<int> balanceOf(int accountId) async => (await (db.select(
    db.accounts,
  )..where((t) => t.id.equals(accountId))).getSingle()).currentBalanceMinor;

  group('ReceivableService', () {
    test('partial payment -> partial; full second payment closes', () async {
      final rid = await makeReceivable(20000);

      final first = await receivables.recordPayment(
        receivableId: rid,
        accountId: kasId,
        amountMinor: 15000,
      );
      expect(first.isSuccess, isTrue);

      var row = (await db.select(db.receivables).get()).single;
      expect(row.status, 'partial');
      expect(row.remainingAmountMinor, 5000);
      expect(row.closedAt, isNull);

      final second = await receivables.recordPayment(
        receivableId: rid,
        accountId: kasId,
        amountMinor: 5000,
      );
      expect(second.isSuccess, isTrue);

      row = (await db.select(db.receivables).get()).single;
      expect(row.status, 'paid');
      expect(row.remainingAmountMinor, 0);
      expect(row.closedAt, isNotNull);
    });

    test('overpay/zero/already-paid rejected', () async {
      final rid = await makeReceivable(20000);

      expect(
        (await receivables.recordPayment(
          receivableId: rid,
          accountId: kasId,
          amountMinor: 25000,
        )).failure?.code,
        ErrorCodes.invalidPayment,
      );
      expect(
        (await receivables.recordPayment(
          receivableId: rid,
          accountId: kasId,
          amountMinor: 0,
        )).failure?.code,
        ErrorCodes.invalidPayment,
      );

      await receivables.recordPayment(
        receivableId: rid,
        accountId: kasId,
        amountMinor: 20000,
      );
      expect(
        (await receivables.recordPayment(
          receivableId: rid,
          accountId: kasId,
          amountMinor: 1000,
        )).failure?.code,
        ErrorCodes.invalidPayment,
      );
    });

    test(
      'payment writes ledger debit + kas balance + junction + audit',
      () async {
        final rid = await makeReceivable(20000);
        final before = await balanceOf(kasId);

        await receivables.recordPayment(
          receivableId: rid,
          accountId: kasId,
          amountMinor: 8000,
        );
        expect(await balanceOf(kasId), before + 8000);

        final junction = await db.select(db.receivablePayments).get();
        expect(junction.single.amountAppliedMinor, 8000);

        final ledger = await db.select(db.ledgerEntries).get();
        expect(ledger.last.entryType, 'debit');

        final logs = await (db.select(
          db.activityLogs,
        )..where((t) => t.action.equals('receivable.paid'))).get();
        expect(logs, hasLength(1));
      },
    );

    test('list joins customer name', () async {
      await makeReceivable(12000);
      final list = await receivables.list(businessId);
      expect(list.single.customerName, 'Ibu Sari');
    });
  });

  group('FinanceService', () {
    test('expense: out-payment + credit ledger + balance down', () async {
      final before = await balanceOf(kasId);
      final r = await finance.recordManual(
        businessId: businessId,
        accountId: kasId,
        isIncome: false,
        amountMinor: 15000,
        category: 'Listrik',
        note: 'Token',
      );
      expect(r.isSuccess, isTrue);
      expect(await balanceOf(kasId), before - 15000);

      final p = await db.select(db.payments).get();
      expect(p.last.direction, 'out');
      expect(p.last.purpose, 'other_expense');
      expect(p.last.category, 'Listrik');
    });

    test('income increases balance', () async {
      final before = await balanceOf(bankId);
      await finance.recordManual(
        businessId: businessId,
        accountId: bankId,
        isIncome: true,
        amountMinor: 100000,
        category: 'Bunga',
      );
      expect(await balanceOf(bankId), before + 100000);
    });

    test('transfer moves both balances + paired ledger entries', () async {
      final kasBefore = await balanceOf(kasId);
      final bankBefore = await balanceOf(bankId);

      final r = await finance.transfer(
        fromAccountId: kasId,
        toAccountId: bankId,
        amountMinor: 25000,
      );
      expect(r.isSuccess, isTrue);
      expect(await balanceOf(kasId), kasBefore - 25000);
      expect(await balanceOf(bankId), bankBefore + 25000);

      final ledger = await db.select(db.ledgerEntries).get();
      final pair = ledger.where((l) => l.sourceType == 'transfer').toList();
      expect(pair.map((e) => e.entryType), containsAll(['debit', 'credit']));

      final paymentsRows = await db.select(db.payments).get();
      final transferRow = paymentsRows.lastWhere(
        (p) => p.purpose == 'transfer',
      );
      expect(transferRow.counterAccountId, bankId);
    });

    test('same-account transfer rejected', () async {
      expect(
        (await finance.transfer(
          fromAccountId: kasId,
          toAccountId: kasId,
          amountMinor: 1000,
        )).failure?.code,
        ErrorCodes.invalidPayment,
      );
    });
  });

  test('inventory service still usable alongside (sanity)', () async {
    final inv = InventoryService(db);
    expect(inv, isNotNull);
  });
}
