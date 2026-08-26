import 'package:drift/drift.dart';

import '../../../core/domain/business_clock.dart';
import '../../../core/units/quantity.dart';
import '../../../database/app_database.dart';

/// Report period preset (DESAIN §16).
enum ReportPeriod { today, yesterday, last7, last30, thisMonth }

/// Aggregated numbers for a period.
class SalesSummary {
  const SalesSummary({
    required this.totalMinor,
    required this.transactionCount,
    required this.paidMinor,
    required this.dueMinor,
    required this.profitMinor,
  });

  final int totalMinor;
  final int transactionCount;
  final int paidMinor;
  final int dueMinor;
  final int profitMinor; // gross profit from cost snapshots (ERD §17)
}

typedef DayTotal = ({DateTime dayLocalStartUtc, int totalMinor});

class TopProductRow {
  TopProductRow({
    required this.name,
    required this.qtyBaseMicro,
    required this.totalMinor,
  });

  final String name;
  final int qtyBaseMicro;
  final int totalMinor;
}

/// Read-only reporting queries. All day boundaries use the business timezone
/// via BusinessClock (D-012). Only finalized, non-voided sales count.
class ReportRepository {
  ReportRepository(this._db);

  final AppDatabase _db;

  static const List<String> _countedStatuses = [
    'confirmed',
    'paid',
    'partially_paid',
    'credit',
  ];

