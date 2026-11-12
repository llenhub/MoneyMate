import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../core/reporting.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';
import '../../ui/editor_page.dart';
import '../../ui/report_widgets.dart';
import 'entry_editor.dart';

Future<void> openEntryEditor(
  BuildContext context,
  WidgetRef ref,
  FinanceState state, {
  Entry? entry,
}) => openEditorPage<void>(context, EntryEditor(entry, state.preferences));

final _recordsRange = NotifierProvider<_RecordsRange, ReportRange>(
  _RecordsRange.new,
);

class _RecordsRange extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.month;
  void select(ReportRange range) => state = range;
}

class EntryRow extends StatelessWidget {
  const EntryRow(this.entry, this.state, {super.key, this.onTap});
  final Entry entry;
  final FinanceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final wallet = state.ledger.wallet(entry.walletId)!;
    final category = state.ledger.category(entry.categoryId);
    final label = entry.type == EntryType.transfer
        ? 'Transfer to ${state.ledger.wallet(entry.destinationId)?.name}'
        : category?.name ?? titleCase(entry.type.name);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: category == null
            ? Theme.of(context).colorScheme.secondaryContainer
            : categoryColor(state.ledger, category.id),
        foregroundColor: category == null ? null : Colors.white,
        child: Icon(
          entry.type == EntryType.transfer
              ? Icons.swap_horiz
              : namedIcon(category?.icon ?? 'category'),
          size: 19,
        ),
      ),
      title: Text(
        entry.description.isEmpty ? label : entry.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (entry.description.isNotEmpty) label,
          wallet.name,
          dateLabel(entry.date, state.preferences.dateFormat),
          ...entry.labelIds
              .map((id) => state.ledger.label(id)?.name)
              .whereType<String>(),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        (entry.type == EntryType.income ? '+' : '') +
            money(
              entry.type == EntryType.expense ? -entry.amount : entry.amount,
              wallet.currency,
            ),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: entry.type == EntryType.income
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

Future<void> showEntryDetails(
  BuildContext context,
  WidgetRef ref,
  FinanceState state,
  Entry entry,
) => editDialog<void>(
  context,
  'Transaction details',
  Builder(
    builder: (dialogContext) {
      final ledger = state.ledger;
      final wallet = ledger.wallet(entry.walletId)!;
      return formFields([
        Text(
          money(entry.amount, wallet.currency),
          style: Theme.of(dialogContext).textTheme.headlineSmall,
        ),
        Text(
          '${titleCase(entry.type.name)} · ${dateLabel(entry.date, state.preferences.dateFormat)} '
          '${TimeOfDay.fromDateTime(entry.date).format(dialogContext)}',
        ),
        Text(
          wallet.name +
              (entry.destinationId == null
                  ? ''
                  : ' to ${ledger.wallet(entry.destinationId)!.name}'),
        ),
        if (entry.categoryId != null)
          Text(ledger.category(entry.categoryId)!.name),
        if (entry.description.isNotEmpty) Text(entry.description),
        if (entry.notes.isNotEmpty) Text(entry.notes),
        if (entry.includedInBalance)
          const Text('Already included in my balance'),
        if (entry.nature != null) Text(titleCase(entry.nature!.name)),
        if (entry.labelIds.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (final id in entry.labelIds)
                if (ledger.label(id) case final LedgerLabel label)
                  Chip(
                    avatar: Icon(
                      namedIcon(label.icon),
                      color: Color(label.color),
                      size: 16,
                    ),
                    label: Text(label.name),
                  ),
            ],
          ),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(dialogContext);
                openEntryEditor(context, ref, state, entry: entry);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () async {
                if (!await confirm(
                  dialogContext,
                  'Delete transaction?',
                  entry.includedInBalance
                      ? 'Reports will be recalculated. Your current balance will stay the same.'
                      : 'Balances and reports will be recalculated.',
                  'Delete',
                )) {
                  return;
                }
                if (!dialogContext.mounted || !context.mounted) return;
                final controller = ref.read(financeProvider.notifier);
                await runAction(dialogContext, () async {
                  await controller.change(
                    (data) => data.copy(
                      entries: data.entries.where((e) => e.id != entry.id),
                    ),
                    expectedDemo: state.preferences.demo,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                });
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ]);
    },
  ),
);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.walletId});
  final String? walletId;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late String _wallet = widget.walletId ?? '';
  String _category = '', _type = '', _query = '', _label = '';
  bool _newest = true;
  Period? _period;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider).requireValue;
    final ledger = state.ledger;
    final range = ref.watch(_recordsRange);
    final period = _period ?? range.period(DateTime.now());
    final entries =
        ledger.entries
            .where(
              (entry) =>
                  (_wallet.isEmpty ||
                      ledger.wallet(_wallet) == null ||
                      entry.walletId == _wallet ||
                      entry.destinationId == _wallet) &&
                  (_category.isEmpty ||
                      ledger.category(_category) == null ||
                      entry.categoryId == _category) &&
                  (_type.isEmpty || entry.type.name == _type) &&
                  period.contains(entry.date) &&
                  (_label.isEmpty ||
                      ledger.label(_label) == null ||
                      entry.labelIds.contains(_label)) &&
                  entry.description.toLowerCase().contains(
                    _query.trim().toLowerCase(),
                  ),
            )
            .toList()
          ..sort(
            (a, b) =>
                _newest ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
          );
    final filters = Panel(
      child: formFields([
        DateRangeSelector(_period == null ? range : null, (value) {
          ref.read(_recordsRange.notifier).select(value);
          setState(() => _period = null);
        }),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search descriptions',
          ),
        ),
        AdaptiveGrid(
          minWidth: 165,
          children: [
            Choice('Wallet', ledger.wallet(_wallet) == null ? '' : _wallet, {
              '': 'All wallets',
              for (final wallet in ledger.wallets) wallet.id: wallet.name,
            }, (value) => setState(() => _wallet = value)),
            Choice(
              'Category',
              ledger.category(_category) == null ? '' : _category,
              {
                '': 'All categories',
                for (final category in ledger.categories)
                  category.id: category.name,
              },
              (value) => setState(() => _category = value),
            ),
            Choice('Type', _type, {
              '': 'All types',
              for (final type in EntryType.values)
                type.name: titleCase(type.name),
            }, (value) => setState(() => _type = value)),
            Choice('Label', ledger.label(_label)?.id ?? '', {
              '': 'All labels',
              for (final label in ledger.labels) label.id: label.name,
            }, (value) => setState(() => _label = value)),
            Choice('Order', _newest, {
              true: 'Newest first',
              false: 'Oldest first',
            }, (value) => setState(() => _newest = value)),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final dates = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year + 25),
                );
                if (dates != null && mounted) {
                  setState(
                    () => _period = Period(
                      dates.start,
                      DateTime(
                        dates.end.year,
                        dates.end.month,
                        dates.end.day + 1,
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.date_range),
              label: Text(
                _period == null
                    ? 'Filter by date'
                    : '${dateLabel(_period!.start, state.preferences.dateFormat)} – '
                          '${dateLabel(DateTime(_period!.end.year, _period!.end.month, _period!.end.day - 1), state.preferences.dateFormat)}',
              ),
            ),
            if (_period != null)
              TextButton(
                onPressed: () => setState(() => _period = null),
                child: const Text('Clear dates'),
              ),
          ],
        ),
      ]),
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
          sliver: SliverToBoxAdapter(
            child: _recordWidth(
              formFields([
                Text(
                  'Records',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                filters,
              ]),
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _recordWidth(
                Panel(
                  child: EmptyPanel(
                    Icons.receipt_long_outlined,
                    ledger.entries.isEmpty
                        ? 'No records yet'
                        : 'No matching records',
                    ledger.entries.isEmpty
                        ? 'Add an income, expense, or transfer.'
                        : 'Try a different date range or filter.',
                  ),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final newDay =
                  index == 0 ||
                  localDay(entries[index - 1].date) != localDay(entry.date);
              return _recordWidth(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (newDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 3),
                        child: Text(
                          dateLabel(entry.date, state.preferences.dateFormat),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    EntryRow(
                      entry,
                      state,
                      onTap: () => showEntryDetails(context, ref, state, entry),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _recordWidth(Widget child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 920),
    child: SizedBox(width: double.infinity, child: child),
  ),
);
