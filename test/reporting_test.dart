import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/src/core/analytics.dart';
import 'package:moneymate/src/core/calculator.dart';
import 'package:moneymate/src/core/models.dart';
import 'package:moneymate/src/core/reporting.dart';

final _date = DateTime(2026, 11, 12);
final _cash = Wallet(
  'cash',
  'Cash',
  WalletType.cash,
  'USD',
  1000,
  palette.first,
  'cash',
  DateTime(2026, 11, 9),
);
final _bank = Wallet(
  'bank',
  'Bank',
  WalletType.bank,
  'USD',
  2000,
  palette.first,
  'bank',
  DateTime(2026, 11, 9),
);
final _yen = Wallet(
  'yen',
  'Yen',
  WalletType.cash,
  'JPY',
  3000,
  palette.first,
  'cash',
  DateTime(2026, 11, 9),
);
final _trip = LedgerLabel('trip', 'Trip', palette.first, 'travel');
final _work = LedgerLabel('work', 'Work', palette.last, 'category');

Entry _record(
  String id,
  int amount,
  Wallet wallet,
  DateTime date, {
  List<String> labels = const [],
  SpendingNature? nature,
  EntryType type = EntryType.expense,
  String? to,
}) => Entry(
  id,
  type,
  amount,
  wallet.id,
  date,
  date,
  date,
  categoryId: type == EntryType.expense
      ? 'expense-0'
      : type == EntryType.income
      ? 'income-0'
      : null,
  labelIds: labels,
  nature: nature,
  destinationId: to,
);

