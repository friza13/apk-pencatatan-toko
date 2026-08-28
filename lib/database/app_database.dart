import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../core/time/utc.dart';
import 'tables/column_mixins.dart';
import 'tables/business_tables.dart';
import 'tables/catalog_tables.dart';
import 'tables/crm_pricing_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/marketplace_tables.dart';
import 'tables/payment_tables.dart';
import 'tables/purchase_tables.dart';
import 'tables/sales_tables.dart';

part 'app_database.g.dart';

/// NotaKit production database, schema version 1 (D-003/D-019).
///
/// The database is always opened encrypted through [openAppDatabase];
/// plaintext access is intentionally not exposed.
@DriftDatabase(
  tables: [
    // Business & system
    Owners,
    Businesses,
    AppSettings,
    ActivityLogs,
    AppNotifications,
    BackupRecords,
    PrinterProfiles,
    // Catalog
    Categories,
    Units,
    Products,
    ProductVariants,
    ProductUnits,
    // CRM & pricing
    CustomerTypes,
    Customers,
    Salesmen,
    PriceTiers,
    ProductPrices,
    CustomerPrices,
    // Sales
    Sales,
    SaleLines,
    // Finance & payments
    Accounts,
    Payments,
    Receivables,
    ReceivablePayments,
    LedgerEntries,
    // Inventory
    StockMovements,
    SalesReturns,
    SalesReturnLines,
    PurchaseReturns,
    PurchaseReturnLines,
    // Purchasing
    Suppliers,
    Purchases,
    PurchaseLines,
    // Marketplace (dormant schema — D-016)
    MarketplaceAccounts,
    MarketplaceOrders,
    MarketplaceOrderLines,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

String _escapeSqlString(String value) => value.replaceAll("'", "''");

/// Opens the encrypted NotaKit database.
///
/// Encryption setup order is critical (SPIKE_REPORT §4):
/// key first, then pragmas, then a forced read so a wrong passphrase fails
/// immediately instead of mid-transaction.
QueryExecutor openEncryptedExecutor({
  required File file,
  required String passphrase,
}) {
  if (passphrase.isEmpty) {
    return NativeDatabase.createInBackground(file);
  }
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) => _setupEncrypted(rawDb, passphrase),
  );
}

void _setupEncrypted(sqlite3.Database rawDb, String passphrase) {
  rawDb
    ..execute("PRAGMA key = '${_escapeSqlString(passphrase)}'")
    ..execute('PRAGMA journal_mode = WAL')
    // Forces real I/O: wrong key surfaces here as SQLITE_NOTADB.
    ..execute('SELECT count(*) FROM sqlite_master');
}
