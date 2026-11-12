import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/state.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/wallets/wallets_screen.dart';
import 'ui/shared.dart';

const _destinations = [
  ('/', 'Home', Icons.space_dashboard_outlined),
  ('/wallets', 'Wallets', Icons.account_balance_wallet_outlined),
  ('/transactions', 'Transactions', Icons.receipt_long_outlined),
];

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      _route('/', (_) => const DashboardScreen()),
      _route('/wallets', (_) => const WalletsScreen()),
      _route(
        '/transactions',
        (state) => TransactionsScreen(
          key: ValueKey(state.uri.toString()),
          walletId: state.uri.queryParameters['wallet'],
        ),
      ),
      _route('/budgets', (_) => const BudgetsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

GoRoute _route(String path, Widget Function(GoRouterState) screen) => GoRoute(
  path: path,
  pageBuilder: (_, state) => NoTransitionPage(
    key: state.pageKey,
    child: _Shell(path: path, child: screen(state)),
  ),
);

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff26805d),
    brightness: brightness,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xff101814)
        : const Color(0xfff5f8f6),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff1b2721) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
    ),
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class MoneyMateApp extends ConsumerWidget {
  const MoneyMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(financeProvider).value?.preferences.theme;
    return MaterialApp.router(
      title: 'MoneyMate',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: ref.watch(_routerProvider),
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell({required this.path, required this.child});
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 860;
    final index = _destinations.indexWhere((item) => item.$1 == path);
    final selected = index < 0 ? 0 : index;
    final state = finance.value;
    final content = finance.when(
      data: (_) => child,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: EmptyPanel(
          Icons.storage,
          'Could not open local data',
          'Check that this device or browser allows local storage.',
          action: FilledButton(
            onPressed: () => ref.invalidate(financeProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
    void navigate(int index) => context.go(_destinations[index].$1);
    final hasWallet =
        state?.ledger.wallets.any((wallet) => !wallet.archived) ?? false;
    final showAdd =
        state != null &&
        (path == '/' ||
            path == '/transactions' ||
            (path == '/wallets' && hasWallet));
    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              title: const Text('MoneyMate'),
              actions: [
                IconButton(
                  tooltip: 'Monthly budgets',
                  icon: const Icon(Icons.pie_chart_outline),
                  onPressed: () => context.go('/budgets'),
                ),
              ],
            ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: navigate,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(icon: Icon(item.$3), label: item.$2),
              ],
            ),
      floatingActionButton: showAdd
          ? FloatingActionButton.extended(
              onPressed: () {
                if (hasWallet) {
                  openEntryEditor(context, ref, state);
                } else {
                  context.go('/wallets');
                }
              },
              icon: const Icon(Icons.add),
              label: Text(hasWallet ? 'Transaction' : 'Add wallet'),
            )
          : null,
      body: desktop
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  extended: true,
                  minExtendedWidth: 206,
                  selectedIndex: selected,
                  onDestinationSelected: navigate,
                  leading: const Padding(
                    padding: EdgeInsets.fromLTRB(14, 22, 14, 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          backgroundColor: ink,
                          foregroundColor: mint,
                          child: Icon(Icons.insights),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'MoneyMate',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.$3),
                        label: Text(item.$2),
                      ),
                  ],
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton.icon(
                      onPressed: () => context.go('/budgets'),
                      icon: const Icon(Icons.pie_chart_outline),
                      label: const Text('Monthly budgets'),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}
