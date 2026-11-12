import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../core/reporting.dart';
import '../../data/state.dart';
import '../../ui/editor_page.dart';
import '../../ui/report_widgets.dart';
import '../../ui/shared.dart';
import '../transactions/transactions_screen.dart';
import 'budget_editor.dart';
import 'goals.dart';
import 'labels.dart';

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider).requireValue;
    final ledger = finance.ledger;
    final analytics = Analytics(ledger);
    final now = DateTime.now();
    return PageBody(
      title: 'Planning',
      subtitle: 'Set limits and save for what matters.',
      children: formFields([
        ReportSection(
          title: 'Budgets',
          subtitle: 'How much can I spend?',
          child: formFields([
            if (ledger.budgets.isEmpty) const Text('No budgets yet.'),
            for (final cadence in BudgetCadence.values)
              if (ledger.budgets.any((item) => item.cadence == cadence)) ...[
                Text(
                  titleCase(cadence.name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final budget in ledger.budgets.where(
                  (item) => item.cadence == cadence,
                ))
                  _budgetCard(
                    context,
                    finance,
                    budget,
                    sumEntries(analytics.budgetEntries(budget)),
                    now,
                    onTap: () =>
                        openEditorPage<void>(context, _BudgetDetail(budget.id)),
                  ),
              ],
            OutlinedButton.icon(
              onPressed: () => editBudget(context, finance.preferences),
              icon: const Icon(Icons.add),
              label: const Text('Create Budget'),
            ),
          ]),
        ),
        ReportSection(
          title: 'Goals',
          subtitle: 'How much have I saved?',
          child: formFields([
            if (ledger.goals.isEmpty) const Text('No savings goals yet.'),
            for (final goal in ledger.goals)
              _goalCard(
                context,
                finance,
                goal,
                onTap: () =>
                    openEditorPage<void>(context, _GoalDetail(goal.id)),
              ),
            OutlinedButton.icon(
              onPressed: () => createGoal(context, finance.preferences),
              icon: const Icon(Icons.add),
              label: const Text('Create Goal'),
            ),
          ]),
        ),
        ReportSection(
          title: 'Labels',
          subtitle: 'Organize records by purpose.',
          child: formFields([
            if (ledger.labels.isEmpty) const Text('No labels yet.'),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                for (final label in ledger.labels)
                  InputChip(
                    label: Text(label.name),
                    tooltip: 'Edit ${label.name}',
                    avatar: Icon(
                      namedIcon(label.icon),
                      size: 16,
                      color: Color(label.color),
                    ),
                    onPressed: () => editLabel(
                      context,
                      finance.preferences.demo,
                      label: label,
                    ),
                    onDeleted: () async {
                      final approved = await confirm(
                        context,
                        'Delete label?',
                        'This removes the label from records and any budget filters that use it.',
                        'Delete',
                      );
                      if (!approved || !context.mounted) return;
                      await runAction(
                        context,
                        () => ref
                            .read(financeProvider.notifier)
                            .change(
                              (ledger) => ledger.deleteLabel(label.id),
                              expectedDemo: finance.preferences.demo,
                            ),
                      );
                    },
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => editLabel(context, finance.preferences.demo),
              icon: const Icon(Icons.add),
              label: const Text('Create Label'),
            ),
          ]),
        ),
      ]).children,
    );
  }
}

class _BudgetDetail extends ConsumerWidget {
  const _BudgetDetail(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider).requireValue;
    final budget = finance.ledger.budgets
        .where((item) => item.id == id)
        .firstOrNull;
    if (budget == null) {
      return const EditorPage(
        title: 'Budget',
        children: [Text('Budget unavailable.')],
      );
    }
    final entries = Analytics(finance.ledger).budgetEntries(budget);
    return EditorPage(
      title: _budgetName(finance.ledger, budget),
      children: [
        _budgetCard(
          context,
          finance,
          budget,
          sumEntries(entries),
          DateTime.now(),
        ),
        Text(
          [
            finance.ledger.category(budget.categoryId)?.name ??
                'All categories',
            finance.ledger.wallet(budget.walletId)?.name ?? 'All accounts',
            finance.ledger.label(budget.labelId)?.name ?? 'All labels',
          ].join(' · '),
        ),
        Text(
          'Alerts · Overspent ${budget.notifyOverspent ? 'on' : 'off'} · Risk ${budget.notifyRisk ? 'on' : 'off'}',
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () =>
                  editBudget(context, finance.preferences, budget: budget),
              child: const Text('Edit budget and alerts'),
            ),
            TextButton(
              onPressed: () => _delete(
                context,
                ref,
                finance.preferences.demo,
                'budget',
                (ledger) => ledger.copy(
                  budgets: ledger.budgets.where((item) => item.id != id),
                ),
              ),
              child: const Text('Delete budget'),
            ),
          ],
        ),
        Text(
          'Matching records',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (entries.isEmpty) const Text('No expenses match this budget.'),
        for (final entry in entries)
          EntryRow(
            entry,
            finance,
            onTap: () => showEntryDetails(context, ref, finance, entry),
          ),
      ],
    );
  }
}

