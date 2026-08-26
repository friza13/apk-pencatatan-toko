import 'package:drift/drift.dart';

import '../../../../database/app_database.dart';
import '../../inventory/data/inventory_service.dart';

/// Seeds contoh data untuk mode demo onboarding (DESAIN §39).
/// Dapat dihapus user lewat pengaturan nanti (MVP: manual via UI produk).
class DemoDataSeeder {
  DemoDataSeeder(this._db);

  final AppDatabase _db;

  Future<void> seed(int businessId) async {
    final existing =
        await (_db.select(_db.products)..limit(1)).get();
    if (existing.isNotEmpty) return; // jangan dobel jika sudah ada data

    final unit = await (_db.select(_db.units)
          ..where((t) => t.code.equals('pcs')))
        .getSingleOrNull();
    if (unit == null) return;

    Future<int> product(String name, int cost, int price, int stock,
            {String? sku}) async {
      final id = await _db.into(_db.products).insert(ProductsCompanion.insert(
            businessId: businessId,
            name: name,
            sku: Value(sku),
            baseUnitId: unit.id,
            costPriceMinor: Value(cost),
            salePriceMinor: Value(price),
            minStockMicro: const Value(5000000),
          ));
      if (stock > 0) {
        await InventoryService(_db).setOpeningBalance(id, stock * 1000000);
      }
      return id;
    }

    await product('Kopi Arabica 200g', 18000, 28000, 24, sku: 'KPI-001');
    await product('Gula Pasir 1kg', 13000, 17000, 30, sku: 'GLA-001');
    await product('Susu UHT 1L', 15500, 21000, 12, sku: 'SUU-001');
    await product('Keripik Kentang', 8500, 13000, 40, sku: 'KRK-001');
    await product('Air Mineral 600ml', 2500, 4000, 60, sku: 'AMR-001');

    await _db.into(_db.customers).insert(CustomersCompanion.insert(
          businessId: businessId,
          name: 'Ibu Sari',
          phone: const Value('081234567890'),
        ));
    await _db.into(_db.customers).insert(CustomersCompanion.insert(
          businessId: businessId,
          name: 'Warung Bu Yati',
          phone: const Value('089876543210'),
        ));

    await _db.into(_db.suppliers).insert(SuppliersCompanion.insert(
          businessId: businessId,
          name: 'CV Sumber Kopi Nusantara',
        ));
  }
}
