import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/providers.dart';
import '../data/inventory_service.dart';

final FutureProvider<InventoryService> inventoryServiceProvider =
    FutureProvider<InventoryService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return InventoryService(db);
});
