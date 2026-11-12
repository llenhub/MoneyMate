import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/src/core/analytics.dart';
import 'package:moneymate/src/core/models.dart';
import 'package:moneymate/src/data/repository.dart';
import 'package:moneymate/src/data/storage.dart';
import 'package:moneymate/src/features/settings/demo.dart';

import 'support/memory_store.dart';

final date = DateTime(2026, 11, 12);
final bank = Wallet(
  'bank',
  'Bank',
  WalletType.bank,
  'USD',
  100000,
  palette.first,
  'bank',
  date,
);
final cash = Wallet(
  'cash',
  'Cash',
  WalletType.cash,
  'USD',
  1000,
  palette.first,
  'cash',
  date,
);
final card = Wallet(
  'card',
  'Card',
  WalletType.credit,
  'USD',
  0,
  palette.first,
  'card',
  date,
);
final jpy = Wallet(
  'jpy',
  'Yen',
  WalletType.cash,
  'JPY',
  1000,
  palette.first,
  'cash',
  date,
);

Entry entry(
  String id,
  EntryType type,
  int amount,
  String wallet, {
  DateTime? when,
  String? to,
  String? category,
}) => Entry(
  id,
  type,
  amount,
  wallet,
  when ?? date,
  date,
  date,
  destinationId: to,
  categoryId:
      category ??
      switch (type) {
        EntryType.expense => 'expense-0',
        EntryType.income => 'income-0',
        _ => null,
      },
);

