import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../customers/data/party_repositories.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../data/purchase_service.dart';

final purchaseServiceProvider = FutureProvider<PurchaseService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return PurchaseService(db);
});

final purchasesListProvider = FutureProvider<List<Purchase>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  final service = await ref.watch(purchaseServiceProvider.future);
  return service.listPurchases(businessId: business.id);
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  return SupplierRepository(db).list(businessId: business.id);
});
