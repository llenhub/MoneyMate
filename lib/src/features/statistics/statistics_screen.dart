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

final _spendingRange = NotifierProvider<_SpendingRange, ReportRange>(
  _SpendingRange.new,
);
final _balanceRange = NotifierProvider<_BalanceRange, ReportRange>(
  _BalanceRange.new,
);

class _SpendingRange extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.week;
  void select(ReportRange value) => state = value;
}

class _BalanceRange extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.month;
  void select(ReportRange value) => state = value;
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({this.balance = false, super.key});
  final bool balance;
  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String? _currency, _group, _individualLabel, _account;
  bool _byLabel = false;
  SpendingNature? _nature;

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider).requireValue;
    final analytics = Analytics(finance.ledger);
    final range = ref.watch(widget.balance ? _balanceRange : _spendingRange);
    final now = DateTime.now();
    return PageBody(
      title: 'Statistics',
      subtitle: 'See what moved your money.',
      children: formFields([
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Spending'),
              icon: Icon(Icons.donut_large),
            ),
            ButtonSegment(
              value: true,
              label: Text('Balance'),
              icon: Icon(Icons.show_chart),
            ),
          ],
          selected: {widget.balance},
          onSelectionChanged: (selection) => context.go(
            selection.single ? '/statistics?view=balance' : '/statistics',
          ),
        ),
        DateRangeSelector(range, (value) {
          if (widget.balance) {
            ref.read(_balanceRange.notifier).select(value);
          } else {
            ref.read(_spendingRange.notifier).select(value);
            setState(() => _group = null);
          }
        }),
        ...(widget.balance
            ? _balance(context, finance, analytics, range, now)
            : _spending(context, finance, analytics, range, now)),
      ]).children,
    );
  }

  List<Widget> _spending(
    BuildContext context,
    FinanceState finance,
    Analytics analytics,
    ReportRange range,
    DateTime now,
  ) {
    final ledger = finance.ledger;
    final currency = _currency ?? finance.preferences.currency;
    final entries = analytics.expenses(range.period(now), currency).toList();
    final label = ledger.label(_individualLabel);
    final grouped = !_byLabel
        ? categorySlices(ledger, entries)
        : _labelSlices(ledger, entries);
    final group = grouped.any((item) => item.id == _group) ? _group : null;
    final selected = entries.where((entry) {
      if (_byLabel && label != null) return entry.labelIds.contains(label.id);
      return group == null ||
          (_byLabel ? labelGroup(entry) : entry.categoryId) == group;
    }).toList();
    final points = [
      for (final bucket in range.buckets(now))
        (
          date: shiftDay(bucket.end, -1),
          value: sumEntries(
            selected.where((entry) => bucket.contains(entry.date)),
          ),
        ),
    ];
    final byNature = _nature == null
        ? entries
        : entries.where((entry) => entry.nature == _nature);
    final natureColors = [
      const Color(0xff4865ab),
      const Color(0xff087c89),
      const Color(0xffad613b),
    ];
    return [
      Choice(
        'Reporting currency',
        currency,
        {
          for (final code in currencies)
            if (code == currency ||
                code == finance.preferences.currency ||
                ledger.wallets.any((wallet) => wallet.currency == code))
              code: code,
        },
        (value) => setState(() {
          _currency = value;
          _group = null;
        }),
      ),
      ReportSection(
        title: 'Spending by Categories or Labels',
        subtitle: range.label,
        child: formFields([
          Text(
            money(sumEntries(entries), currency),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            selected: {_byLabel},
            segments: const [
              ButtonSegment(value: false, label: Text('Categories')),
              ButtonSegment(value: true, label: Text('Labels')),
            ],
            onSelectionChanged: (value) => setState(() {
              _byLabel = value.single;
              _group = null;
              _individualLabel = null;
            }),
          ),
          if (_byLabel && ledger.labels.isNotEmpty) ...[
            const Text(
              'Each expense appears once in the donut. Expenses with several labels share the Multiple labels slice.',
            ),
            Choice(
              'Filter by individual label',
              label?.id ?? '',
              {
                '': 'All labels',
                for (final item in ledger.labels) item.id: item.name,
              },
              (value) => setState(() {
                _individualLabel = value;
                _group = null;
              }),
            ),
          ],
          SpendingDonut(
            slices: grouped,
            currency: currency,
            selected: group,
            onSelect: (value) => setState(() {
              _group = value;
              _individualLabel = null;
            }),
          ),
          Text(
            'Spending Trend',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (label != null)
            Text('${label.name} · ${money(sumEntries(selected), currency)}'),
          TrendChart(
            selected.isEmpty ? [] : points,
            currency,
            label: 'No spending in this selection',
          ),
          Text(
            'Top 5 Expenses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _topExpenses(context, finance, selected),
        ]),
      ),
      ReportSection(
        title: 'The Nature of Spending',
        subtitle: range.label,
        child: formFields([
          Text(
            money(sumEntries(byNature), currency),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _nature == null,
                onSelected: (_) => setState(() => _nature = null),
              ),
              for (final nature in SpendingNature.values)
                ChoiceChip(
                  label: Text(titleCase(nature.name)),
                  selected: _nature == nature,
                  onSelected: (_) => setState(() => _nature = nature),
                ),
            ],
          ),
          if (_nature == null)
            for (final (index, nature) in [
              ...SpendingNature.values,
              null,
            ].indexed)
              _comparison(
                context,
                nature == null ? 'Unclassified' : titleCase(nature.name),
                sumEntries(entries.where((entry) => entry.nature == nature)),
                currency,
                sumEntries(entries),
                index == 3 ? Colors.blueGrey : natureColors[index],
              ),
          if (_nature != null) ...[
            for (final item in categorySlices(ledger, byNature).take(5))
              _comparison(
                context,
                item.name,
                item.value,
                currency,
                sumEntries(byNature),
                item.color,
              ),
            Text(
              'Largest ${_nature!.name} expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _topExpenses(context, finance, byNature),
          ],
        ]),
      ),
    ];
  }

  Widget _topExpenses(
    BuildContext context,
    FinanceState finance,
    Iterable<Entry> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (sorted.isEmpty) return const Text('No expenses match this selection.');
    return Column(
      children: [
        for (final entry in sorted.take(5))
          EntryRow(
            entry,
            finance,
            onTap: () => showEntryDetails(context, ref, finance, entry),
          ),
      ],
    );
  }

  List<Widget> _balance(
    BuildContext context,
    FinanceState finance,
    Analytics analytics,
    ReportRange range,
    DateTime now,
  ) {
    final ledger = finance.ledger;
    final account = activeAccount(
      ledger,
      _account ?? ref.watch(homeAccountProvider),
      includeArchived:
          _account != null || ledger.wallets.every((wallet) => wallet.archived),
    );
    final balances = analytics.balances();
    final currencyBalances = analytics.balancesByCurrency();
    return [
      ReportSection(
        title: 'Balance Trend',
        subtitle: range.label,
        child: account == null
            ? const EmptyPanel(
                Icons.account_balance_wallet_outlined,
                'No accounts yet',
                'Add an account from Home to view balance history.',
              )
            : formFields([
                Choice('Account', account.id, {
                  for (final wallet in ledger.wallets) wallet.id: wallet.name,
                }, (value) => setState(() => _account = value)),
                Text(
                  money(balances[account.id]!, account.currency),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                TrendChart(
                  analytics.balanceHistory(account, range.buckets(now)),
                  account.currency,
                ),
              ]),
      ),
      ReportSection(
        title: 'Balance by Accounts',
        onMore: () => context.go('/wallets'),
        moreLabel: 'Manage accounts',
        child: formFields([
          if (ledger.wallets.isEmpty) const Text('No accounts yet.'),
          for (final currency in currencyBalances.keys) ...[
            Text(currency, style: Theme.of(context).textTheme.titleMedium),
            for (final wallet in ledger.wallets.where(
              (item) => item.currency == currency,
            ))
              _comparison(
                context,
                wallet.name,
                balances[wallet.id]!,
                currency,
                ledger.wallets
                    .where((item) => item.currency == currency)
                    .map((item) => balances[item.id]!.abs())
                    .reduce((a, b) => a > b ? a : b),
                Color(wallet.color),
                onTap: () => context.go(
                  Uri(
                    path: '/records',
                    queryParameters: {'wallet': wallet.id},
                  ).toString(),
                ),
              ),
          ],
        ]),
      ),
      ReportSection(
        title: 'Balance by Currency',
        child: formFields([
          if (currencyBalances.isEmpty) const Text('No balances to group yet.'),
          for (final item in currencyBalances.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(item.key, style: const TextStyle(fontSize: 11)),
              ),
              title: Text(money(item.value, item.key)),
              subtitle: Text(
                '${ledger.wallets.where((wallet) => wallet.currency == item.key).length} accounts',
              ),
            ),
        ]),
      ),
    ];
  }
}

