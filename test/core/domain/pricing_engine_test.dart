import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/core/domain/pricing_engine.dart';

const _now = 1790000000000;

PriceCandidate _override({
  required int price,
  int? minQtyMicro,
  int? from,
  int? to,
}) => PriceCandidate(
  priceMinor: price,
  source: PriceSource.customerOverride,
  minQtyMicro: minQtyMicro,
  validFromMillis: from,
  validToMillis: to,
);

PricingRequest _request({int qtyMicro = 1000000, bool wholesale = false}) {
  return PricingRequest(
    nowMillis: _now,
    quantityMicro: qtyMicro,
    useWholesale: wholesale,
  );
}

void main() {
  group('PricingEngine priority', () {
    test('standard price used when nothing else matches', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: const [],
        standardPriceMinor: 12000,
      );
      expect(r.source, PriceSource.standard);
      expect(r.unitPriceMinor, 12000);
    });

    test('wholesale toggle beats standard but loses to overrides', () {
      final wholesaleOnly = PricingEngine.resolve(
        request: _request(wholesale: true),
        candidates: const [],
        standardPriceMinor: 12000,
        wholesalePriceMinor: 10500,
      );
      expect(wholesaleOnly.source, PriceSource.wholesale);
      expect(wholesaleOnly.unitPriceMinor, 10500);

      final overrideWins = PricingEngine.resolve(
        request: _request(wholesale: true),
        candidates: [_override(price: 9000)],
        standardPriceMinor: 12000,
        wholesalePriceMinor: 10500,
      );
      expect(overrideWins.source, PriceSource.customerOverride);
      expect(overrideWins.unitPriceMinor, 9000);
    });

    test('customer override beats tier rule', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [
          _override(price: 9000),
          const PriceCandidate(
            priceMinor: 9500,
            source: PriceSource.tierOrCustomerType,
          ),
        ],
        standardPriceMinor: 12000,
      );
      expect(r.source, PriceSource.customerOverride);
      expect(r.unitPriceMinor, 9000);
    });

    test('tier rule beats standard', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [
          const PriceCandidate(
            priceMinor: 9500,
            source: PriceSource.tierOrCustomerType,
          ),
        ],
        standardPriceMinor: 12000,
      );
      expect(r.source, PriceSource.tierOrCustomerType);
      expect(r.unitPriceMinor, 9500);
    });

    test('quantity break: larger min_qty wins among overrides', () {
      final r = PricingEngine.resolve(
        request: _request(qtyMicro: 24000000),
        candidates: [
          _override(price: 9000),
          _override(price: 8500, minQtyMicro: 12000000),
          _override(price: 8000, minQtyMicro: 48000000), // threshold unreached
        ],
        standardPriceMinor: 12000,
      );
      expect(r.unitPriceMinor, 8500);
    });

    test('expired candidate ignored', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [_override(price: 7000, from: 1, to: 100)],
        standardPriceMinor: 12000,
      );
      expect(r.source, PriceSource.standard);
    });

    test('not-yet-valid candidate ignored', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [_override(price: 7000, from: 1999999999999)],
        standardPriceMinor: 12000,
      );
      expect(r.source, PriceSource.standard);
    });

    test('tier priority breaks ties between tier candidates', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [
          const PriceCandidate(
            priceMinor: 9900,
            source: PriceSource.tierOrCustomerType,
          ),
          const PriceCandidate(
            priceMinor: 9400,
            source: PriceSource.tierOrCustomerType,
            tierPriority: 10,
          ),
        ],
        standardPriceMinor: 12000,
      );
      expect(r.unitPriceMinor, 9400);
    });

    test('tie on min_qty resolved by newer validity start', () {
      final r = PricingEngine.resolve(
        request: _request(),
        candidates: [
          _override(price: 9100, from: 1780000000000),
          _override(price: 8900, from: 1785000000000),
        ],
        standardPriceMinor: 12000,
      );
      expect(r.unitPriceMinor, 8900);
    });

    test('variant and unit-specific candidates do not leak to other lines', () {
      final r = PricingEngine.resolve(
        request: PricingRequest(
          nowMillis: _now,
          quantityMicro: 1000000,
          variantId: 2,
          unitId: 3,
        ),
        candidates: const [
          PriceCandidate(
            priceMinor: 7000,
            source: PriceSource.tierOrCustomerType,
            variantId: 1,
            unitId: 3,
          ),
          PriceCandidate(
            priceMinor: 8000,
            source: PriceSource.tierOrCustomerType,
            variantId: 2,
            unitId: 3,
          ),
        ],
        standardPriceMinor: 12000,
      );
      expect(r.unitPriceMinor, 8000);
    });
  });
}
