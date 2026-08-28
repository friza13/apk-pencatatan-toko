import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/backup/presentation/data_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/inventory/presentation/stock_card_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/inventory/presentation/stock_screen.dart';
import '../../features/receivables/presentation/receivables_screen.dart';
import '../../features/customers/presentation/simple_party_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/new_sale_screen.dart';
import '../../features/sales/presentation/sale_detail_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/settings/more_menu_screen.dart';
import '../../features/settings/presentation/references_screen.dart';
import '../../features/settings/presentation/store_profile_screen.dart';

/// App routes. Bottom navigation has exactly 5 destinations (DESAIN.md §8):
/// Beranda, Penjualan, Produk, Laporan, Lainnya.
abstract final class AppRoutes {
  static const String home = '/home';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sales',
              builder: (context, state) => const SalesScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const NewSaleScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => SaleDetailScreen(
                    saleId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) => const ProductsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const ProductFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ProductDetailScreen(
                    productId: int.parse(state.pathParameters['id']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => ProductFormScreen(
                        productId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreMenuScreen(),
              routes: [
                GoRoute(
                  path: 'customers',
                  builder: (context, state) => const CustomersScreen(),
                ),
                GoRoute(
                  path: 'suppliers',
                  builder: (context, state) =>
                      const SimplePartyScreen(isSupplier: true),
                ),
                GoRoute(
                  path: 'salesmen',
                  builder: (context, state) =>
                      const SimplePartyScreen(isSupplier: false),
                ),
                GoRoute(
                  path: 'data',
                  builder: (context, state) => const DataScreen(),
                ),
                GoRoute(
                  path: 'piutang',
                  builder: (context, state) => const ReceivablesScreen(),
                ),
                GoRoute(
                  path: 'kas',
                  builder: (context, state) => const FinanceScreen(),
                ),
                GoRoute(
                  path: 'stock',
                  builder: (context, state) => const StockScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => StockCardScreen(
                        productId: int.parse(state.pathParameters['id']!),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'references',
                  builder: (context, state) => const ReferencesScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const StoreProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Penjualan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}
