import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/error/failures.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';

void main() {
  late AppDatabase db;
  late InventoryService service;
  late int businessId;
  late int productId;
  late int pcsUnitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = InventoryService(db);

    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko'));

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    pcsUnitId = (await refs.unitByCode(businessId, 'pcs'))!.id;

    final products = ProductRepository(db);
    productId = await products.createProduct(
      ProductDraft(
        businessId: businessId,
        name: 'Kopi',
        baseUnitId: pcsUnitId,
        salePriceMinor: 10000,
      ),
    );
  });

  tearDown(() async => db.close());

  Future<int> cachedStock() async => (await (db.select(
    db.products,
  )..where((t) => t.id.equals(productId))).getSingle()).stockQuantityMicro;

  test('opening balance writes movement and sets cache', () async {
    final r = await service.setOpeningBalance(productId, 10000000); // 10
    expect(r.isSuccess, isTrue);
    expect(r.newStockMicro, 10000000);
    expect(await cachedStock(), 10000000);

    final movements = await service.movementsFor(productId);
    expect(movements.single.movementType, 'opening_balance');
    expect(movements.single.qtyBaseMicro, 10000000);
  });

  test('opening balance only once', () async {
    await service.setOpeningBalance(productId, 5000000);
    final r = await service.setOpeningBalance(productId, 9000000);
    expect(r.isSuccess, isFalse);
    expect(r.failure?.code, ErrorCodes.invalidQuantity);
    expect(await cachedStock(), 5000000);
  });

  test('adjustment in/out updates cache symmetrically', () async {
    await service.setOpeningBalance(productId, 20000000); // 20

    final add = await service.adjustStock(productId, 7000000, 'beli tambahan');
    expect(add.newStockMicro, 27000000); // 27

    final take = await service.adjustStock(productId, -3000000, 'rusak');
    expect(take.newStockMicro, 24000000); // 24
    expect(await cachedStock(), 24000000);

    final movements = await service.movementsFor(productId);
    expect(movements[0].movementType, 'adjustment_out'); // newest first
    expect(movements[0].qtyBaseMicro, -3000000);
    expect(movements[1].movementType, 'adjustment_in');
  });

  test('adjustment below zero is rejected atomically', () async {
    await service.setOpeningBalance(productId, 3000000); // 3
    final r = await service.adjustStock(productId, -5000000, 'oops');
    expect(r.isSuccess, isFalse);
    expect(r.failure?.code, ErrorCodes.stockInsufficient);
    // Cache untouched after rollback.
    expect(await cachedStock(), 3000000);
    expect(await service.movementsFor(productId), hasLength(1));
  });

  test('stock opname computes delta vs counted', () async {
    await service.setOpeningBalance(productId, 20000000); // 20
    await service.adjustStock(productId, -2500000, ''); // →17.5

    final r = await service.stockOpname(productId, 19000000, 'cek fisik');
    expect(r.isSuccess, isTrue);
    expect(r.newStockMicro, 19000000);

    final movements = await service.movementsFor(productId);
    expect(movements.first.movementType, 'stock_opname');
    expect(movements.first.qtyBaseMicro, 1500000); // +1.5
    expect(movements.first.note, contains('hitung=19'));
  });

  test('opname with no difference is a no-op success', () async {
    await service.setOpeningBalance(productId, 8000000);
    final before = await service.movementsFor(productId);
    final r = await service.stockOpname(productId, 8000000, '');
    expect(r.isSuccess, isTrue);
    expect(r.newStockMicro, 8000000);
    expect(await service.movementsFor(productId), hasLength(before.length));
  });

  test('negative inputs rejected', () async {
    expect(
      (await service.setOpeningBalance(productId, -1)).failure?.code,
      ErrorCodes.invalidQuantity,
    );
    expect(
      (await service.stockOpname(productId, -5, '')).failure?.code,
      ErrorCodes.invalidQuantity,
    );
  });

  test('zero adjustment rejected', () async {
    expect(
      (await service.adjustStock(productId, 0, 'x')).failure?.code,
      ErrorCodes.invalidQuantity,
    );
  });
}
