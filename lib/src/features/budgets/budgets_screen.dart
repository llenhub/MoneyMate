import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});
  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider).requireValue;
    final now = DateTime.now();
    final period = Period.month(now, _offset);
    final currency = state.preferences.currency;
    final analytics = Analytics(state.ledger);
    final current = analytics.totals(period, currency);
    final previous = analytics.totals(Period.month(now, _offset - 1), currency);
    final budgets =
        state.ledger.budgets
            .where((b) => b.month == period.monthKey && b.currency == currency)
            .toList()
          ..sort((a, b) => (a.categoryId ?? '').compareTo(b.categoryId ?? ''));
    void edit([Budget? budget]) => editDialog<void>(
      context,
      budget == null ? 'New monthly budget' : 'Edit budget',
      _BudgetForm(state, period, budget),
    );
    return PageBody(
      title: 'Monthly budgets',
      subtitle: 'Track spending limits and compare your monthly activity.',
      action: FilledButton.icon(
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const Text('Set budget'),
      ),
      children: [
        Panel(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(() => _offset--),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(period.start),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(() => _offset++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (budgets.isEmpty)
          Panel(
            child: EmptyPanel(
              Icons.pie_chart_outline,
              'No budgets for this month',
              'Set an overall limit or a limit for a specific expense category in $currency.',
              action: TextButton(
                onPressed: edit,
                child: const Text('Create a budget'),
              ),
            ),
          ),
        AdaptiveGrid(
          minWidth: 300,
          children: [
            for (final budget in budgets)
              Builder(
                builder: (context) {
                  final spent = analytics.spent(budget, current);
                  final remaining = budget.amount - spent;
                  final prior = analytics.spent(budget, previous);
                  final color = Theme.of(context).colorScheme;
                  return Panel(
                    child: formFields([
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              analytics.categories[budget.categoryId]?.name ??
                                  'Overall spending',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit budget',
                            onPressed: () => edit(budget),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete budget',
                            onPressed: () async {
                              if (!await confirm(
                                    context,
                                    'Delete budget?',
                                    'Transactions for this month will stay in your ledger.',
                                    'Delete',
                                  ) ||
                                  !context.mounted) {
                                return;
                              }
                              await runAction(
                                context,
                                () => ref
                                    .read(financeProvider.notifier)
                                    .change(
                                      (ledger) => ledger.copy(
                                        budgets: ledger.budgets.where(
                                          (b) => b.id != budget.id,
                                        ),
                                      ),
                                      expectedDemo: state.preferences.demo,
                                    ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      Text(
                        '${money(spent, currency)} of ${money(budget.amount, currency)}',
                      ),
                      LinearProgressIndicator(
                        value: (spent / budget.amount).clamp(0.0, 1.0),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 8,
                        color: remaining < 0 ? color.error : color.primary,
                      ),
                      Text(
                        remaining < 0
                            ? 'Over budget by ${money(-remaining, currency)}'
                            : '${money(remaining, currency)} remaining',
                        style: TextStyle(
                          color: remaining < 0 ? color.error : color.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Previous month · ${money(prior, currency)}'),
                    ]),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm(this.state, this.period, this.budget);
  final FinanceState state;
  final Period period;
  final Budget? budget;
  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  String get _currency => widget.state.preferences.currency;
  late final _amount = TextEditingController(
    text: widget.budget == null
        ? ''
        : decimalMoney(widget.budget!.amount, _currency),
  );
  late var _category = widget.budget?.categoryId ?? '';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => formFields([
    Choice('Scope', _category, {
      '': 'Overall spending',
      for (final c in widget.state.ledger.categories)
        if (c.type == EntryType.expense &&
            (!c.archived || c.id == widget.budget?.categoryId))
          c.id: c.name,
    }, (id) => setState(() => _category = id)),
    TextField(
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Monthly limit · $_currency'),
    ),
    if (_error != null)
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    FilledButton(
      onPressed: _busy
          ? null
          : () async {
              final amount = parseMoney(_amount.text, _currency);
              if (amount == null || amount <= 0) {
                setState(() => _error = 'Enter a positive monthly limit.');
                return;
              }
              setState(() {
                _busy = true;
                _error = null;
              });
              final old = widget.budget;
              final budget = Budget(
                old?.id ?? newId(),
                _currency,
                widget.period.monthKey,
                amount,
                old?.created ?? DateTime.now().toUtc(),
                categoryId: _category.isEmpty ? null : _category,
              );
              try {
                await ref
                    .read(financeProvider.notifier)
                    .change(
                      (ledger) => ledger.copy(
                        budgets: [
                          ...ledger.budgets.where((b) => b.id != budget.id),
                          budget,
                        ],
                      ),
                      expectedDemo: widget.state.preferences.demo,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (mounted) {
                  setState(() {
                    _busy = false;
                    _error = error.toString();
                  });
                }
              }
            },
      child: const Text('Save budget'),
    ),
  ]);
}
