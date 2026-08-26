import 'package:drift/drift.dart';

import '../../../database/app_database.dart';

/// Categories, units, price tiers, customer types (FR sections C/G).
class ReferenceRepository {
  ReferenceRepository(this._db);

  final AppDatabase _db;

  // ---------- Categories ----------

  Future<List<Category>> categories(int businessId) => (_db.select(
        _db.categories,
      )
        ..where((t) => t.businessId.equals(businessId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<int> addCategory({
    required int businessId,
    required String name,
    int? parentId,
    int sortOrder = 0,
  }) =>
      _db.into(_db.categories).insert(CategoriesCompanion.insert(
            businessId: businessId,
            name: name,
            parentId: Value(parentId),
            sortOrder: Value(sortOrder),
          ));

  Future<void> renameCategory(int id, String name) =>
      (_db.update(_db.categories)..where((t) => t.id.equals(id)))
          .write(CategoriesCompanion(name: Value(name)));

  Future<void> setCategoryActive(int id, bool active) =>
      (_db.update(_db.categories)..where((t) => t.id.equals(id)))
          .write(CategoriesCompanion(isActive: Value(active)));

  // ---------- Units ----------

  Future<List<Unit>> units(int businessId) => (_db.select(_db.units)
        ..where((t) => t.businessId.equals(businessId))
        ..orderBy([(t) => OrderingTerm.asc(t.code)]))
      .get();

  Future<Unit?> unitByCode(int businessId, String code) =>
      (_db.select(_db.units)
            ..where((t) => t.businessId.equals(businessId) &
                t.code.equals(code)))
          .getSingleOrNull();

  Future<int> addUnit({
    required int businessId,
    required String code,
    required String name,
    String? symbol,
    int decimalScale = 0,
  }) =>
      _db.into(_db.units).insert(UnitsCompanion.insert(
            businessId: businessId,
            code: code,
            name: name,
            symbol: Value(symbol),
            decimalScale: Value(decimalScale),
          ));

  // ---------- Price tiers ----------

  Future<List<PriceTier>> priceTiers(int businessId) => (_db.select(
        _db.priceTiers,
      )..where((t) => t.businessId.equals(businessId))).get();

  Future<int> addPriceTier({
    required int businessId,
    required String name,
    required int priority,
  }) =>
      _db.into(_db.priceTiers).insert(PriceTiersCompanion.insert(
            businessId: businessId,
            name: name,
            priority: Value(priority),
          ));

  // ---------- Customer types ----------

  Future<List<CustomerType>> customerTypes(int businessId) =>
      (_db.select(_db.customerTypes)
            ..where((t) => t.businessId.equals(businessId)))
          .get();

  Future<int> addCustomerType({
    required int businessId,
    required String name,
    int? defaultPaymentTermDays,
  }) =>
      _db.into(_db.customerTypes).insert(CustomerTypesCompanion.insert(
            businessId: businessId,
            name: name,
            defaultPaymentTermDays:
                Value(defaultPaymentTermDays ?? 0),
          ));

  /// Seeds sensible starter data for a brand-new business. Safe to call
  /// repeatedly — existing codes/names are skipped.
  Future<void> ensureDefaults(int businessId) async {
    if (await unitByCode(businessId, 'pcs') == null) {
      await addUnit(
        businessId: businessId,
        code: 'pcs',
        name: 'Pieces',
        symbol: 'pcs',
      );
    }
    if (await unitByCode(businessId, 'dus') == null) {
      await addUnit(
        businessId: businessId,
        code: 'dus',
        name: 'Dus',
        symbol: 'dus',
      );
    }

    final tiers = await priceTiers(businessId);
    if (!tiers.any((t) => t.name == 'Retail')) {
      await addPriceTier(businessId: businessId, name: 'Retail', priority: 10);
    }
    if (!tiers.any((t) => t.name == 'Grosir')) {
      await addPriceTier(businessId: businessId, name: 'Grosir', priority: 20);
    }

    final types = await customerTypes(businessId);
    if (!types.any((t) => t.name == 'Umum')) {
      await addCustomerType(businessId: businessId, name: 'Umum');
    }
  }
}