void main() {
  late FinanceRepository repository;
  late MemoryStore store;
  late Ledger ledger;

  setUp(() async {
    store = MemoryStore();
    repository = FinanceRepository(store);
    final original = await repository.load(demo: false);
    ledger = original.copy(wallets: [bank, cash, card, jpy]);
    await repository.save(ledger, demo: false, previous: original);
  });

  test('create and update a wallet, retaining its persisted ID', () async {
    final replacement = Wallet(
      bank.id,
      'Primary',
      bank.type,
      bank.currency,
      125000,
      bank.color,
      bank.icon,
      date,
    );
    final updated = ledger.copy(wallets: [replacement, cash, card, jpy]);
    await repository.save(updated, demo: false, previous: ledger);
    final restored = await FinanceRepository(store).load(demo: false);
    expect(restored.wallet(bank.id)?.name, 'Primary');
    expect(Analytics(restored).balances()[bank.id], 125000);
  });

  test(
    'income, expense, edit and delete derive balances without rounding',
    () async {
      final salary = entry('salary', EntryType.income, 50001, bank.id);
      final expense = entry('food', EntryType.expense, 10023, bank.id);
      final withIncome = ledger.copy(entries: [salary]);
      await repository.save(withIncome, demo: false, previous: ledger);
      expect(Analytics(withIncome).balances()[bank.id], 150001);
      final withExpense = ledger.copy(entries: [salary, expense]);
      await repository.save(withExpense, demo: false, previous: withIncome);
      expect(Analytics(withExpense).balances()[bank.id], 139978);
      final edited = withExpense.copy(
        entries: [salary, entry('food', EntryType.expense, 901, bank.id)],
      );
      await repository.save(edited, demo: false, previous: withExpense);
      expect(Analytics(edited).balances()[bank.id], 149100);
      final deleted = edited.copy(entries: [salary]);
      await repository.save(deleted, demo: false, previous: edited);
      expect(
        Analytics(await repository.load(demo: false)).balances()[bank.id],
        150001,
      );
    },
  );

  test(
    'transfers and card payments move funds without double-counting purchases',
    () {
      final data = ledger.copy(
        entries: [
          entry('cash-out', EntryType.transfer, 500, bank.id, to: cash.id),
          entry('purchase', EntryType.expense, 20000, card.id),
          entry('payment', EntryType.transfer, 15000, bank.id, to: card.id),
          entry(
            'refund',
            EntryType.income,
            1000,
            card.id,
            category: 'income-5',
          ),
        ],
      );
      data.validate();
      final analytics = Analytics(data);
      expect(analytics.balances(), {
        bank.id: 84500,
        cash.id: 1500,
        card.id: -4000,
        jpy.id: 1000,
      });
      final totals = analytics.totals(Period.month(date), 'USD');
      expect(totals.income, 0);
      expect(totals.expense, 20000);
      expect(totals.net, -20000);
      expect(totals.categories, {'expense-0': 20000});
      expect(
        () => ledger
            .copy(
              entries: [
                entry('fx', EntryType.transfer, 500, bank.id, to: jpy.id),
              ],
            )
            .validate(),
        throwsFormatException,
      );
    },
  );

  test('monthly date boundaries, category totals and budget progress', () {
    final november = Period.month(date);
    final budget = Budget(
      'budget',
      'USD',
      november.monthKey,
      2000,
      date,
      categoryId: 'expense-0',
    );
    final data = ledger.copy(
      budgets: [budget],
      entries: [
        entry(
          'before',
          EntryType.expense,
          999,
          bank.id,
          when: november.start.subtract(const Duration(milliseconds: 1)),
        ),
        entry('start', EntryType.expense, 1400, bank.id, when: november.start),
        entry('end', EntryType.expense, 200, bank.id, when: november.end),
        entry('yen', EntryType.expense, 800, jpy.id, when: november.start),
        entry(
          'groceries',
          EntryType.expense,
          300,
          cash.id,
          category: 'expense-1',
        ),
      ],
    );
    data.validate();
    final analytics = Analytics(data);
    final totals = analytics.totals(november, 'USD');
    expect(totals.categories, {'expense-0': 1400, 'expense-1': 300});
    expect(analytics.spent(budget, totals), 1400);
    expect(analytics.totals(Period.month(date, -1), 'USD').expense, 999);
    expect(analytics.totals(Period.month(date, 1), 'USD').expense, 200);
  });

  test('archived category history survives while deletion is rejected', () {
    final data = ledger.copy(
      entries: [entry('a', EntryType.expense, 100, bank.id)],
    );
    final archived = data.copy(
      categories: [
        for (final c in data.categories)
          if (c.id == 'expense-0')
            Category(
              c.id,
              c.name,
              c.type,
              c.color,
              c.icon,
              archived: true,
              isDefault: c.isDefault,
            )
          else
            c,
      ],
    );
    archived.validate();
    expect(
      Analytics(
        archived,
      ).totals(Period.month(date), 'USD').categories['expense-0'],
      100,
    );
    expect(
      () => archived
          .copy(
            categories: archived.categories.where((c) => c.id != 'expense-0'),
          )
          .validate(),
      throwsFormatException,
    );
  });

  test(
    'backup restores atomically and rejects duplicate or dangling records',
    () async {
      final expense = entry('unique', EntryType.expense, 100, bank.id);
      final encoded = ledger.copy(entries: [expense]).encode();
      final restored = Ledger.decode(encoded);
      await repository.save(restored, demo: false, previous: ledger);
      expect(
        (await FinanceRepository(store).load(demo: false)).entries.single.id,
        'unique',
      );
      expect(
        () =>
            Ledger.decode(restored.copy(entries: [expense, expense]).encode()),
        throwsFormatException,
      );
      await expectLater(
        repository.save(
          restored.copy(wallets: []),
          demo: false,
          previous: restored,
        ),
        throwsFormatException,
      );
      expect(
        (await FinanceRepository(store).load(demo: false)).encode(),
        encoded,
      );
    },
  );

  test('demo snapshots stay separate from personal snapshots', () async {
    final empty = await repository.load(demo: true);
    final seeded = demoLedger(date);
    expect(
      () => Ledger.decode(seeded.encode(demo: true), expectedDemo: false),
      throwsFormatException,
    );
    expect(
      Ledger.decode(seeded.encode(demo: true), expectedDemo: true).entries,
      hasLength(seeded.entries.length),
    );
    await repository.save(seeded, demo: true, previous: empty);
    expect((await repository.load(demo: true)).entries, isNotEmpty);
    expect((await repository.load(demo: false)).wallets.map((w) => w.id), [
      bank.id,
      cash.id,
      card.id,
      jpy.id,
    ]);
  });

  test('stale writes cannot overwrite a newer snapshot', () async {
    final other = FinanceRepository(store);
    final stale = await other.load(demo: false);
    await repository.save(
      ledger.copy(wallets: [bank]),
      demo: false,
      previous: ledger,
    );
    await expectLater(
      other.save(stale.copy(wallets: [cash]), demo: false, previous: stale),
      throwsA(isA<StoreConflict>()),
    );
  });

  test('money parsing is exact and respects supported minor units', () {
    expect(parseMoney('100.03', 'USD'), 10003);
    expect(parseMoney('1.2', 'USD'), 120);
    expect(parseMoney('1.2', 'JPY'), isNull);
    expect(parseMoney('1.001', 'USD'), isNull);
    expect(decimalMoney(-10003, 'USD'), '-100.03');
  });
}
