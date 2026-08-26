import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/customers/data/party_repositories.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';

void main() {
  late AppDatabase db;
  late int businessId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db.into(db.owners).insert(
          OwnersCompanion.insert(name: 'Owner'),
        );
    businessId = await db.into(db.businesses).insert(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Uji'),
        );
  });

  tearDown(() async => db.close());

  group('ReferenceRepository', () {
    test('ensureDefaults seeds units/tiers/types once', () async {
      final refs = ReferenceRepository(db);
      await refs.ensureDefaults(businessId);
      await refs.ensureDefaults(businessId); // idempotent

      final units = await refs.units(businessId);
      expect(units.map((u) => u.code), containsAll(['pcs', 'dus']));
      expect(units.where((u) => u.code == 'pcs'), hasLength(1));

      final tiers = await refs.priceTiers(businessId);
      expect(tiers.map((t) => t.name), containsAll(['Retail', 'Grosir']));

      final types = await refs.customerTypes(businessId);
      expect(types.map((t) => t.name), contains('Umum'));
    });

    test('addCategory + rename + deactivate', () async {
      final refs = ReferenceRepository(db);
      final id = await refs.addCategory(businessId: businessId, name: 'Minuman');
      await refs.renameCategory(id, 'Minuman Kemasan');
      await refs.setCategoryActive(id, false);

      final cats = await refs.categories(businessId);
      expect(cats.single.name, 'Minuman Kemasan');
      expect(cats.single.isActive, isFalse);
    });
  });

  group('ProductRepository', () {
    late ReferenceRepository refs;
    late ProductRepository products;
    late int pcsUnitId;
    late int dusUnitId;
    late int retailTierId;

    setUp(() async {
      refs = ReferenceRepository(db);
      products = ProductRepository(db);
      await refs.ensureDefaults(businessId);
      pcsUnitId = (await refs.unitByCode(businessId, 'pcs'))!.id;
      dusUnitId = (await refs.unitByCode(businessId, 'dus'))!.id;
      retailTierId =
          (await refs.priceTiers(businessId)).firstWhere((t) => t.name == 'Retail').id;
    });

    ProductDraft draft({
      String name = 'Kopi Arabica',
      String? sku = 'KPI-001',
    }) =>
        ProductDraft(
          businessId: businessId,
          name: name,
          sku: sku,
          baseUnitId: pcsUnitId,
          costPriceMinor: 8000,
          salePriceMinor: 12000,
          wholesalePriceMinor: 10500,
          minStockMicro: 5000000, // 5 pcs
          units: [ProductUnitInput(unitId: dusUnitId, conversionToBase: '24')],
          variants: [
            VariantInput(name: '200g', salePriceMinor: 12000),
            VariantInput(name: '500g', salePriceMinor: 25000),
          ],
          tierPrices: [TierPriceInput(tierId: retailTierId, priceMinor: 11500)],
        );

    test('createProduct writes full aggregate; detail loads it back',
        () async {
      final id = await products.createProduct(draft());

      final detail = (await products.detail(id))!;
      expect(detail.product.salePriceMinor, 12000);
      expect(detail.variants, hasLength(2));
      expect(detail.units, hasLength(1));
      expect(detail.units.single.unitCode, 'dus');
      expect(detail.units.single.entry.conversionToBaseMicro, 24000000);
    });

    test('search matches name/sku and applies filters', () async {
      await products.createProduct(draft());
      await products.createProduct(
        draft(name: 'Gula Pasir', sku: 'GLP-001'),
      );
      // Out-of-stock candidate (cache starts at 0).
      await products.createProduct(draft(name: 'Teh Celup', sku: 'TEH-001'));

      expect((await products.search(businessId: businessId)), hasLength(3));
      expect(
        (await products.search(businessId: businessId, query: 'kopi')),
        hasLength(1),
      );
      expect(
        (await products.search(
          businessId: businessId,
          query: 'GLP',
        )).single.name,
        'Gula Pasir',
      );
      expect(
        (await products.search(
          businessId: businessId,
          filter: ProductFilter.outOfStock,
        )),
        hasLength(3), // all start with zero cached stock
      );
    });

    test('updateProduct replaces children without orphaning', () async {
      final id = await products.createProduct(draft());

      final d = ProductDraft(
        businessId: businessId,
        name: 'Kopi Arabica Update',
        baseUnitId: pcsUnitId,
        salePriceMinor: 13000,
        units: [], // conversions removed
        variants: [VariantInput(name: '1kg', salePriceMinor: 40000)],
        tierPrices: [],
      );
      await products.updateProduct(id, d);

      final detail = (await products.detail(id))!;
      expect(detail.product.name, 'Kopi Arabica Update');
      expect(detail.product.salePriceMinor, 13000);
      expect(detail.variants.single.name, '1kg');
      expect(detail.units, isEmpty);

      // Old variant rows must be gone.
      final variantCount = await (db.select(db.productVariants)
            ..where((t) => t.productId.equals(id)))
          .get();
      expect(variantCount, hasLength(1));
    });

    test('archive/restore toggles active flag', () async {
      final id = await products.createProduct(draft());
      await products.setActive(id, false);
      expect((await products.byId(id))!.isActive, isFalse);

      final inactive = await products.search(
        businessId: businessId,
        filter: ProductFilter.inactive,
      );
      expect(inactive, hasLength(1));

      await products.setActive(id, true);
      expect((await products.byId(id))!.isActive, isTrue);
    });
  });

  group('Party repositories', () {
    test('customer create/search/update/deactivate', () async {
      final repo = CustomerRepository(db);
      final id = await repo.create(businessId: businessId, name: 'Ibu Sari');
      await repo.create(businessId: businessId, name: 'Bapak Dedi');

      expect(
        (await repo.search(businessId: businessId, query: 'sari')).single.id,
        id,
      );

      await repo.update(
        id,
        CustomersCompanion.insert(
          businessId: businessId,
          name: 'Ibu Sari Wulandari',
          phone: const Value('0812'),
        ),
      );
      expect((await repo.byId(id))!.phone, '0812');

      await repo.setActive(id, false);
      expect(await repo.search(businessId: businessId), hasLength(1));
      expect(
        (await repo.search(businessId: businessId, activeOnly: false)),
        hasLength(2),
      );
    });

    test('supplier create/rename/list', () async {
      final repo = SupplierRepository(db);
      await repo.create(businessId: businessId, name: 'CV Sumber Kopi');
      await repo.create(businessId: businessId, name: 'PT Gula Jaya');

      final all = await repo.list(businessId: businessId);
      expect(all, hasLength(2));
      await repo.rename(all.first.id, 'CV Sumber Kopi Utama');
      expect((await repo.list(businessId: businessId)).first.name,
          'CV Sumber Kopi Utama');
    });

    test('salesman create requires unique code per business', () async {
      final repo = SalesmanRepository(db);
      await repo.create(businessId: businessId, code: 'SL-01', name: 'Rian');

      expect(
        () => repo.create(businessId: businessId, code: 'SL-01', name: 'Dup'),
        throwsA(anything),
      );

      final list = await repo.list(businessId: businessId);
      expect(list.single.name, 'Rian');
    });
  });
}
