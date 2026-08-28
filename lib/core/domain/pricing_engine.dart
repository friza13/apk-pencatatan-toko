/// Pricing resolution per FR-PRICE-001.
///
/// Priority (highest first):
///   1. customer override      — CustomerPrice rows
///   2. tier / customer type   — ProductPrice rows matching the customer's
///                               tier or type
///   3. wholesale rule         — explicit wholesale toggle uses
///                               product.wholesalePriceMinor
///   4. standard               — product.salePriceMinor
///
/// All inputs are plain dataclasses so the engine stays free of drift and
/// infrastructure; repositories map table rows into these in P4+.
library;

/// A price candidate coming from any pricing source.
class PriceCandidate {
  const PriceCandidate({
    required this.priceMinor,
    required this.source,
    this.variantId,
    this.unitId,
    this.minQtyMicro,
    this.validFromMillis,
    this.validToMillis,
    this.tierPriority = 100,
  });

  final int priceMinor;
  final PriceSource source;
  final int? variantId;
  final int? unitId;
  final int? minQtyMicro;
  final int? validFromMillis;
  final int? validToMillis;

  /// Lower number wins when comparing tier-based candidates.
  final int tierPriority;
}

enum PriceSource { customerOverride, tierOrCustomerType, wholesale, standard }

/// Context of a single line being priced.
class PricingRequest {
  const PricingRequest({
    required this.nowMillis,
    required this.quantityMicro,
    this.productId,
    this.variantId,
    this.unitId,
    this.customerTierId,
    this.customerTypeId,
    this.useWholesale = false,
  });

  final int nowMillis;
  final int quantityMicro;
  final int? productId;
  final int? variantId;
  final int? unitId;
  final int? customerTierId;
  final int? customerTypeId;
  final bool useWholesale;
}

/// Resolved outcome of pricing.
class ResolvedPrice {
  const ResolvedPrice({
    required this.unitPriceMinor,
    required this.source,
    this.candidate,
  });

  final int unitPriceMinor;
  final PriceSource source;
  final PriceCandidate? candidate;
}

abstract final class PricingEngine {
  /// Standard fallback prices carried by the product master.
  static ResolvedPrice resolve({
    required PricingRequest request,
    required List<PriceCandidate> candidates,
    required int standardPriceMinor,
    int? wholesalePriceMinor,
  }) {
    final applicable = candidates
        .where((c) => _isApplicable(c, request))
        .toList();

    // 1) Customer overrides — most specific min_qty, then newest start.
    final override = _pickBest(
      applicable,
      source: PriceSource.customerOverride,
      request: request,
    );
    if (override != null) {
      return ResolvedPrice(
        unitPriceMinor: override.priceMinor,
        source: override.source,
        candidate: override,
      );
    }

    // 2) Tier / customer-type rules.
    final tiered = _pickBest(
      applicable,
      source: PriceSource.tierOrCustomerType,
      request: request,
    );
    if (tiered != null) {
      return ResolvedPrice(
        unitPriceMinor: tiered.priceMinor,
        source: tiered.source,
        candidate: tiered,
      );
    }

    // 3) Wholesale toggle.
    if (request.useWholesale && wholesalePriceMinor != null) {
      return ResolvedPrice(
        unitPriceMinor: wholesalePriceMinor,
        source: PriceSource.wholesale,
      );
    }

    // 4) Standard.
    return ResolvedPrice(
      unitPriceMinor: standardPriceMinor,
      source: PriceSource.standard,
    );
  }

  static bool _isApplicable(PriceCandidate c, PricingRequest r) {
    if (c.priceMinor < 0) {
      return false;
    }
    if (c.minQtyMicro != null && r.quantityMicro < c.minQtyMicro!) {
      return false;
    }
    if (c.variantId != null && c.variantId != r.variantId) {
      return false;
    }
    if (c.unitId != null && c.unitId != r.unitId) {
      return false;
    }
    if (c.validFromMillis != null && r.nowMillis < c.validFromMillis!) {
      return false;
    }
    if (c.validToMillis != null && r.nowMillis > c.validToMillis!) {
      return false;
    }
    return true;
  }

  static PriceCandidate? _pickBest(
    List<PriceCandidate> candidates, {
    required PriceSource source,
    required PricingRequest request,
  }) {
    final pool = candidates.where((c) => c.source == source).toList();
    if (pool.isEmpty) {
      return null;
    }
    pool.sort((a, b) {
      // Specificity: larger min_qty first.
      final aMin = a.minQtyMicro ?? 0;
      final bMin = b.minQtyMicro ?? 0;
      final byMinQty = bMin.compareTo(aMin);
      if (byMinQty != 0) {
        return byMinQty;
      }
      // Then tier priority (lower number = more important).
      final byPriority = a.tierPriority.compareTo(b.tierPriority);
      if (byPriority != 0) {
        return byPriority;
      }
      // Then newest validity start.
      final aFrom = a.validFromMillis ?? 0;
      final bFrom = b.validFromMillis ?? 0;
      return bFrom.compareTo(aFrom);
    });
    return pool.first;
  }
}
