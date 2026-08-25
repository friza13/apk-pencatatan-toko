import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('host runtime can open the database engine', () async {
    final result =
        await db.customSelect('SELECT sqlite_version() AS v').getSingle();
    // ignore: avoid_print
    print('[P1] host sqlite version = ${result.data['v']}');
  });

  test('schema v1 creates the full production table set', () async {
    await db.customSelect('SELECT 1').getSingle();

    const expectedTables = {
      'owners',
      'businesses',
      'app_settings',
      'activity_logs',
      'app_notifications',
      'backup_records',
      'printer_profiles',
      'categories',
      'units',
      'products',
      'product_variants',
      'product_units',
      'customer_types',
      'customers',
      'salesmen',
      'price_tiers',
      'product_prices',
      'customer_prices',
      'sales',
      'sale_lines',
      'accounts',
      'payments',
      'receivables',
      'receivable_payments',
      'ledger_entries',
      'stock_movements',
      'suppliers',
      'purchases',
      'purchase_lines',
      'sales_returns',
      'sales_return_lines',
      'purchase_returns',
      'purchase_return_lines',
      'marketplace_accounts',
      'marketplace_orders',
      'marketplace_order_lines',
    };

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'drift_%'",
    ).get();

    final names = tables.map((t) => t.data['name'] as String).toSet();
    final missing = expectedTables.difference(names);
    expect(missing, isEmpty, reason: 'missing tables: $missing');
  });

  test('business seed then product requires valid unit (FK)', () async {
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'Owner'),
        );
    final businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Contoh'),
        );
    expect(businessId, greaterThan(0));

    var rejected = false;
    try {
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              businessId: businessId,
              name: 'Orphan',
              baseUnitId: 9999,
            ),
          );
    } catch (e) {
      rejected = e.toString().contains('FOREIGN KEY');
    }
    expect(rejected, isTrue);
  });

  test('payment amount must be positive (CHECK)', () async {
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'O'),
        );
    final businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'B'),
        );
    final accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(businessId: businessId, name: 'Kas'),
        );

    var rejected = false;
    try {
      await db.into(db.payments).insert(
            PaymentsCompanion.insert(
              businessId: businessId,
              direction: 'in',
              purpose: 'sale_payment',
              accountId: Value(accountId),
              amountMinor: 0,
            ),
          );
    } catch (e) {
      rejected = e.toString().contains('CHECK');
    }
    expect(rejected, isTrue);
  });

  test('unit code unique per business', () async {
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'O'),
        );
    final businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'B'),
        );

    await db.into(db.units).insert(
          UnitsCompanion.insert(
            businessId: businessId,
            code: 'pcs',
            name: 'Pieces',
          ),
        );

    var rejected = false;
    try {
      await db.into(db.units).insert(
            UnitsCompanion.insert(
              businessId: businessId,
              code: 'pcs',
              name: 'Pieces 2',
            ),
          );
    } catch (e) {
      rejected = e.toString().contains('UNIQUE');
    }
    expect(rejected, isTrue);
  });

  test('timestamps are stored as UTC epoch millis and read back as UTC',
      () async {
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'O'),
        );
    final id = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'O2'),
        );
    expect(id, greaterThan(ownerId));

    final row = await (db.select(db.owners)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.createdAt.isUtc, isTrue);

    final raw = await db.customSelect(
      'SELECT created_at FROM owners WHERE id = $id',
    ).getSingle();
    expect(raw.data['created_at'], row.createdAt.millisecondsSinceEpoch);
  });

  test('sale status constrained to lifecycle values (D-009)', () async {
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'O'),
        );
    final businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'B'),
        );

    var rejected = false;
    try {
      await db.customStatement(
        'INSERT INTO sales (business_id, status) VALUES ($businessId, '
        "'exploded')",
      );
    } catch (_) {
      rejected = true;
    }
    expect(rejected, isTrue);
  });
}
