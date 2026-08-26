import 'package:drift/drift.dart';

import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';

/// Product aggregate: product + units(conversion) + variants + prices
/// (FR-PROD-001..003). Stock is never written here — movements own it (D-014).
class ProductRepository {
  ProductRepository(this._db);

  final AppDatabase _db;

  /// Search + filter for the products list (DESAIN §13 filter chips).
  Future<List<Product>> search({
    required int businessId,
    String query = '',
    ProductFilter filter = ProductFilter.all,
  }) async {
    final q = query.trim().toLowerCase();
    final rows = await (_db.select(_db.products)
          ..where((t) => t.businessId.equals(businessId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();

    Iterable<Product> result = rows;
    if (q.isNotEmpty) {
      bool matches(Product p) =>
          p.name.toLowerCase().contains(q) ||
          (p.sku ?? '').toLowerCase().contains(q) ||
          (p.barcode ?? '').contains(q);
      result = result.where(matches);
    }

    bool lowStock(Product p) =>
        p.trackStock &&
        p.stockQuantityMicro > 0 &&
        p.minStockMicro > 0 &&
        p.stockQuantityMicro <= p.minStockMicro;
    bool outOfStock(Product p) => p.trackStock && p.stockQuantityMicro <= 0;

    switch (filter) {
      case ProductFilter.active:
        result = result.where((p) => p.isActive);
      case ProductFilter.inactive:
        result = result.where((p) => !p.isActive);
      case ProductFilter.lowStock:
        result = result.where(lowStock);
      case ProductFilter.outOfStock:
        result = result.where(outOfStock);
      case ProductFilter.all:
        break;
    }
    return result.toList();
  }

  Future<Product?> byId(int id) =>
      (_db.select(_db.products)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Full aggregate load for the detail screen.
  Future<ProductDetail?> detail(int id) async {
    final product = await byId(id);
    if (product == null) {
      return null;
    }
    final variants =
        await (_db.select(_db.productVariants)
              ..where((t) => t.productId.equals(id)))
            .get();
    final unitRows = await (_db.select(_db.productUnits).join([
      innerJoin(_db.units, _db.units.id.equalsExp(_db.productUnits.unitId)),
    ])
          ..where(_db.productUnits.productId.equals(id)))
        .get()
        .then(
      (rows) => rows
          .map((r) => (
                entry: r.readTable(_db.productUnits),
                unitName: r.readTable(_db.units).name,
                unitCode: r.readTable(_db.units).code,
              ))
          .toList(),
    );
    return ProductDetail(
      product: product,
      variants: variants,
      units: unitRows,
    );
  }

  /// Creates the whole aggregate in one transaction.
  Future<int> createProduct(ProductDraft draft) {
    return _db.transaction(() async {
      final productId = await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              businessId: draft.businessId,
              name: draft.name,
              categoryId: Value(draft.categoryId),
              type: Value(draft.type),
              sku: Value(draft.sku),
              barcode: Value(draft.barcode),
              baseUnitId: draft.baseUnitId,
              costPriceMinor: Value(draft.costPriceMinor),
              salePriceMinor: Value(draft.salePriceMinor),
              wholesalePriceMinor: Value(draft.wholesalePriceMinor),
              minStockMicro: Value(draft.minStockMicro),
              trackStock: Value(draft.trackStock),
              description: Value(draft.description),
              notes: Value(draft.notes),
              marketplaceSkuTokopedia: Value(draft.skuTokopedia),
              marketplaceSkuTiktok: Value(draft.skuTiktok),
              marketplaceSkuShopee: Value(draft.skuShopee),
              weightGrams: Value(draft.weightGrams),
              volumeMl: Value(draft.volumeMl),
            ),
          );

      for (final u in draft.units) {
        await _db.into(_db.productUnits).insert(ProductUnitsCompanion.insert(
              productId: productId,
              unitId: u.unitId,
              conversionToBaseMicro: u.conversionToBaseMicro,
              salePriceOverrideMinor: Value(u.salePriceOverrideMinor),
            ));
      }

      for (final v in draft.variants) {
        await _db.into(_db.productVariants).insert(ProductVariantsCompanion.insert(
              productId: productId,
              name: v.name,
              sku: Value(v.sku),
              costPriceMinor: Value(v.costPriceMinor),
              salePriceMinor: Value(v.salePriceMinor),
            ));
      }

      await _replaceTierPrices(productId, draft.businessId, draft.tierPrices);
      return productId;
    });
  }

  /// Replaces the aggregate contents with [draft] (children replaced whole).
  Future<void> updateProduct(int productId, ProductDraft draft) {
    return _db.transaction(() async {
      await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
          .write(ProductsCompanion(
        name: Value(draft.name),
        categoryId: Value(draft.categoryId),
        type: Value(draft.type),
        sku: Value(draft.sku),
        barcode: Value(draft.barcode),
        baseUnitId: Value(draft.baseUnitId),
        costPriceMinor: Value(draft.costPriceMinor),
        salePriceMinor: Value(draft.salePriceMinor),
        wholesalePriceMinor: Value(draft.wholesalePriceMinor),
        minStockMicro: Value(draft.minStockMicro),
        trackStock: Value(draft.trackStock),
        description: Value(draft.description),
        notes: Value(draft.notes),
        marketplaceSkuTokopedia: Value(draft.skuTokopedia),
        marketplaceSkuTiktok: Value(draft.skuTiktok),
        marketplaceSkuShopee: Value(draft.skuShopee),
        weightGrams: Value(draft.weightGrams),
        volumeMl: Value(draft.volumeMl),
      ));

      await (_db.delete(_db.productUnits)
            ..where((t) => t.productId.equals(productId)))
          .go();
      for (final u in draft.units) {
        await _db.into(_db.productUnits).insert(ProductUnitsCompanion.insert(
              productId: productId,
              unitId: u.unitId,
              conversionToBaseMicro: u.conversionToBaseMicro,
              salePriceOverrideMinor: Value(u.salePriceOverrideMinor),
            ));
      }

      await (_db.delete(_db.productVariants)
            ..where((t) => t.productId.equals(productId)))
          .go();
      for (final v in draft.variants) {
        await _db.into(_db.productVariants).insert(ProductVariantsCompanion.insert(
              productId: productId,
              name: v.name,
              sku: Value(v.sku),
              costPriceMinor: Value(v.costPriceMinor),
              salePriceMinor: Value(v.salePriceMinor),
            ));
      }

      await _replaceTierPrices(productId, draft.businessId, draft.tierPrices);
    });
  }

  Future<void> _replaceTierPrices(
    int productId,
    int businessId,
    List<TierPriceInput> tierPrices,
  ) async {
    await (_db.delete(_db.productPrices)
          ..where((t) => t.productId.equals(productId)))
        .go();
    for (final tp in tierPrices) {
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(
            productId: productId,
            priceTierId: Value(tp.tierId),
            priceMinor: tp.priceMinor,
          ));
    }
  }

  Future<void> setActive(int productId, bool active) =>
      (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          isActive: Value(active),
          archivedAt: active
              ? const Value(null)
              : Value(DateTime.now().toUtc()),
        ),
      );
}

