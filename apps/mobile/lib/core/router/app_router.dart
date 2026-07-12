import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/wallets/screens/wallets_screen.dart';
import '../../features/wallets/screens/currency_detail_screen.dart';
import '../../features/home/screens/dashboard_detail_screen.dart';
import '../../features/budgets/screens/budgets_screen.dart';
import '../../features/budgets/screens/budget_detail_screen.dart';
import '../../features/budgets/widgets/budget_bottom_sheet.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/categories/screens/categories_screen.dart';
import '../../features/transactions/widgets/transaction_bottom_sheet.dart';
import '../../features/transactions/screens/recurring_templates_screen.dart';

/// PRD §6 — go_router with ShellRoute for 4-tab bottom navigation
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
            routes: [
              GoRoute(
                path: 'dashboard-detail',
                builder: (context, state) => const DashboardDetailScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/wallets',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WalletsScreen(),
            ),
          ),
          GoRoute(
            path: '/budgets',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BudgetsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => BudgetDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportsScreen(),
            ),
          ),
        ],
      ),
      // Non-shell routes (full-screen)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: 'recurring',
            builder: (context, state) => const RecurringTemplatesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/wallets/:currency',
        builder: (context, state) => CurrencyDetailScreen(
          currency: state.pathParameters['currency']!,
        ),
      ),
    ],
  );
});

/// PRD §6 — Bottom navigation bar with 4 tabs + shared AppBar on root tabs.
///
/// Root tab screens (Home, Wallets, Budgets, Reports) return body-only widgets.
/// Child route screens (DashboardDetail, BudgetDetail) keep their own Scaffold
/// and AppBar — ScaffoldWithNavBar only provides bottom nav for those.
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  /// The set of paths that are considered "root tabs" — these get the shared
  /// AppBar from ScaffoldWithNavBar. Everything else is a child route that
  /// provides its own AppBar.
  static const _rootTabPaths = {'/', '/wallets', '/budgets', '/reports'};

  static String _resolveTitle(String location) {
    if (location == '/' || location.startsWith('/dashboard-detail')) {
      return 'DailySpend';
    }
    if (location.startsWith('/wallets')) return 'Wallets';
    if (location.startsWith('/budgets')) return 'Budgets';
    if (location.startsWith('/reports')) return 'Reports';
    return 'DailySpend';
  }

  static int _calculateSelectedIndex(String location) {
    if (location == '/' || location.startsWith('/dashboard-detail')) return 0;
    if (location.startsWith('/wallets')) return 1;
    if (location.startsWith('/budgets')) return 2;
    if (location.startsWith('/reports')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _calculateSelectedIndex(location);
    final isRootTab = _rootTabPaths.contains(location);

    return Scaffold(
      appBar: isRootTab
          ? AppBar(
              title: Text(_resolveTitle(location)),
              actions: [
                // Show "Add Budget" action when on the Budgets tab
                if (location == '/budgets')
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Budget',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) => const BudgetBottomSheet(),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            )
          : null,
      body: child,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: () {
          TransactionBottomSheet.show(context);
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              isSelected: selectedIndex == 0,
              onTap: () => context.go('/'),
            ),
            _NavBarItem(
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet,
              label: 'Wallets',
              isSelected: selectedIndex == 1,
              onTap: () => context.go('/wallets'),
            ),
            const SizedBox(width: 48), // Padding for the notch
            _NavBarItem(
              icon: Icons.savings_outlined,
              activeIcon: Icons.savings,
              label: 'Budgets',
              isSelected: selectedIndex == 2,
              onTap: () => context.go('/budgets'),
            ),
            _NavBarItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart,
              label: 'Reports',
              isSelected: selectedIndex == 3,
              onTap: () => context.go('/reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? activeIcon : icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