class _GoalDetail extends ConsumerWidget {
  const _GoalDetail(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider).requireValue;
    final goal = finance.ledger.goals
        .where((item) => item.id == id)
        .firstOrNull;
    if (goal == null) {
      return const EditorPage(
        title: 'Goal',
        children: [Text('Goal unavailable.')],
      );
    }
    return EditorPage(
      title: goal.name,
      children: [
        _goalCard(context, finance, goal),
        if (goal.note.isNotEmpty) Text(goal.note),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () => editGoal(context, finance.preferences, goal),
              child: const Text('Edit goal or update savings'),
            ),
            TextButton(
              onPressed: () => _delete(
                context,
                ref,
                finance.preferences.demo,
                'goal',
                (ledger) => ledger.copy(
                  goals: ledger.goals.where((item) => item.id != id),
                ),
              ),
              child: const Text('Delete goal'),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  bool demo,
  String name,
  Ledger Function(Ledger) update,
) async {
  if (!await confirm(
        context,
        'Delete $name?',
        'This removes the $name from Planning.',
        'Delete',
      ) ||
      !context.mounted) {
    return;
  }
  await runAction(context, () async {
    await ref.read(financeProvider.notifier).change(update, expectedDemo: demo);
    if (context.mounted) Navigator.pop(context);
  });
}

String _budgetName(Ledger ledger, Budget budget) => budget.name.isNotEmpty
    ? budget.name
    : ledger.category(budget.categoryId)?.name ?? 'Overall spending';

Widget _budgetCard(
  BuildContext context,
  FinanceState finance,
  Budget budget,
  int spent,
  DateTime now, {
  VoidCallback? onTap,
}) {
  final period = budgetPeriod(budget);
  final ratio = spent / budget.amount;
  final remaining = budget.amount - spent;
  final colors = Theme.of(context).colorScheme;
  final active = period.contains(now);
  final atRisk = active && budgetAtRisk(budget, spent, now);
  return _progressCard(
    context,
    name: _budgetName(finance.ledger, budget),
    icon: Icons.pie_chart_outline,
    amount: spent,
    limit: budget.amount,
    currency: budget.currency,
    ratio: ratio,
    percent: '${spent * 100 ~/ budget.amount}% used',
    detail: remaining < 0
        ? '${money(-remaining, budget.currency)} over budget'
        : '${money(remaining, budget.currency)} remaining',
    period:
        '${dateLabel(period.start, finance.preferences.dateFormat)} to '
        '${dateLabel(shiftDay(period.end, -1), finance.preferences.dateFormat)}',
    alert: budget.notifyOverspent && remaining < 0
        ? 'Budget overspent'
        : budget.notifyRisk && atRisk
        ? 'Projected to exceed this budget'
        : null,
    color: remaining < 0
        ? colors.error
        : ratio >= .8 || atRisk
        ? colors.tertiary
        : colors.primary,
    onTap: onTap,
  );
}

Widget _goalCard(
  BuildContext context,
  FinanceState finance,
  SavingsGoal goal, {
  VoidCallback? onTap,
}) {
  final remaining = goal.target - goal.saved;
  return _progressCard(
    context,
    name: goal.name,
    icon: namedIcon(goal.icon),
    amount: goal.saved,
    limit: goal.target,
    currency: goal.currency,
    ratio: goal.saved / goal.target,
    percent: '${goal.saved * 100 ~/ goal.target}% completed',
    detail: remaining > 0
        ? '${money(remaining, goal.currency)} left to save'
        : remaining == 0
        ? 'Goal reached'
        : '${money(-remaining, goal.currency)} above target',
    period: goal.due == null
        ? null
        : 'Target · ${dateLabel(goal.due!, finance.preferences.dateFormat)}',
    color: Color(goal.color),
    onTap: onTap,
  );
}

Widget _progressCard(
  BuildContext context, {
  required String name,
  required IconData icon,
  required int amount,
  required int limit,
  required String currency,
  required String percent,
  required double ratio,
  required String detail,
  required Color color,
  String? period,
  String? alert,
  VoidCallback? onTap,
}) => Material(
  color: Theme.of(context).colorScheme.surfaceContainerLow,
  borderRadius: BorderRadius.circular(14),
  child: InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: formFields([
        Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
        Text('${money(amount, currency)} / ${money(limit, currency)}'),
        LinearProgressIndicator(
          value: ratio.clamp(0, 1),
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          semanticsLabel: percent,
        ),
        Text('$percent · $detail'),
        if (period != null) Text(period),
        if (alert != null)
          Text(
            alert,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
      ]),
    ),
  ),
);
