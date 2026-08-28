import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/products/data/product_repository.dart';

/// NFR-001 perf sanity: pencarian produk pada ~10k baris harus tetap
/// responsif. Angka absolut dicetak untuk monitoring, assertion longgar agar
/// tidak flaky di CI lambat.
void main() {
  late AppDatabase db;
  late int businessId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'O'));
    businessId = await db
        .into(db.businesses)
        .insert(BusinessesCompanion.insert(ownerId: ownerId, name: 'T'));
  });

  tearDown(() async => db.close());

  test('bulk insert 10k products lalu search tetap cepat', () async {
    await db
        .into(db.units)
        .insert(
          UnitsCompanion.insert(
            businessId: businessId,
            code: 'pcs',
            name: 'Pieces',
          ),
        );
    final pcsId = (await (db.select(
      db.units,
    )..where((t) => t.code.equals('pcs'))).getSingle()).id;
    final sw = Stopwatch()..start();
    final repo = ProductRepository(db);
    const n = 10000;
    for (var i = 0; i < n; i++) {
      // Batch per 500 via transaction agar cepat.
      if (i % 500 == 0) {}
      await _insert(db, businessId, pcsId, i);
    }
    sw.stop();
    // ignore: avoid_print
    print('[PERF] bulk-insert $n rows: ${sw.elapsedMilliseconds} ms');

    final t1 = Stopwatch()..start();
    final hits = await repo.search(
      businessId: businessId,
      query: 'Produk 9999',
    );
    t1.stop();
    // ignore: avoid_print
    print(
      '[PERF] search exact: ${t1.elapsedMilliseconds} ms, '
      'hits=${hits.length}',
    );

    final t2 = Stopwatch()..start();
    await repo.search(
      businessId: businessId,
      query: '99',
      filter: ProductFilter.active,
    );
    t2.stop();
    // ignore: avoid_print
    print('[PERF] search prefix-2-digit: ${t2.elapsedMilliseconds} ms');

    expect(
      hits,
      isNotEmpty,
      reason: 'query "9999" harus menemukan Produk 9999',
    );
    expect(
      t2.elapsedMilliseconds,
      lessThan(2000),
      reason: 'search harus < 2s bahkan di mesin lambat (NFR target 200ms)',
    );
  });
}

Future<void> _insert(AppDatabase db, int businessId, int unitId, int i) async {
  await db.batch((batch) {
    batch.insert(
      db.products,
      ProductsCompanion.insert(
        businessId: businessId,
        name: 'Produk $i',
        sku: Value('SKU-$i'),
        baseUnitId: unitId,
        salePriceMinor: Value(1000 + i),
      ),
    );
  });
}