List<ReportSlice> _labelSlices(Ledger ledger, Iterable<Entry> entries) {
  final amounts = <String, int>{};
  for (final entry in entries) {
    amounts.update(
      labelGroup(entry),
      (value) => value + entry.amount,
      ifAbsent: () => entry.amount,
    );
  }
  return [
    for (final item in amounts.entries)
      (
        id: item.key,
        name: switch (item.key) {
          unlabeledGroup => 'Unlabeled',
          sharedLabelsGroup => 'Multiple labels',
          _ => ledger.label(item.key)?.name ?? 'Unknown label',
        },
        value: item.value,
        color: Color(
          ledger.label(item.key)?.color ??
              (item.key == sharedLabelsGroup ? 0xff5868a3 : 0xff65777b),
        ),
      ),
  ]..sort((a, b) => b.value.compareTo(a.value));
}

Widget _comparison(
  BuildContext context,
  String name,
  int amount,
  String currency,
  int reference,
  Color color, {
  VoidCallback? onTap,
}) => InkWell(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(name)),
            const SizedBox(width: 8),
            Text(
              money(amount, currency),
              style: TextStyle(
                color: amount < 0 ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
          value: reference == 0 ? 0 : (amount.abs() / reference).clamp(0, 1),
          color: amount < 0 ? Theme.of(context).colorScheme.error : color,
        ),
      ],
    ),
  ),
);
