import 'package:drift/drift.dart';

import '../../../database/app_database.dart';

/// Customers (FR section E) with search.
class CustomerRepository {
  CustomerRepository(this._db);

  final AppDatabase _db;

  Future<List<Customer>> search({
    required int businessId,
    String query = '',
    bool activeOnly = true,
  }) async {
    final rows = await (_db.select(_db.customers)
          ..where((t) => t.businessId.equals(businessId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    final q = query.trim().toLowerCase();
    Iterable<Customer> result = rows;
    if (activeOnly) {
      result = result.where((c) => c.isActive);
    }
    if (q.isNotEmpty) {
      result = result.where((c) =>
          c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').contains(q));
    }
    return result.toList();
  }

  Future<Customer?> byId(int id) =>
      (_db.select(_db.customers)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> create({
    required int businessId,
    required String name,
    Value<String> phone = const Value.absent(),
    Value<String> address = const Value.absent(),
    Value<int> customerTypeId = const Value.absent(),
    Value<int> salesmanId = const Value.absent(),
    int creditLimitMinor = 0,
    int paymentTermDays = 0,
    Value<String> notes = const Value.absent(),
  }) =>
      _db.into(_db.customers).insert(CustomersCompanion.insert(
            businessId: businessId,
            name: name,
            phone: phone,
            address: address,
            customerTypeId: customerTypeId,
            salesmanId: salesmanId,
            creditLimitMinor: Value(creditLimitMinor),
            paymentTermDays: Value(paymentTermDays),
            notes: notes,
          ));

  Future<void> update(int id, CustomersCompanion changes) =>
      (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(changes);

  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.customers)..where((t) => t.id.equals(id)))
          .write(CustomersCompanion(isActive: Value(active)));
}

/// Suppliers (FR section F).
class SupplierRepository {
  SupplierRepository(this._db);

  final AppDatabase _db;

  Future<List<Supplier>> list({required int businessId}) =>
      (_db.select(_db.suppliers)
            ..where((t) => t.businessId.equals(businessId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<int> create({
    required int businessId,
    required String name,
    Value<String> phone = const Value.absent(),
    Value<String> address = const Value.absent(),
  }) =>
      _db.into(_db.suppliers).insert(SuppliersCompanion.insert(
            businessId: businessId,
            name: name,
            phone: phone,
            address: address,
          ));

  Future<void> rename(int id, String name) =>
      (_db.update(_db.suppliers)..where((t) => t.id.equals(id)))
          .write(SuppliersCompanion(name: Value(name)));

  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.suppliers)..where((t) => t.id.equals(id)))
          .write(SuppliersCompanion(isActive: Value(active)));
}

/// Salesmen (FR section H).
class SalesmanRepository {
  SalesmanRepository(this._db);

  final AppDatabase _db;

  Future<List<Salesman>> list({required int businessId}) =>
      (_db.select(_db.salesmen)
            ..where((t) => t.businessId.equals(businessId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<int> create({
    required int businessId,
    required String code,
    required String name,
    Value<String> phone = const Value.absent(),
  }) =>
      _db.into(_db.salesmen).insert(SalesmenCompanion.insert(
            businessId: businessId,
            code: code,
            name: name,
            phone: phone,
          ));

  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.salesmen)..where((t) => t.id.equals(id)))
          .write(SalesmenCompanion(isActive: Value(active)));
}
