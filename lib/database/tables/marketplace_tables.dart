import 'package:drift/drift.dart';

import 'business_tables.dart';
import 'catalog_tables.dart';
import 'column_mixins.dart';

/// Marketplace integration schema (dormant in MVP — D-016). Tables exist so
/// future adapters have a stable target; no UI or sync ships until Phase 13.

class MarketplaceAccounts extends Table with IdColumn {
  IntColumn get businessId =>
      integer().references(Businesses, #id, onDelete: KeyAction.cascade)();

  /// `tokopedia`, `tiktok`, `shopee`, `notakit_online`.
  TextColumn get provider => text()();

  TextColumn get accountName => text()();

  /// Reference into secure storage — credentials never stored here.
  TextColumn get credentialRef => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get lastSyncAt => integer().nullable()();
}

class MarketplaceOrders extends Table with IdColumn {
  IntColumn get marketplaceAccountId =>
      integer().references(MarketplaceAccounts, #id)();

  TextColumn get externalOrderId => text()();

  TextColumn get externalStatus => text().nullable()();

  IntColumn get orderTime => integer().nullable()();

  TextColumn get customerNameSnapshot => text().nullable()();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  TextColumn get rawPayloadHash => text().nullable()();

  IntColumn get importedAt => integer().nullable()();

  /// Staging status per SRS state machine; posting to local sales happens
  /// only after validation.
  TextColumn get status => text().withDefault(const Constant('imported'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {marketplaceAccountId, externalOrderId},
      ];
}

class MarketplaceOrderLines extends Table with IdColumn {
  IntColumn get marketplaceOrderId =>
      integer().references(MarketplaceOrders, #id)();

  IntColumn get productId =>
      integer().nullable().references(Products, #id)();

  TextColumn get externalSku => text().nullable()();

  TextColumn get productNameSnapshot => text()();

  IntColumn get qtyMicro => integer()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get lineTotalMinor => integer()();
}