void main() {
  test(
    'calculator uses precedence and rounds once in the selected currency',
    () {
      expect(evaluateAmount('100+50', 'USD'), 15000);
      expect(evaluateAmount('0.1+0.2', 'USD'), 30);
      expect(evaluateAmount('2+3×4−1', 'USD'), 1300);
      expect(evaluateAmount('10÷3×3', 'USD'), 1000);
      expect(evaluateAmount('1÷8', 'USD'), 13);
      expect(evaluateAmount('2.5', 'JPY'), 3);
      expect(evaluateAmount('-4+6', 'USD'), 200);
      for (final invalid in ['1÷0', '1+', '1.2.3', '4++5', '', '1 2']) {
        expect(() => evaluateAmount(invalid, 'USD'), throwsFormatException);
      }
    },
  );

  test(
    'report windows use local calendar days and cover every date exactly once',
    () {
      final now = DateTime(2024, 8, 30, 23, 59);
      final month = ReportRange.month.period(now);
      expect(month.start, DateTime(2024, 8, 1));
      expect(month.contains(now), isTrue);
      expect(month.contains(month.end), isFalse);
      expect(ReportRange.halfYear.period(now).start, DateTime(2024, 2, 29));
      expect(ReportRange.quarter.buckets(now), hasLength(12));
      expect(ReportRange.halfYear.buckets(now), hasLength(6));
      for (final range in ReportRange.values) {
        final buckets = range.buckets(now);
        expect(buckets.first.start, range.period(now).start);
        expect(buckets.last.end, range.period(now).end);
        for (var i = 1; i < buckets.length; i++) {
          expect(buckets[i - 1].end, buckets[i].start);
        }
      }
    },
  );

  test(
    'balance history reconstructs opening, backdated and both sides of transfers',
    () {
      final early = DateTime(2026, 11, 7, 13);
      final later = DateTime(2026, 11, 10, 12);
      final ledger = Ledger(
        wallets: [_cash, _bank, _yen],
        entries: [
          _record('debit', 200, _cash, early),
          _record(
            'move',
            300,
            _cash,
            later,
            type: EntryType.transfer,
            to: _bank.id,
          ),
          _record('income', 50, _bank, later, type: EntryType.income),
        ],
      );
      ledger.validate();
      final analytics = Analytics(ledger);
      final buckets = ReportRange.week.buckets(_date);
      expect(analytics.balanceHistory(_cash, buckets).first.value, 800);
      expect(analytics.balanceHistory(_cash, buckets).last.value, 500);
      expect(analytics.balanceHistory(_bank, buckets).last.value, 2350);
      expect(analytics.balancesByCurrency(), {'USD': 2850, 'JPY': 3000});
    },
  );

  test(
    'labels, nature, currency and account scopes never multiply a budget expense',
    () {
      final budget = Budget(
        'scope',
        'USD',
        '2026-11',
        3000,
        _date,
        categoryId: 'expense-0',
        walletId: _cash.id,
        labelId: _trip.id,
        notifyRisk: true,
      );
      final ledger = Ledger(
        wallets: [_cash, _bank, _yen],
        labels: [_trip, _work],
        budgets: [budget],
        entries: [
          _record(
            'multi',
            2100,
            _cash,
            _date,
            labels: [_trip.id, _work.id],
            nature: SpendingNature.need,
          ),
          _record('single', 250, _bank, _date, labels: [_trip.id]),
          _record('other-currency', 700, _yen, _date, labels: [_trip.id]),
          _record(
            'other-period',
            400,
            _cash,
            DateTime(2026, 10, 31),
            labels: [_trip.id],
          ),
          _record(
            'move',
            400,
            _cash,
            _date,
            labels: [_trip.id],
            type: EntryType.transfer,
            to: _bank.id,
          ),
        ],
      );
      ledger.validate();
      final analytics = Analytics(ledger);
      final current = analytics.expenses(Period.month(_date), 'USD');
      expect(sumEntries(current), 2350);
      expect(current.map(labelGroup), [sharedLabelsGroup, _trip.id]);
      expect(
        sumEntries(
          current.where((entry) => entry.nature == SpendingNature.need),
        ),
        2100,
      );
      expect(sumEntries(analytics.budgetEntries(budget)), 2100);
      expect(budgetAtRisk(budget, 2100, _date), isTrue);
      expect(budgetAtRisk(budget, 2100, DateTime(2026, 12, 1)), isFalse);
      final after = ledger.deleteLabel(_trip.id);
      after.validate();
      expect(after.entries, hasLength(5));
      expect(after.entries.first.labelIds, [_work.id]);
      expect(after.budgets.single.labelId, isNull);
    },
  );

  test(
    'old snapshots decode and new backups round-trip goals, labels and settings',
    () {
      final legacy =
          jsonDecode(
                  Ledger(
                    wallets: [_cash],
                    entries: [_record('historic', 250, _cash, _date)],
                  ).encode(),
                )
                as Json
            ..['schemaVersion'] = 1
            ..remove('labels')
            ..remove('goals');
      final tx = (legacy['transactions'] as List).single as Json;
      tx.remove('labelIds');
      tx.remove('nature');
      final migrated = Ledger.decode(jsonEncode(legacy));
      expect(migrated.entries.single.amount, 250);
      expect(migrated.entries.single.labelIds, isEmpty);
      expect(migrated.entries.single.nature, isNull);
      final next = migrated.copy(
        labels: [_trip],
        goals: [
          SavingsGoal(
            'goal',
            'Trip',
            'USD',
            300,
            350,
            palette.first,
            'travel',
            note: 'Over target',
            due: _date,
          ),
        ],
        budgets: [
          Budget(
            'budget',
            'USD',
            '2026-11',
            500,
            _date,
            labelId: _trip.id,
            cadence: BudgetCadence.custom,
            start: _date,
            end: shiftDay(_date, 2),
            notifyOverspent: true,
            notifyRisk: true,
          ),
        ],
      );
      final restored = Ledger.decode(
        next.encode(demo: false),
        expectedDemo: false,
      );
      expect(restored.encode(), next.encode());
      expect(restored.goals.single.saved, 350);
      expect(restored.budgets.single.notifyRisk, isTrue);
      expect(restored.labels.single.name, 'Trip');
    },
  );
}
