import 'models.dart';

class Period {
  const Period(this.start, this.end);
  final DateTime start, end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  factory Period.month(DateTime now, [int offset = 0]) => Period(
    DateTime(now.year, now.month + offset),
    DateTime(now.year, now.month + offset + 1),
  );

  factory Period.week(DateTime now) => Period(
    DateTime(now.year, now.month, now.day - now.weekday + 1),
    DateTime(now.year, now.month, now.day - now.weekday + 8),
  );

  factory Period.year(DateTime now) =>
      Period(DateTime(now.year), DateTime(now.year + 1));

  String get monthKey =>
      '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
}

int sumEntries(Iterable<Entry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.amount);

Period budgetPeriod(Budget budget) {
  if (budget.start case final DateTime start) return Period(start, budget.end!);
  final month = DateTime.parse('${budget.month}-01');
  return Period.month(month);
}

class Totals {
  const Totals(this.income, this.expense, this.categories);
  final int income, expense;
  final Map<String, int> categories;
  int get net => income - expense;
}

class Analytics {
  Analytics(this.ledger)
    : wallets = {for (final wallet in ledger.wallets) wallet.id: wallet},
      categories = {
        for (final category in ledger.categories) category.id: category,
      };

  final Ledger ledger;
  final Map<String, Wallet> wallets;
  final Map<String, Category> categories;

  Map<String, int> balances() {
    final result = {for (final w in ledger.wallets) w.id: w.opening};
    for (final entry in ledger.entries) {
      result.update(
        entry.walletId,
        (balance) =>
            balance +
            (entry.type == EntryType.income ? entry.amount : -entry.amount),
      );
      if (entry.type == EntryType.transfer) {
        result.update(
          entry.destinationId!,
          (balance) => balance + entry.amount,
        );
      }
    }
    return result;
  }

  Totals totals(Period period, String currency) {
    var income = 0;
    var expense = 0;
    final spending = <String, int>{};
    for (final entry in ledger.entries) {
      final wallet = wallets[entry.walletId]!;
      if (wallet.currency != currency || !period.contains(entry.date)) continue;
      switch (entry.type) {
        case EntryType.income:
          if (wallet.type != WalletType.credit) income += entry.amount;
        case EntryType.expense:
          expense += entry.amount;
          spending.update(
            entry.categoryId!,
            (value) => value + entry.amount,
            ifAbsent: () => entry.amount,
          );
        case EntryType.transfer:
          break;
      }
    }
    return Totals(income, expense, spending);
  }

  List<Entry> largest(Period period, String currency) =>
      ledger.entries
          .where(
            (e) =>
                e.type == EntryType.expense &&
                period.contains(e.date) &&
                wallets[e.walletId]?.currency == currency,
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  int spent(Budget budget, Totals totals) => budget.categoryId == null
      ? totals.expense
      : totals.categories[budget.categoryId] ?? 0;

  Iterable<Entry> expenses(Period period, String currency) =>
      ledger.entries.where(
        (entry) =>
            entry.type == EntryType.expense &&
            period.contains(entry.date) &&
            wallets[entry.walletId]?.currency == currency,
      );

  List<Entry> budgetEntries(Budget budget) =>
      expenses(budgetPeriod(budget), budget.currency)
          .where(
            (entry) =>
                (budget.categoryId == null ||
                    entry.categoryId == budget.categoryId) &&
                (budget.walletId == null ||
                    entry.walletId == budget.walletId) &&
                (budget.labelId == null ||
                    entry.labelIds.contains(budget.labelId)),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Json assistantContext(
    DateTime now,
    String currency, {
    int categoryLimit = 16,
  }) {
    final period = Period.month(now);
    final previousPeriod = Period.month(now, -1);
    final current = totals(period, currency);
    final previous = totals(previousPeriod, currency);
    final ids =
        {...current.categories.keys, ...previous.categories.keys}.toList()
          ..sort(
            (a, b) => (current.categories[b] ?? 0).compareTo(
              current.categories[a] ?? 0,
            ),
          );
    final budgets = ledger.budgets.where(
      (b) => b.currency == currency && budgetPeriod(b).contains(now),
    );
    final biggest = largest(period, currency);
    return {
      'period': period.monthKey,
      'previousPeriod': previousPeriod.monthKey,
      'currency': currency,
      'fractionDigits': fractionDigits(currency),
      'incomeMinor': current.income,
      'expenseMinor': current.expense,
      'netMinor': current.net,
      'previousExpenseMinor': previous.expense,
      'expenseChangeMinor': current.expense - previous.expense,
      'expenseCount': biggest.length,
      'categories': [
        for (final id in ids.take(categoryLimit))
          {
            'name': categories[id]?.name,
            'spentMinor': current.categories[id] ?? 0,
            'previousMinor': previous.categories[id] ?? 0,
            'changeMinor':
                (current.categories[id] ?? 0) - (previous.categories[id] ?? 0),
            'sharePercent': current.expense == 0
                ? 0
                : (current.categories[id] ?? 0) * 100 ~/ current.expense,
            'classification': _classification(id),
            if (_classification(id) == 'discretionary')
              'exampleSavingsMinorAtTenPercent':
                  (current.categories[id] ?? 0) ~/ 10,
          },
      ],
      'budgets': [
        for (final budget in budgets.take(10))
          (() {
            final spent = sumEntries(budgetEntries(budget));
            return {
              'category': budget.name.isNotEmpty
                  ? budget.name
                  : categories[budget.categoryId]?.name ?? 'Overall',
              'limitMinor': budget.amount,
              'spentMinor': spent,
              'remainingMinor': budget.amount - spent,
              'utilizationPercent': spent * 100 ~/ budget.amount,
            };
          })(),
      ],
      'largestExpenses': [
        for (final entry in biggest.take(5))
          {
            'amountMinor': entry.amount,
            'category': categories[entry.categoryId]?.name,
            'day': entry.date.day,
          },
      ],
      'weeklyExpenses': [
        for (
          var day = 1;
          day <= 31 && day <= DateTime(now.year, now.month + 1, 0).day;
          day += 7
        )
          totals(
            Period(
              DateTime(now.year, now.month, day),
              day + 7 >= DateTime(now.year, now.month + 1, 0).day + 1
                  ? period.end
                  : DateTime(now.year, now.month, day + 7),
            ),
            currency,
          ).expense,
      ],
    };
  }

  String _classification(String id) {
    if (['expense-3', 'expense-4', 'expense-9', 'expense-10'].contains(id)) {
      return 'discretionary';
    }
    if (['expense-1', 'expense-5', 'expense-6', 'expense-7'].contains(id)) {
      return 'often essential';
    }
    return 'review individually';
  }
}
