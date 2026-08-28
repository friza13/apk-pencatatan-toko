import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../products/controllers/products_providers.dart';
import '../../security/providers.dart';
import '../data/sales_service.dart';
import '../data/sales_return_service.dart';

final FutureProvider<SalesService> salesServiceProvider =
    FutureProvider<SalesService>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      return SalesService(db);
    });

final FutureProvider<SalesReturnService> salesReturnServiceProvider =
    FutureProvider<SalesReturnService>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      return SalesReturnService(db);
    });

/// Ensures at least one cash account exists for taking payments.
final FutureProvider<int> defaultAccountIdProvider = FutureProvider<int>((
  ref,
) async {
  final business = await ref.watch(currentBusinessProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final rows = await (db.select(
    db.accounts,
  )..where((t) => t.businessId.equals(business.id))).get();
  if (rows.isNotEmpty) {
    return rows
        .firstWhere((a) => a.type == 'cash', orElse: () => rows.first)
        .id;
  }
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          businessId: business.id,
          name: 'Kas Tunai',
          type: const Value('cash'),
        ),
      );
});

// ---------------- Cart ----------------

class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.qtyMicro,
    required this.unitPriceMinor,
    this.tracked = true,
    this.currentStockMicro = 0,
  });

  final int productId;
  final String name;
  int qtyMicro;
  int unitPriceMinor;
  bool tracked;
  int currentStockMicro;

  int get lineTotalMinor => divideHalfUpRound(qtyMicro * unitPriceMinor);
}

int divideHalfUpRound(int numerator) => (numerator + 500000) ~/ 1000000;

class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  int get subtotalMinor => lines.fold(0, (sum, l) => sum + l.lineTotalMinor);

  bool get isEmpty => lines.isEmpty;
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Product p) {
    final existing = state.lines.where((l) => l.productId == p.id).toList();
    if (existing.isNotEmpty) {
      _changeQty(p.id, existing.first.qtyMicro + 1000000);
      return;
    }
    state = CartState(
      lines: [
        ...state.lines,
        CartLine(
          productId: p.id,
          name: p.name,
          qtyMicro: 1000000,
          unitPriceMinor: p.salePriceMinor,
          tracked: p.trackStock && p.type == 'goods',
          currentStockMicro: p.stockQuantityMicro,
        ),
      ],
    );
  }

  void _changeQty(int productId, int newQtyMicro) {
    if (newQtyMicro <= 0) {
      state = CartState(
        lines: state.lines.where((l) => l.productId != productId).toList(),
      );
      return;
    }
    state = CartState(
      lines: [
        for (final l in state.lines)
          if (l.productId == productId)
            CartLine(
              productId: l.productId,
              name: l.name,
              qtyMicro: newQtyMicro,
              unitPriceMinor: l.unitPriceMinor,
              tracked: l.tracked,
              currentStockMicro: l.currentStockMicro,
            )
          else
            l,
      ],
    );
  }

  void increment(int productId) {
    final line = state.lines.where((l) => l.productId == productId).firstOrNull;
    if (line == null) return;
    _changeQty(productId, line.qtyMicro + 1000000);
  }

  void decrement(int productId) {
    final line = state.lines.where((l) => l.productId == productId).firstOrNull;
    if (line == null) return;
    _changeQty(productId, line.qtyMicro - 1000000);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Newest-first list of all sales for the business.
final FutureProvider<List<Sale>> salesListProvider = FutureProvider<List<Sale>>(
  (ref) async {
    final business = await ref.watch(currentBusinessProvider.future);
    final db = await ref.watch(appDatabaseProvider.future);
    return (db.select(db.sales)
          ..where((t) => t.businessId.equals(business.id))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  },
);

/// Single sale + lines for the detail screen.
final saleDetailProvider =
    FutureProvider.family<({Sale sale, List<SaleLine> lines})?, int>((
      ref,
      id,
    ) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final sale = await (db.select(
        db.sales,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (sale == null) return null;
      final lines = await (db.select(
        db.saleLines,
      )..where((t) => t.saleId.equals(id))).get();
      return (sale: sale, lines: lines);
    });
