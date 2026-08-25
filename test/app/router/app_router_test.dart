import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:notakit/main.dart';

void main() {
  testWidgets('app boots into Beranda with 5-tab bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NotaKitApp()));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsAtLeastNWidgets(1));
    expect(find.text('Penjualan'), findsOneWidget);
    expect(find.text('Produk'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
  });

  testWidgets('bottom navigation switches to Produk tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NotaKitApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produk').last);
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(router.routerDelegate.currentConfiguration.uri.path, '/products');
  });
}
