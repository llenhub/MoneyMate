import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../core/reporting.dart';
import '../../data/state.dart';
import '../../ui/editor_page.dart';
import '../../ui/shared.dart';
import 'labels.dart';

Future<void> editBudget(
  BuildContext context,
  Preferences preferences, {
  Budget? budget,
}) => openEditorPage<void>(context, _BudgetEditor(preferences, budget));

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor(this.preferences, this.budget);
  final Preferences preferences;
  final Budget? budget;
  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  late final _name = TextEditingController(text: widget.budget?.name);
  late final _amount = TextEditingController(
    text: widget.budget == null
        ? ''
        : decimalMoney(widget.budget!.amount, widget.budget!.currency),
  );
  late var _currency = widget.budget?.currency ?? widget.preferences.currency;
  late var _cadence = widget.budget?.cadence ?? BudgetCadence.monthly;
  late var _anchor = widget.budget == null
      ? localDay(DateTime.now())
      : budgetPeriod(widget.budget!).start;
  late var _customEnd = widget.budget == null
      ? _anchor
      : shiftDay(budgetPeriod(widget.budget!).end, -1);
  late var _category = widget.budget?.categoryId ?? '';
  late var _wallet = widget.budget?.walletId ?? '';
  late var _label = widget.budget?.labelId ?? '';
  late var _overspent = widget.budget?.notifyOverspent ?? false;
  late var _risk = widget.budget?.notifyRisk ?? false;
  bool _busy = false;
  String? _error;

  Period get _period => switch (_cadence) {
    BudgetCadence.weekly => Period.week(_anchor),
    BudgetCadence.monthly => Period.month(_anchor),
    BudgetCadence.yearly => Period.year(_anchor),
    BudgetCadence.custom => Period(_anchor, shiftDay(_customEnd, 1)),
  };

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(financeProvider).requireValue.ledger;
    final period = _period;
    return EditorPage(
      title: widget.budget == null ? 'New Budget' : 'Edit Budget',
      onSave: _save,
      busy: _busy,
      error: _error,
      children: [
        TextField(
          controller: _name,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Budget name (optional)',
          ),
        ),
        Choice('Period', _cadence, {
          for (final item in BudgetCadence.values) item: titleCase(item.name),
        }, (value) => setState(() => _cadence = value)),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            '${dateLabel(period.start, widget.preferences.dateFormat)} to '
            '${dateLabel(shiftDay(period.end, -1), widget.preferences.dateFormat)}',
          ),
          onPressed: _pickDates,
        ),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Budget limit'),
        ),
        Choice(
          'Currency',
          _currency,
          {for (final code in currencies) code: code},
          (value) => setState(() {
            _currency = value;
            _wallet = '';
          }),
        ),
        Choice('Category', _category, {
          '': 'All categories',
          for (final item in ledger.categories)
            if (item.type == EntryType.expense &&
                (!item.archived || item.id == _category))
              item.id: item.name,
        }, (value) => setState(() => _category = value)),
        Choice('Account', _wallet, {
          '': 'All accounts in $_currency',
          for (final item in ledger.wallets)
            if (item.currency == _currency &&
                (!item.archived || item.id == _wallet))
              item.id: item.name,
        }, (value) => setState(() => _wallet = value)),
        OutlinedButton.icon(
          icon: const Icon(Icons.sell_outlined),
          label: Text(
            ledger.label(_label)?.name ?? 'All labels · Select or add',
          ),
          onPressed: () async {
            final selected = await pickLabels(
              context,
              {_label}..remove(''),
              single: true,
            );
            if (selected != null && mounted) {
              setState(() => _label = selected.firstOrNull ?? '');
            }
          },
        ),
        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
        const Text('Alerts appear on this budget in Planning.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Budget Overspent'),
          subtitle: const Text(
            'Show an alert when spending exceeds the budget.',
          ),
          value: _overspent,
          onChanged: (value) => setState(() => _overspent = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Risk of Overspending'),
          subtitle: const Text(
            'Show an alert when spending is projected to exceed the limit.',
          ),
          value: _risk,
          onChanged: (value) => setState(() => _risk = value),
        ),
      ],
    );
  }

  Future<void> _pickDates() async {
    if (_cadence == BudgetCadence.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
        initialDateRange: DateTimeRange(start: _anchor, end: _customEnd),
      );
      if (range != null && mounted) {
        setState(() {
          _anchor = range.start;
          _customEnd = range.end;
        });
      }
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date != null && mounted) {
      setState(() {
        _anchor = date;
        if (_customEnd.isBefore(date)) _customEnd = date;
      });
    }
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text, _currency);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive amount for $_currency.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = widget.budget;
    final period = _period;
    final budget = Budget(
      old?.id ?? newId(),
      _currency,
      period.monthKey,
      amount,
      old?.created ?? DateTime.now().toUtc(),
      categoryId: _category.isEmpty ? null : _category,
      walletId: _wallet.isEmpty ? null : _wallet,
      labelId: _label.isEmpty ? null : _label,
      name: _name.text.trim(),
      cadence: _cadence,
      start: period.start,
      end: period.end,
      notifyOverspent: _overspent,
      notifyRisk: _risk,
    );
    try {
      await ref
          .read(financeProvider.notifier)
          .change(
            (ledger) => ledger.copy(
              budgets: [
                for (final item in ledger.budgets)
                  item.id == budget.id ? budget : item,
                if (old == null) budget,
              ],
            ),
            expectedDemo: widget.preferences.demo,
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
}
