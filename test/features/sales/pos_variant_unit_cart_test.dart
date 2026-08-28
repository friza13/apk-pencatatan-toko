import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:notakit/core/units/quantity.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/inventory/data/inventory_service.dart';
import 'package:notakit/features/products/controllers/products_providers.dart';
import 'package:notakit/features/products/data/product_repository.dart';
import 'package:notakit/features/products/data/reference_repository.dart';
import 'package:notakit/features/sales/controllers/sales_providers.dart';
import 'package:notakit/features/sales/presentation/new_sale_screen.dart';
import 'package:notakit/features/security/providers.dart';

void main() {
  late AppDatabase db;
  late int businessId;
  late int baseUnitId;
  late int boxUnitId;
  late Business business;
  late int cashAccountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final ownerId = await db
        .into(db.owners)
        .insert(OwnersCompanion.insert(name: 'Owner'));
    business = await db
        .into(db.businesses)
        .insertReturning(
          BusinessesCompanion.insert(ownerId: ownerId, name: 'Toko Sukses'),
        );
    businessId = business.id;

    final refs = ReferenceRepository(db);
    await refs.ensureDefaults(businessId);
    baseUnitId = (await refs.unitByCode(businessId, 'pcs'))!.id;
    boxUnitId = await db
        .into(db.units)
        .insert(
          UnitsCompanion.insert(
            businessId: businessId,
            code: 'box',
            name: 'Box',
          ),
        );

    cashAccountId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            businessId: businessId,
            name: 'Kas',
            type: const Value('cash'),
          ),
        );
  });

  tearDown(() async => db.close());

  test('CartController adds variant and converted unit as separate lines', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final product = Product(
      id: 1,
      businessId: 1,
      name: 'Kaos Polos',
      type: 'goods',
      baseUnitId: 1,
      costPriceMinor: 30000,
      salePriceMinor: 50000,
      wholesalePriceMinor: 0,
      minStockMicro: 0,
      stockQuantityMicro: 10000000,
      trackStock: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final cart = container.read(cartProvider.notifier)
      ..add(product)
      ..addVariantOrUnit(
        product: product,
        variantId: 10,
        variantName: 'XL',
        unitPriceMinor: 55000,
        currentStockMicro: 4000000,
      )
      ..addVariantOrUnit(
        product: product,
        unitId: 2,
        unitName: 'Lusin',
        conversionFactorMicro: 12 * quantityScale,
        unitPriceMinor: 550000,
      );

    expect(container.read(cartProvider).lines.length, 3);
    final baseLine = container.read(cartProvider).lines[0];
    expect(baseLine.unitPriceMinor, 50000);

    final variantLine = container.read(cartProvider).lines[1];
    expect(variantLine.variantId, 10);
    expect(variantLine.variantName, 'XL');
    expect(variantLine.unitPriceMinor, 55000);
    expect(variantLine.displayName, contains('XL'));

    final unitLine = container.read(cartProvider).lines[2];
    expect(unitLine.unitId, 2);
    expect(unitLine.unitName, 'Lusin');
    expect(unitLine.conversionFactorMicro, 12 * quantityScale);
    expect(unitLine.displayName, contains('Lusin'));

    // 4. Increment variant line by key
    cart.incrementByKey(variantLine.cartKey);
    expect(container.read(cartProvider).lines[1].qtyMicro, 2000000);
  });

  testWidgets(
    'NewSaleScreen shows variant/unit selection sheet and checkouts',
    (tester) async {
      final prodRepo = ProductRepository(db);
      final invService = InventoryService(db);

      final prodId = await prodRepo.createProduct(
        ProductDraft(
          businessId: businessId,
          name: 'Kemeja Katun',
          baseUnitId: baseUnitId,
          costPriceMinor: 70000,
          salePriceMinor: 100000,
          variants: [
            VariantInput(name: 'Putih M', salePriceMinor: 100000),
            VariantInput(name: 'Putih L', salePriceMinor: 110000),
          ],
          units: [
            ProductUnitInput(unitId: boxUnitId, conversionToBase: '10')
              ..salePriceOverrideMinor = 950000,
          ],
        ),
      );
      await invService.setOpeningBalance(prodId, 50 * quantityScale);
      final variants = await (db.select(
        db.productVariants,
      )..where((t) => t.productId.equals(prodId))).get();
      for (final v in variants) {
        await invService.setOpeningBalance(
          prodId,
          50 * quantityScale,
          variantId: v.id,
        );
      }

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const NewSaleScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) =>
                const Scaffold(body: Text('Sales Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) async => db),
            currentBusinessProvider.overrideWith((ref) async => business),
            defaultAccountIdProvider.overrideWith((ref) async => cashAccountId),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Search for product
      await tester.enterText(
        find.widgetWithText(TextField, 'Cari produk untuk ditambahkan...'),
        'Kemeja',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Click product in results
      expect(find.text('Kemeja Katun'), findsOneWidget);
      await tester.tap(find.text('Kemeja Katun'));
      await tester.pumpAndSettle();

      // Modal sheet should pop up with options: Default / Varian / Satuan
      expect(find.text('Pilih Varian / Satuan'), findsOneWidget);
      expect(find.text('Putih M'), findsOneWidget);
      expect(find.text('Putih L'), findsOneWidget);
      expect(find.text('Satuan: Box'), findsOneWidget);

      // Tap Putih L variant
      await tester.tap(find.text('Putih L'));
      await tester.pumpAndSettle();

      // Verify item in cart with variant name
      expect(find.text('Kemeja Katun (Putih L)'), findsOneWidget);
      expect(find.text('Bayar - Rp110.000'), findsOneWidget);

      // Tap Bayar
      await tester.tap(find.text('Bayar - Rp110.000'));
      await tester.pumpAndSettle();

      // Verify Payment BottomSheet
      expect(find.text('Pembayaran'), findsOneWidget);
      await tester.tap(find.text('Simpan Nota'));
      await tester.pumpAndSettle();

      // Check dialog
      expect(find.text('Nota tersimpan'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Nota tersimpan'), findsNothing);

      // Check DB sale lines
      final saleLines = await db.select(db.saleLines).get();
      expect(saleLines.length, 1);
      expect(saleLines.first.unitPriceMinor, 110000);
      expect(saleLines.first.variantId, isNotNull);
    },
  );
}
