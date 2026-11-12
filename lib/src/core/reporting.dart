import 'analytics.dart';
import 'models.dart';

enum ReportRange {
  week('7D', 'Last 7 days'),
  month('30D', 'Last 30 days'),
  quarter('12W', 'Last 12 weeks'),
  halfYear('6M', 'Last 6 months'),
  year('1Y', 'Last year');

  const ReportRange(this.code, this.label);
  final String code, label;

  Period period(DateTime now) {
    final today = localDay(now);
    final end = shiftDay(today, 1);
    final start = switch (this) {
      week => shiftDay(end, -7),
      month => shiftDay(end, -30),
      quarter => shiftDay(end, -84),
      halfYear => shiftMonth(end, -6),
      year => shiftMonth(end, -12),
    };
    return Period(start, end);
  }

  List<Period> buckets(DateTime now) {
    final span = period(now);
    if (this == halfYear || this == year) {
      final count = this == halfYear ? 6 : 12;
      return [
        for (var offset = -count; offset < 0; offset++)
          Period(
            shiftMonth(span.end, offset),
            shiftMonth(span.end, offset + 1),
          ),
      ];
    }
    final result = <Period>[];
    var start = span.start;
    while (start.isBefore(span.end)) {
      final next = shiftDay(start, this == quarter ? 7 : 1);
      final end = next.isAfter(span.end) ? span.end : next;
      result.add(Period(start, end));
      start = end;
    }
    return result;
  }
}

DateTime localDay(DateTime time) {
  final date = time.toLocal();
  return DateTime(date.year, date.month, date.day);
}

DateTime shiftDay(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime shiftMonth(DateTime date, int months) {
  final month = DateTime(date.year, date.month + months);
  final last = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, date.day.clamp(1, last));
}

bool budgetAtRisk(Budget budget, int spent, DateTime now) {
  final period = budgetPeriod(budget);
  if (!period.contains(now) || spent <= 0 || spent > budget.amount) {
    return false;
  }
  DateTime calendarDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
  final start = calendarDate(period.start);
  final days = calendarDate(period.end).difference(start).inDays;
  final elapsed = calendarDate(localDay(now)).difference(start).inDays + 1;
  return days > 0 &&
      elapsed > 0 &&
      BigInt.from(spent) * BigInt.from(days) >
          BigInt.from(budget.amount) * BigInt.from(elapsed);
}

extension Reporting on Analytics {
  List<({DateTime date, int value})> balanceHistory(
    Wallet wallet,
    List<Period> buckets,
  ) {
    final changes =
        ledger.entries
            .where(
              (entry) =>
                  entry.walletId == wallet.id ||
                  entry.destinationId == wallet.id,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final earliest = changes.firstOrNull?.date;
    final opened = earliest != null && earliest.isBefore(wallet.created)
        ? earliest
        : wallet.created;
    var balance = wallet.opening;
    var index = 0;
    return [
      for (final bucket in buckets)
        if (opened.isBefore(bucket.end))
          (() {
            while (index < changes.length &&
                changes[index].date.isBefore(bucket.end)) {
              final entry = changes[index++];
              balance +=
                  entry.destinationId == wallet.id ||
                      entry.type == EntryType.income
                  ? entry.amount
                  : -entry.amount;
            }
            return (date: shiftDay(bucket.end, -1), value: balance);
          })(),
    ];
  }

  Map<String, int> balancesByCurrency() {
    final result = <String, int>{};
    final current = balances();
    for (final wallet in ledger.wallets) {
      result.update(
        wallet.currency,
        (amount) => amount + current[wallet.id]!,
        ifAbsent: () => current[wallet.id]!,
      );
    }
    return result;
  }
}

const unlabeledGroup = '';
const sharedLabelsGroup = '@multiple';

String labelGroup(Entry entry) => switch (entry.labelIds.length) {
  0 => unlabeledGroup,
  1 => entry.labelIds.single,
  _ => sharedLabelsGroup,
};
