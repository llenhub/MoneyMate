import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/state.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/planning/planning_screen.dart';
import 'features/statistics/statistics_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/wallets/wallets_screen.dart';
import 'ui/shared.dart';

const _destinations = [
  ('/', 'Home', Icons.space_dashboard_outlined),
  ('/statistics', 'Statistics', Icons.bar_chart_rounded),
  ('/records', 'Records', Icons.receipt_long_outlined),
  ('/planning', 'Planning', Icons.flag_outlined),
  ('/assistant', 'AI Chat', Icons.chat_bubble_outline),
];

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      _route('/', (_) => const DashboardScreen()),
      _route('/wallets', (_) => const WalletsScreen()),
      _route(
        '/records',
        (state) => TransactionsScreen(
          key: ValueKey(state.uri.toString()),
          walletId: state.uri.queryParameters['wallet'],
        ),
      ),
      _route('/assistant', (_) => const AssistantScreen()),
      _route('/settings', (_) => const SettingsScreen()),
      _route('/planning', (_) => const PlanningScreen()),
      _route(
        '/statistics',
        (state) => StatisticsScreen(
          key: ValueKey(state.uri),
          balance: state.uri.queryParameters['view'] == 'balance',
        ),
      ),
      GoRoute(path: '/budgets', redirect: (_, _) => '/planning'),
      GoRoute(
        path: '/transactions',
        redirect: (_, state) => state.uri.replace(path: '/records').toString(),
      ),
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
      data: (_) => Column(
        children: [
          if (state!.preferences.demo)
            Material(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child: Text(
                    'Demo mode · Fictional data',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
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
    final primary = index >= 0;
    final showAdd = state != null && primary && path != '/assistant';
    return Scaffold(
      appBar: !primary
          ? AppBar(
              leading: IconButton(
                tooltip: 'Back to Home',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
            )
          : null,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: navigate,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(icon: Icon(item.$3), label: item.$2),
              ],
            ),
      floatingActionButton: showAdd
          ? FloatingActionButton(
              onPressed: () => openEntryEditor(context, ref, state),
              tooltip: 'Add transaction',
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
      body: desktop
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  extended: true,
                  minExtendedWidth: 206,
                  selectedIndex: primary ? selected : null,
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
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : SafeArea(bottom: false, child: content),
    );
  }
}
