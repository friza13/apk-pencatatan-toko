import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notakit/database/app_database.dart';
import 'package:notakit/features/printing/presentation/print_sheet.dart';

void main() {
  testWidgets(
    'PrintSheet formats micro quantity to readable decimal/integer string',
    (tester) async {
      final now = DateTime(2026, 8, 28, 14, 30);
      final sale = Sale(
        id: 1,
        businessId: 1,
        number: 'INV/2026/001',
        status: 'paid',
        saleType: 'retail',
        subtotalMinor: 25000,
        discountTotalMinor: 0,
        taxTotalMinor: 0,
        serviceChargeMinor: 0,
        shippingFeeMinor: 0,
        roundingMinor: 0,
        grandTotalMinor: 25000,
        paidTotalMinor: 25000,
        dueTotalMinor: 0,
        createdAt: now,
        updatedAt: now,
      );

      final line = SaleLine(
        id: 1,
        saleId: 1,
        productId: 1,
        productNameSnapshot: 'Kopi Arabica',
        unitNameSnapshot: 'pcs',
        qtyMicro: 1000000, // 1 unit in micro
        qtyBaseMicro: 1000000,
        conversionFactorMicro: 1000000,
        unitPriceMinor: 25000,
        discountAmountMinor: 0,
        taxAmountMinor: 0,
        costPriceSnapshotMinor: 15000,
        lineTotalMinor: 25000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: PrintSheet(
                storeName: 'Toko NotaKit',
                sale: sale,
                lines: [line],
                customerName: 'Budi',
                paymentLabel: 'TUNAI',
                footerNote: 'Terima kasih!',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify preview text contains "1 X 25.000" and NOT "1000000"
      expect(find.textContaining('1 X 25.000'), findsOneWidget);
      expect(find.textContaining('1000000'), findsNothing);
    },
  );
}