  /// [startUtcMillis, endUtcMillis) window for a preset relative to now.
  (int, int) rangeFor(ReportPeriod period, int offsetMinutes) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    switch (period) {
      case ReportPeriod.today:
        return BusinessClock.dayRangeUtcMillis(now, offsetMinutes);
      case ReportPeriod.yesterday:
        final (s, _) = BusinessClock.dayRangeUtcMillis(
            now - BusinessClock.millisPerDay, offsetMinutes);
        return (s, s + BusinessClock.millisPerDay);
      case ReportPeriod.last7:
      case ReportPeriod.last30:
        final days = period == ReportPeriod.last7 ? 7 : 30;
        final (todayStart, todayEnd) =
            BusinessClock.dayRangeUtcMillis(now, offsetMinutes);
        return (
          todayStart - days * BusinessClock.millisPerDay,
          todayEnd
        );
      case ReportPeriod.thisMonth:
        final localNow = DateTime.now()
            .toUtc()
            .add(Duration(minutes: offsetMinutes));
        final firstLocal =
            DateTime.utc(localNow.year, localNow.month);
        final start = firstLocal.millisecondsSinceEpoch -
            offsetMinutes * 60000;
        return (start, now + 1);
    }
  }

  Future<SalesSummary> salesSummary({
    required int businessId,
    required int startUtcMillis,
    required int endUtcMillis,
  }) async {
    final salesRows = await (_db.select(_db.sales)
          ..where((t) =>
              t.businessId.equals(businessId) &
              t.status.isIn(_countedStatuses) &
              t.createdAt.isBiggerOrEqualValue(startUtcMillis) &
              t.createdAt.isSmallerThanValue(endUtcMillis)))
        .get();

    var total = 0;
    var paid = 0;
    var due = 0;
    for (final s in salesRows) {
      total += s.grandTotalMinor;
      paid += s.paidTotalMinor;
      due += s.dueTotalMinor;
    }

    // Gross profit: sum(line_total - qty_base x cost_snapshot).
    var profit = 0;
    if (salesRows.isNotEmpty) {
      final ids = salesRows.map((s) => s.id).toList();
      final lines = await (_db.select(_db.saleLines)
            ..where((t) => t.saleId.isIn(ids)))
          .get();
      for (final l in lines) {
        final cogs = (l.qtyBaseMicro * l.costPriceSnapshotMinor) ~/
            quantityScale;
        profit += l.lineTotalMinor - cogs;
      }
    }

    return SalesSummary(
      totalMinor: total,
      transactionCount: salesRows.length,
      paidMinor: paid,
      dueMinor: due,
      profitMinor: profit,
    );
  }

  /// Daily totals for the last [days] days ending today (bar chart source).
  Future<List<DayTotal>>
      dailyTotals({
    required int businessId,
    required int days,
    required int offsetMinutes,
    String statusFilter = 'all',
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final result = <({DateTime dayLocalStartUtc, int totalMinor})>[];

    for (var d = days - 1; d >= 0; d--) {
      final (s, e) = BusinessClock.dayRangeUtcMillis(
          now - d * BusinessClock.millisPerDay, offsetMinutes);
      final sumExp = _db.sales.grandTotalMinor.sum();

      final query = _db.selectOnly(_db.sales)
        ..addColumns([sumExp])
        ..where(_db.sales.businessId.equals(businessId) &
            _db.sales.status.isIn(_countedStatuses) &
            _db.sales.createdAt.isBiggerOrEqualValue(s) &
            _db.sales.createdAt.isSmallerThanValue(e));

      final row = await query.getSingle();
      final total = row.read(sumExp) ?? 0;
      result.add((
        dayLocalStartUtc:
            DateTime.fromMillisecondsSinceEpoch(s, isUtc: true),
        totalMinor: total,
      ));
    }
    return result;
  }

  /// Best sellers within the window.
  Future<List<TopProductRow>> topProducts({
    required int businessId,
    required int startUtcMillis,
    required int endUtcMillis,
    int limit = 5,
  }) async {
    final salesIdsQuery = _db.select(_db.sales)
          ..where((t) =>
              t.businessId.equals(businessId) &
              t.status.isIn(_countedStatuses) &
              t.createdAt.isBiggerOrEqualValue(startUtcMillis) &
              t.createdAt.isSmallerThanValue(endUtcMillis));
    final salesIds = (await salesIdsQuery.get()).map((s) => s.id).toList();
    if (salesIds.isEmpty) return [];

    final qtySum = _db.saleLines.qtyBaseMicro.sum();
    final totSum = _db.saleLines.lineTotalMinor.sum();

    final query = _db.selectOnly(_db.saleLines)
      ..addColumns([_db.saleLines.productNameSnapshot, qtySum, totSum])
      ..where(_db.saleLines.saleId.isIn(salesIds))
      ..groupBy([_db.saleLines.productNameSnapshot])
      ..orderBy([OrderingTerm.desc(totSum)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map((r) => TopProductRow(
              name: r.read(_db.saleLines.productNameSnapshot)!,
              qtyBaseMicro: r.read(qtySum) ?? 0,
              totalMinor: r.read(totSum) ?? 0,
            ))
        .toList();
  }

  /// Stock valuation from cached balances at current WAC.
  Future<int> stockValuationMinor(int businessId) async {
    final products = await (_db.select(_db.products)
          ..where((t) =>
              t.businessId.equals(businessId) &
              t.trackStock.equals(true) &
              t.type.equals('goods')))
        .get();
    var total = 0;
    for (final p in products) {
      final qtyUnits = p.stockQuantityMicro ~/ quantityScale;
      total += qtyUnits * p.costPriceMinor;
    }
    return total;
  }

  /// Outstanding receivables total (D-010 derived overdue handled by caller).
  Future<int> receivablesOutstanding(int businessId) async {
    final sum = _db.receivables.remainingAmountMinor.sum();
    final query = _db.selectOnly(_db.receivables)
      ..addColumns([sum])
      ..where(_db.receivables.businessId.equals(businessId) &
          _db.receivables.remainingAmountMinor.isBiggerThanValue(0));
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  /// Low-stock product names for dashboard insight.
  Future<List<String>> lowStockNames(int businessId, {int limit = 3}) async {
    final rows = await (_db.select(_db.products)
          ..where((t) =>
              t.businessId.equals(businessId) &
              t.trackStock.equals(true) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.stockQuantityMicro)])
          ..limit(limit))
        .get();
    return rows
        .where((p) =>
            p.minStockMicro > 0 &&
            p.stockQuantityMicro <= p.minStockMicro)
        .map((p) => p.name)
        .toList();
  }
}
