import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../ui/shared.dart';

const starterQuestions = [
  'Where am I spending the most?',
  'What changed from last month?',
  'Which budgets did I exceed?',
  'What were my biggest expenses?',
  'How could I save next month?',
  'How much did I spend on transportation?',
];

List<String> spendingSuggestions(
  Json summary,
  String currency,
  String question,
) {
  final categories = (summary['categories'] as List).cast<Json>();
  final budgets = (summary['budgets'] as List).cast<Json>();
  final query = question.toLowerCase();
  final mentioned = categories
      .where((item) => query.contains((item['name'] as String).toLowerCase()))
      .firstOrNull;
  final candidates = mentioned == null ? categories : [mentioned];
  return [
    for (final category
        in candidates
            .where(
              (item) =>
                  item['classification'] == 'discretionary' &&
                  (item['exampleSavingsMinorAtTenPercent'] as int) > 0,
            )
            .take(3))
      'Review ${category['name']} for purchases you could skip next month. '
          'A 10% reduction at this month’s recorded spending level would free up '
          '${money(category['exampleSavingsMinorAtTenPercent'] as int, currency)}.',
    for (final budget
        in budgets
            .where(
              (item) =>
                  (item['remainingMinor'] as int) < 0 &&
                  (mentioned == null || item['category'] == mentioned['name']),
            )
            .take(1))
      'Review what pushed the ${budget['category']} budget over its limit, '
          'then decide which purchases can wait until next month.',
    if (mentioned == null)
      'Set aside money for regular bills before choosing a flexible spending limit.'
    else
      'Compare ${mentioned['name']} purchases across months before setting the next limit.',
  ];
}

String spendingAnswer(
  Analytics analytics,
  DateTime now,
  String currency,
  String question,
) {
  final month = Period.month(now);
  final prior = analytics.totals(Period.month(now, -1), currency);
  final current = analytics.totals(month, currency);
  final text = question.toLowerCase();
  String amount(int value) => money(value, currency);
  final categories = current.categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final budgetQuestion =
      text.contains('budget') ||
      text.contains('exceed') ||
      text.contains('limit');
  if (budgetQuestion) {
    final budgets = analytics.ledger.budgets.where(
      (budget) => budget.currency == currency && budget.month == month.monthKey,
    );
    if (budgets.isEmpty) {
      return 'There are no $currency budgets for ${month.monthKey}. Set an overall or category limit in Monthly budgets.';
    }
    return 'Budget progress for ${month.monthKey}\n\n${budgets.map((budget) {
      final spent = analytics.spent(budget, current);
      final remaining = budget.amount - spent;
      final name = analytics.categories[budget.categoryId]?.name ?? 'Overall';
      return '• $name · ${amount(spent)} of ${amount(budget.amount)} · '
          '${remaining < 0 ? '${amount(-remaining)} over' : '${amount(remaining)} left'}';
    }).join('\n')}';
  }
  if (text.contains('last month') ||
      text.contains('chang') ||
      text.contains('compar')) {
    final change = current.expense - prior.expense;
    final movement = change == 0
        ? 'Spending is unchanged.'
        : 'Spending is ${change > 0 ? 'up' : 'down'} ${amount(change.abs())}.';
    return '${month.monthKey} expenses are ${amount(current.expense)} so far. '
        'The previous calendar month totaled ${amount(prior.expense)}. $movement';
  }
  final matching = analytics.categories.values
      .where(
        (c) =>
            c.type == EntryType.expense &&
            (text.contains(c.name.toLowerCase()) ||
                (c.id == 'expense-0' &&
                    ['dining', 'restaurant', 'coffee'].any(text.contains))),
      )
      .firstOrNull;
  if (matching != null) {
    return '${matching.name} spending for ${month.monthKey} is ${amount(current.categories[matching.id] ?? 0)}. '
        'Last month it was ${amount(prior.categories[matching.id] ?? 0)}.';
  }
  if (text.contains('biggest') || text.contains('largest')) {
    final entries = analytics.largest(month, currency).take(5);
    if (entries.isEmpty) {
      return 'There are no recorded $currency expenses for ${month.monthKey}.';
    }
    return 'Largest expenses in ${month.monthKey}\n\n${entries.map((entry) => '• ${entry.description.isEmpty ? analytics.categories[entry.categoryId]!.name : entry.description} · ${amount(entry.amount)}').join('\n')}';
  }
  if (text.contains('sav') || text.contains('reduce') || text.contains('cut')) {
    final discretionary = categories
        .where(
          (category) => [
            'expense-3',
            'expense-4',
            'expense-9',
            'expense-10',
          ].contains(category.key),
        )
        .take(3);
    if (discretionary.isEmpty) {
      return 'There is too little discretionary spending recorded this month to estimate a category reduction.';
    }
    final baseline = discretionary.fold(
      0,
      (sum, category) => sum + category.value,
    );
    return 'A 10% reduction across ${discretionary.map((c) => analytics.categories[c.key]!.name).join(', ')} '
        'would free up about ${amount(baseline ~/ 10)} if spending stayed at this month’s recorded level. '
        'Review those expenses for purchases you could skip or defer.';
  }
  if (current.expense == 0 && current.income == 0) {
    return 'There is no recorded $currency income or spending for ${month.monthKey}.';
  }
  final breakdown = categories
      .take(4)
      .map(
        (c) =>
            '• ${analytics.categories[c.key]!.name} · ${amount(c.value)} (${c.value * 100 ~/ current.expense}%)',
      )
      .join('\n');
  return '${month.monthKey} · Income ${amount(current.income)}, expenses ${amount(current.expense)}, '
      'net cash flow ${amount(current.net)}.${breakdown.isEmpty ? '' : '\n\nTop categories\n$breakdown'}';
}
