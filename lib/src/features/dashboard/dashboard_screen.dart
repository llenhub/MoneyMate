import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';
import '../transactions/transactions_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _period = 'This month';
  Period? _custom;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider).requireValue;
    final ledger = state.ledger;
    final analytics = Analytics(ledger);
    final now = DateTime.now();
    final period = switch (_period) {
      'This week' => Period.week(now),
      'Last month' => Period.month(now, -1),
      'This year' => Period.year(now),
      'Custom range' => _custom ?? Period.month(now),
      _ => Period.month(now),
    };
    final currency = state.preferences.currency;
    final totals = analytics.totals(period, currency);
    final balances = analytics.balances();
    final wallets = ledger.wallets
        .where((wallet) => wallet.currency == currency)
        .toList();
    final available = wallets
        .where((w) => w.type != WalletType.credit)
        .fold(0, (total, wallet) => total + balances[wallet.id]!);
    final debt = wallets
        .where((w) => w.type == WalletType.credit && balances[w.id]! < 0)
        .fold(0, (total, wallet) => total - balances[wallet.id]!);
    final recent =
        ledger.entries
            .where(
              (entry) =>
                  analytics.wallets[entry.walletId]?.currency == currency &&
                  period.contains(entry.date),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final spending = totals.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trendPeriods = [
      for (var i = -5; i <= 0; i++)
        Period.month(period.end.subtract(const Duration(hours: 12)), i),
    ];
    final trends = [
      for (final month in trendPeriods) analytics.totals(month, currency),
    ];
    final chartLabels = [
      for (final month in trendPeriods) DateFormat.MMM().format(month.start),
    ];
    final color = Theme.of(context).colorScheme;
    return PageBody(
      title: 'Overview',
      subtitle: 'Your balances, spending, and cash flow in $currency.',
      action: SizedBox(
        width: 192,
        child: Choice(
          'Reporting period',
          _period,
          {
            for (final value in [
              'This week',
              'This month',
              'Last month',
              'This year',
              'Custom range',
            ])
              value: value,
          },
          (value) async {
            if (value != 'Custom range') {
              setState(() => _period = value);
              return;
            }
            final dates = await showDateRangePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (dates != null && mounted) {
              setState(() {
                _custom = Period(
                  dates.start,
                  DateTime(dates.end.year, dates.end.month, dates.end.day + 1),
                );
                _period = value;
              });
            }
          },
        ),
      ),
      children: [
        if (_period == 'Custom range')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${dateLabel(period.start, state.preferences.dateFormat)} – '
              '${dateLabel(DateTime(period.end.year, period.end.month, period.end.day - 1), state.preferences.dateFormat)}',
            ),
          ),
        AdaptiveGrid(
          minWidth: 240,
          children: [
            _Metric(
              'Available balance',
              money(available, currency),
              Icons.account_balance_wallet_outlined,
              featured: true,
            ),
            _Metric(
              'Credit card debt',
              money(debt, currency),
              Icons.credit_card_outlined,
            ),
            _Metric(
              'Net cash flow',
              money(totals.net, currency),
              Icons.swap_vert,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          minWidth: 158,
          children: [
            _Metric(
              'Period income',
              money(totals.income, currency),
              Icons.south_west,
            ),
            _Metric(
              'Period expenses',
              money(totals.expense, currency),
              Icons.north_east,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          minWidth: 365,
          children: [
            Panel(
              title: 'Spending by category',
              child: spending.isEmpty
                  ? const EmptyPanel(
                      Icons.donut_large,
                      'No spending this period',
                      'Expense categories will appear here as you add transactions.',
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 170,
                          child: PieChart(
                            PieChartData(
                              centerSpaceRadius: 52,
                              sectionsSpace: 3,
                              sections: [
                                for (final (i, item) in spending.indexed)
                                  PieChartSectionData(
                                    color: _categoryColor(
                                      analytics,
                                      item.key,
                                      i,
                                    ),
                                    value: item.value.toDouble(),
                                    radius: 23,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        for (final (i, item) in spending.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: _categoryColor(analytics, item.key, i),
                                  size: 11,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    analytics.categories[item.key]!.name,
                                  ),
                                ),
                                Text(money(item.value, currency)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Panel(
              title: 'Monthly expenses',
              child: trends.every((item) => item.expense == 0)
                  ? const EmptyPanel(
                      Icons.bar_chart,
                      'No monthly expenses',
                      'The six-month trend will appear after you log expenses.',
                    )
                  : SizedBox(
                      height: 230,
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          borderData: FlBorderData(show: false),
                          titlesData: _titles(chartLabels, currency),
                          gridData: const FlGridData(drawVerticalLine: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                                '${chartLabels[group.x]}\n${money(rod.toY.round(), currency)}',
                                const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          barGroups: [
                            for (final (i, item) in trends.indexed)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: item.expense.toDouble(),
                                    width: 14,
                                    color: color.primary,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          minWidth: 365,
          children: [
            Panel(
              title: 'Income and expense trend',
              child:
                  trends.every((item) => item.income == 0 && item.expense == 0)
                  ? const EmptyPanel(
                      Icons.show_chart,
                      'No cash flow history',
                      'Record income or expenses to see monthly movement.',
                    )
                  : Column(
                      children: [
                        Wrap(
                          spacing: 18,
                          children: [
                            for (final (label, shade) in [
                              ('Income', color.primary),
                              ('Expenses', color.tertiary),
                            ])
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: shade, size: 10),
                                  const SizedBox(width: 6),
                                  Text(label),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 210,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              minX: 0,
                              maxX: 5,
                              titlesData: _titles(chartLabels, currency),
                              gridData: const FlGridData(
                                drawVerticalLine: false,
                              ),
                              borderData: FlBorderData(show: false),
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (points) => [
                                    for (final point in points)
                                      LineTooltipItem(
                                        money(point.y.round(), currency),
                                        const TextStyle(color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                              lineBarsData: [
                                for (final (shade, income) in [
                                  (color.primary, true),
                                  (color.tertiary, false),
                                ])
                                  LineChartBarData(
                                    color: shade,
                                    barWidth: 3,
                                    spots: [
                                      for (final (i, item) in trends.indexed)
                                        FlSpot(
                                          i.toDouble(),
                                          (income ? item.income : item.expense)
                                              .toDouble(),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Panel(
              title: 'Wallet balances',
              child: wallets.isEmpty
                  ? EmptyPanel(
                      Icons.wallet_outlined,
                      'No $currency wallets',
                      'Create a wallet or change your reporting currency.',
                      action: TextButton(
                        onPressed: () => context.go('/wallets'),
                        child: const Text('Manage wallets'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final wallet in wallets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              namedIcon(wallet.icon),
                              color: Color(wallet.color),
                            ),
                            title: Text(wallet.name),
                            subtitle: Text(
                              '${wallet.type.label}${wallet.archived ? ' · Archived' : ''}',
                            ),
                            trailing: Text(
                              money(
                                wallet.type == WalletType.credit
                                    ? -balances[wallet.id]!
                                    : balances[wallet.id]!,
                                currency,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Recent transactions',
          child: recent.isEmpty
              ? const EmptyPanel(
                  Icons.receipt_long_outlined,
                  'No transactions this period',
                  'Your most recent activity will appear here.',
                )
              : Column(
                  children: [
                    for (final entry in recent.take(5))
                      EntryRow(
                        entry,
                        state,
                        onTap: () =>
                            showEntryDetails(context, ref, state, entry),
                      ),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: const Text('View all transactions'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Color _categoryColor(Analytics analytics, String id, int index) =>
      Color(analytics.categories[id]?.color ?? palette[index % palette.length]);

  FlTitlesData _titles(List<String> labels, String currency) => FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 47,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Text(
            NumberFormat.compact(
              locale: 'en',
            ).format(value / (fractionDigits(currency) == 0 ? 1 : 100)),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: 24,
        getTitlesWidget: (value, meta) =>
            value < 0 || value >= labels.length || value != value.round()
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  labels[value.toInt()],
                  style: const TextStyle(fontSize: 10),
                ),
              ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, {this.featured = false});
  final String label, value;
  final IconData icon;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 9),
            Flexible(child: Text(label)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: featured ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    return featured
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [ink, Color(0xff276a51)]),
            ),
            child: Padding(
              padding: const EdgeInsets.all(19),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: mint),
                child: IconTheme.merge(
                  data: const IconThemeData(color: mint),
                  child: child,
                ),
              ),
            ),
          )
        : Panel(child: child);
  }
}