/// Filter chips on the products list (DESAIN §13).
enum ProductFilter { all, active, inactive, lowStock, outOfStock }

/// Input aggregates for create/update.
class ProductDraft {
  ProductDraft({
    required this.businessId,
    required this.name,
    required this.baseUnitId,
    this.categoryId,
    this.type = 'goods',
    this.sku,
    this.barcode,
    this.costPriceMinor = 0,
    this.salePriceMinor = 0,
    this.wholesalePriceMinor,
    this.minStockMicro = 0,
    this.trackStock = true,
    this.description,
    this.notes,
    this.skuTokopedia,
    this.skuTiktok,
    this.skuShopee,
    this.weightGrams,
    this.volumeMl,
    List<ProductUnitInput>? units,
    List<VariantInput>? variants,
    List<TierPriceInput>? tierPrices,
  })  : units = units ?? [],
        variants = variants ?? [],
        tierPrices = tierPrices ?? [];

  final int businessId;
  String name;
  int? categoryId;
  String type;
  String? sku;
  String? barcode;
  final int baseUnitId;
  int costPriceMinor;
  int salePriceMinor;
  int? wholesalePriceMinor;
  int minStockMicro;
  bool trackStock;
  String? description;
  String? notes;
  String? skuTokopedia;
  String? skuTiktok;
  String? skuShopee;
  int? weightGrams;
  int? volumeMl;

  final List<ProductUnitInput> units;
  final List<VariantInput> variants;
  final List<TierPriceInput> tierPrices;
}

class ProductUnitInput {
  ProductUnitInput({required this.unitId, required String conversionToBase})
      : conversionToBaseMicro = toMicro(conversionToBase);

  final int unitId;
  final int conversionToBaseMicro;
  int? salePriceOverrideMinor;
}

class VariantInput {
  VariantInput({required this.name, this.sku, this.costPriceMinor, this.salePriceMinor});

  final String name;
  final String? sku;
  final int? costPriceMinor;
  final int? salePriceMinor;
}

class TierPriceInput {
  TierPriceInput({required this.tierId, required this.priceMinor});

  final int tierId;
  final int priceMinor;
}

/// Loaded aggregate for detail UI.
class ProductDetail {
  ProductDetail({
    required this.product,
    required this.variants,
    required this.units,
  });

  final Product product;
  final List<ProductVariant> variants;
  final List<({ProductUnit entry, String unitName, String unitCode})> units;
}
