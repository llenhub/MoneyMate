import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../core/reporting.dart';
import '../../data/state.dart';
import '../../ui/report_widgets.dart';
import '../../ui/shared.dart';
import '../transactions/transactions_screen.dart';
import '../wallets/wallets_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _category;
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider).requireValue;
    final ledger = finance.ledger;
    final analytics = Analytics(ledger);
    final now = DateTime.now();
    final wallets = ledger.wallets.where((wallet) => !wallet.archived).toList();
    final account = activeAccount(ledger, ref.watch(homeAccountProvider));
    final balances = analytics.balances();
    final currency = _currency ?? finance.preferences.currency;
    final expenses = analytics.expenses(
      ReportRange.month.period(now),
      currency,
    );
    final records = ledger.entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 44,
                        vertical: 10,
                      ),
                      child: Text(
                        'MoneyMate',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: PopupMenuButton<String>(
                        tooltip: 'MoneyMate options',
                        onSelected: (route) => context.go(route),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: '/wallets',
                            child: Text('Manage accounts'),
                          ),
                          PopupMenuItem(
                            value: '/assistant',
                            child: Text('AI Assistant'),
                          ),
                          PopupMenuItem(
                            value: '/settings',
                            child: Text('Settings'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'List of Accounts',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/wallets'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 115,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      if (index == wallets.length) {
                        return SizedBox(
                          width: 125,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () => openWalletEditor(context, finance),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add),
                                SizedBox(height: 6),
                                Text(
                                  'Add Account',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final wallet = wallets[index];
                      final selected = wallet.id == account?.id;
                      return SizedBox(
                        width: 172,
                        child: Semantics(
                          selected: selected,
                          button: true,
                          child: Material(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: selected
                                    ? Colors.transparent
                                    : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => ref
                                  .read(homeAccountProvider.notifier)
                                  .select(wallet.id),
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: DefaultTextStyle.merge(
                                  style: TextStyle(
                                    color: selected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        namedIcon(wallet.icon),
                                        size: 20,
                                        color: selected
                                            ? theme.colorScheme.onPrimary
                                            : Color(wallet.color),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        wallet.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          money(
                                            balances[wallet.id]!,
                                            wallet.currency,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (account != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _accountDetails(
                        context,
                        finance,
                        account,
                        balances[account.id]!,
                      ),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Account details'),
                    ),
                  ),
                const SizedBox(height: 18),
                ReportSection(
                  title: 'Expenses Structure',
                  subtitle: 'Last 30 days · $currency',
                  action: PopupMenuButton<String>(
                    tooltip: 'Expenses options',
                    onSelected: (value) => setState(() {
                      _category = null;
                      if (value != 'clear') _currency = value;
                    }),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear category selection'),
                      ),
                      for (final item in currencies.where(
                        (code) =>
                            code == finance.preferences.currency ||
                            ledger.wallets.any(
                              (wallet) => wallet.currency == code,
                            ),
                      ))
                        PopupMenuItem(
                          value: item,
                          child: Text('Report in $item'),
                        ),
                    ],
                  ),
                  child: SpendingDonut(
                    slices: categorySlices(ledger, expenses),
                    currency: currency,
                    selected: _category,
                    onSelect: (id) => setState(() => _category = id),
                  ),
                  onMore: () => context.go('/statistics'),
                ),
                const SizedBox(height: 14),
                ReportSection(
                  title: 'Last Records Overview',
                  child: records.isEmpty
                      ? const EmptyPanel(
                          Icons.receipt_long_outlined,
                          'No records yet',
                          'Add your first income, expense, or transfer.',
                        )
                      : Column(
                          children: [
                            for (final entry in records.take(5))
                              EntryRow(
                                entry,
                                finance,
                                onTap: () => showEntryDetails(
                                  context,
                                  ref,
                                  finance,
                                  entry,
                                ),
                              ),
                          ],
                        ),
                  onMore: () => context.go('/records'),
                ),
                const SizedBox(height: 14),
                ReportSection(
                  title: 'Balance Trend',
                  subtitle: account == null
                      ? null
                      : '${account.name} · Last 30 days',
                  child: account == null
                      ? const EmptyPanel(
                          Icons.show_chart,
                          'Choose an account',
                          'Add an account to see its balance over time.',
                        )
                      : TrendChart(
                          analytics.balanceHistory(
                            account,
                            ReportRange.month.buckets(now),
                          ),
                          account.currency,
                        ),
                  onMore: () => context.go('/statistics?view=balance'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _accountDetails(
  BuildContext context,
  FinanceState finance,
  Wallet wallet,
  int balance,
) => editDialog<void>(
  context,
  wallet.name,
  Builder(
    builder: (dialog) => formFields([
      Text(wallet.type.label),
      Text(
        money(balance, wallet.currency),
        style: Theme.of(dialog).textTheme.headlineSmall,
      ),
      if (wallet.limit != null)
        Text('Credit limit · ${money(wallet.limit!, wallet.currency)}'),
      FilledButton.tonal(
        onPressed: () {
          Navigator.pop(dialog);
          openWalletEditor(context, finance, wallet: wallet);
        },
        child: const Text('Edit account'),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(dialog);
          context.go(
            Uri(
              path: '/records',
              queryParameters: {'wallet': wallet.id},
            ).toString(),
          );
        },
        child: const Text('View records'),
      ),
    ]),
  ),
);
