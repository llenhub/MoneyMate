import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';

Future<void> openEntryEditor(
  BuildContext context,
  WidgetRef ref,
  FinanceState state, {
  Entry? entry,
}) => editDialog<void>(
  context,
  entry == null ? 'New transaction' : 'Edit transaction',
  _EntryForm(state, entry),
);

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
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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
        '${wallet.name} · ${dateLabel(entry.date, state.preferences.dateFormat)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        money(
          entry.type == EntryType.expense ? -entry.amount : entry.amount,
          wallet.currency,
        ),
        style: const TextStyle(fontWeight: FontWeight.w700),
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
                  'Balances and reports will be recalculated.',
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
  String _category = '', _type = '', _query = '';
  bool _newest = true;
  Period? _period;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider).requireValue;
    final ledger = state.ledger;
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
                  (_period?.contains(entry.date) ?? true) &&
                  entry.description.toLowerCase().contains(
                    _query.trim().toLowerCase(),
                  ),
            )
            .toList()
          ..sort(
            (a, b) =>
                _newest ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
          );
    return PageBody(
      title: 'Transactions',
      subtitle: 'Search and review activity across your wallets.',
      children: [
        Panel(
          child: formFields([
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
                Choice(
                  'Wallet',
                  ledger.wallet(_wallet) == null ? '' : _wallet,
                  {
                    '': 'All wallets',
                    for (final wallet in ledger.wallets) wallet.id: wallet.name,
                  },
                  (value) => setState(() => _wallet = value),
                ),
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
        ),
        const SizedBox(height: 14),
        Panel(
          child: entries.isEmpty
              ? EmptyPanel(
                  Icons.receipt_long_outlined,
                  ledger.entries.isEmpty
                      ? 'No transactions yet'
                      : 'No matching transactions',
                  ledger.entries.isEmpty
                      ? 'Use the add button to record your first transaction.'
                      : 'Try a different search or filter.',
                )
              : Column(
                  children: [
                    for (final (index, entry) in entries.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      EntryRow(
                        entry,
                        state,
                        onTap: () =>
                            showEntryDetails(context, ref, state, entry),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm(this.state, this.entry);
  final FinanceState state;
  final Entry? entry;
  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  Ledger get _ledger => widget.state.ledger;
  late var _type = widget.entry?.type ?? EntryType.expense;
  late var _wallet =
      widget.entry?.walletId ??
      _ledger.wallets.firstWhere((w) => !w.archived).id;
  late var _destination = widget.entry?.destinationId ?? '';
  late var _category = widget.entry?.categoryId ?? '';
  late var _date = widget.entry?.date ?? DateTime.now();
  late final _amount = TextEditingController(
    text: widget.entry == null
        ? ''
        : decimalMoney(widget.entry!.amount, _ledger.wallet(_wallet)!.currency),
  );
  late final _description = TextEditingController(
    text: widget.entry?.description,
  );
  late final _notes = TextEditingController(text: widget.entry?.notes);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text, _ledger.wallet(_wallet)!.currency);
    if (amount == null ||
        amount <= 0 ||
        (_type == EntryType.transfer
            ? _destination.isEmpty
            : _category.isEmpty)) {
      setState(
        () => _error =
            'Enter a positive amount and select ${_type == EntryType.transfer ? 'a destination wallet' : 'a category'}.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final previous = widget.entry;
    final now = DateTime.now().toUtc();
    final entry = Entry(
      previous?.id ?? newId(),
      _type,
      amount,
      _wallet,
      _date,
      previous?.created ?? now,
      now,
      destinationId: _type == EntryType.transfer ? _destination : null,
      categoryId: _type == EntryType.transfer ? null : _category,
      description: _description.text.trim(),
      notes: _notes.text.trim(),
    );
    try {
      await ref
          .read(financeProvider.notifier)
          .change(
            (data) => data.copy(
              entries: [
                for (final item in data.entries)
                  if (item.id == entry.id) entry else item,
                if (previous == null) entry,
              ],
            ),
            expectedDemo: widget.state.preferences.demo,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _ledger.wallet(_wallet)!;
    final walletOptions = {
      for (final w in _ledger.wallets)
        if ((!w.archived || w.id == widget.entry?.walletId) &&
            (_type != EntryType.transfer || w.type != WalletType.credit))
          w.id: w.name,
    };
    final destinationOptions = {
      for (final w in _ledger.wallets)
        if (w.id != _wallet &&
            w.currency == source.currency &&
            (!w.archived || w.id == widget.entry?.destinationId))
          w.id: w.name,
    };
    final categories = {
      for (final category in _ledger.categories)
        if (category.type == _type &&
            (!category.archived || category.id == widget.entry?.categoryId))
          category.id: category.name,
    };
    return formFields([
      Choice(
        'Type',
        _type,
        {for (final type in EntryType.values) type: titleCase(type.name)},
        (value) => setState(() {
          _type = value;
          _category = '';
          _destination = '';
        }),
      ),
      Choice(
        _type == EntryType.transfer ? 'From wallet' : 'Wallet',
        _wallet,
        walletOptions,
        (value) => setState(() {
          _wallet = value;
          _destination = '';
        }),
      ),
      if (_type == EntryType.transfer) ...[
        Choice(
          'To wallet',
          _destination,
          destinationOptions,
          (value) => setState(() => _destination = value),
        ),
        if (destinationOptions.isEmpty || walletOptions.isEmpty)
          const Text(
            'Transfers need a non-credit source and another wallet in the same currency.',
          ),
      ] else
        Choice(
          'Category',
          _category,
          categories,
          (value) => setState(() => _category = value),
        ),
      if (_type == EntryType.income && source.type == WalletType.credit)
        const Text('Credit-card refunds or adjustments reduce debt.'),
      TextField(
        controller: _amount,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Amount · ${source.currency}'),
      ),
      TextField(
        controller: _description,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Description (optional)'),
      ),
      TextField(
        controller: _notes,
        maxLines: 2,
        maxLength: 800,
        decoration: const InputDecoration(labelText: 'Notes (optional)'),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (date != null && mounted) {
                setState(
                  () => _date = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    _date.hour,
                    _date.minute,
                  ),
                );
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(dateLabel(_date, widget.state.preferences.dateFormat)),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_date),
              );
              if (time != null && mounted) {
                setState(
                  () => _date = DateTime(
                    _date.year,
                    _date.month,
                    _date.day,
                    time.hour,
                    time.minute,
                  ),
                );
              }
            },
            icon: const Icon(Icons.schedule),
            label: Text(TimeOfDay.fromDateTime(_date).format(context)),
          ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      FilledButton(
        onPressed: _busy || !walletOptions.containsKey(_wallet) ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save transaction'),
      ),
    ]);
  }
}
