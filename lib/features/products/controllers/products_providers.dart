import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../security/auth_repository.dart';
import '../../security/providers.dart';
import '../data/product_repository.dart';
import '../data/reference_repository.dart';

/// Current signed-in business (single-owner app => at most one row).
final FutureProvider<Business> currentBusinessProvider =
    FutureProvider<Business>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final repo =
      AuthRepository(db: db, secureStore: ref.read(secureStoreProvider));
  final business = await repo.currentBusiness();
  if (business == null) {
    throw StateError('No business - onboarding incomplete');
  }
  return business;
});

final FutureProvider<ReferenceRepository> referenceRepositoryProvider =
    FutureProvider<ReferenceRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ReferenceRepository(db);
});

final FutureProvider<ProductRepository> productRepositoryProvider =
    FutureProvider<ProductRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ProductRepository(db);
});

/// Seeds starter units/tiers/types once per unlock.
final FutureProvider<void> masterDataSeedProvider = FutureProvider<void>(
  (ref) async {
    final business = await ref.watch(currentBusinessProvider.future);
    final refs = await ref.watch(referenceRepositoryProvider.future);
    await refs.ensureDefaults(business.id);
  },
);

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.query = '',
    this.filter = ProductFilter.all,
  });

  final List<Product> items;
  final String query;
  final ProductFilter filter;
}

class ProductsController extends AsyncNotifier<ProductListState> {
  @override
  Future<ProductListState> build() async {
    final business = await ref.watch(currentBusinessProvider.future);
    await ref.watch(masterDataSeedProvider.future);
    final repo = await ref.watch(productRepositoryProvider.future);
    final items = await repo.search(businessId: business.id);
    return ProductListState(items: items);
  }

  Future<void> _reload(String query, ProductFilter filter) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      final repo = await ref.read(productRepositoryProvider.future);
      final items = await repo.search(
        businessId: business.id,
        query: query,
        filter: filter,
      );
      return ProductListState(items: items, query: query, filter: filter);
    });
  }

  Future<void> setQuery(String q) => _reload(q, state.value!.filter);

  Future<void> setFilter(ProductFilter f) => _reload(state.value!.query, f);

  Future<void> refresh() => _reload(state.value!.query, state.value!.filter);

  /// Creates or updates from the form, then reloads the list.
  Future<int> saveProduct(int? existingId, ProductDraft draft) async {
    final repo = await ref.read(productRepositoryProvider.future);
    int id;
    if (existingId == null) {
      id = await repo.createProduct(draft);
    } else {
      await repo.updateProduct(existingId, draft);
      id = existingId;
    }
    await refresh();
    return id;
  }

  Future<void> toggleActive(Product p) async {
    final repo = await ref.read(productRepositoryProvider.future);
    await repo.setActive(p.id, !p.isActive);
    await refresh();
  }
}

final productsControllerProvider =
    AsyncNotifierProvider<ProductsController, ProductListState>(
        ProductsController.new);

/// Watchable categories for dropdowns/forms.
final StreamProvider<List<Category>> categoriesStreamProvider =
    StreamProvider<List<Category>>((ref) async* {
  final business = await ref.watch(currentBusinessProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final query = db.select(db.categories)
    ..where((t) => t.businessId.equals(business.id))
    ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  yield* query.watch();
});

/// Watchable units for dropdowns/conversion editors.
final StreamProvider<List<Unit>> unitsStreamProvider =
    StreamProvider<List<Unit>>((ref) async* {
  final business = await ref.watch(currentBusinessProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final query = db.select(db.units)
    ..where((t) => t.businessId.equals(business.id))
    ..orderBy([(t) => OrderingTerm.asc(t.code)]);
  yield* query.watch();
});

/// Watchable price tiers for the pricing section.
final StreamProvider<List<PriceTier>> tiersStreamProvider =
    StreamProvider<List<PriceTier>>((ref) async* {
  final business = await ref.watch(currentBusinessProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  yield* (db.select(db.priceTiers)
        ..where((t) => t.businessId.equals(business.id)))
      .watch();
});
