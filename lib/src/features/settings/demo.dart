import 'dart:math';

import '../../core/analytics.dart';
import '../../core/models.dart';

Ledger demoLedger(DateTime now) {
  final rng = Random(17);
  final first = Period.month(now, -5).start;
  final wallets = [
    Wallet(
      'demo-bank',
      'Main Bank',
      WalletType.bank,
      'USD',
      214500,
      palette[0],
      'bank',
      first,
    ),
    Wallet(
      'demo-cash',
      'Daily Cash',
      WalletType.cash,
      'USD',
      16000,
      palette[3],
      'cash',
      first,
    ),
    Wallet(
      'demo-card',
      'Everyday Card',
      WalletType.credit,
      'USD',
      0,
      palette[1],
      'card',
      first,
      limit: 400000,
    ),
    Wallet(
      'demo-travel',
      'Travel Savings',
      WalletType.digital,
      'USD',
      125000,
      palette[2],
      'travel',
      first,
    ),
  ];
  final entries = <Entry>[];
  void add(
    DateTime date,
    EntryType type,
    int amount,
    String wallet,
    String description, {
    String? category,
    String? destination,
  }) {
    entries.add(
      Entry(
        'demo-${entries.length}',
        type,
        amount,
        wallet,
        date,
        date,
        date,
        categoryId: category,
        destinationId: destination,
        description: description,
      ),
    );
  }

  for (var offset = -5; offset <= 0; offset++) {
    final month = Period.month(now, offset).start;
    DateTime date(int day) => DateTime(
      month.year,
      month.month,
      offset == 0 ? min(day, now.day) : day,
      10,
    );
    add(
      date(1),
      EntryType.income,
      360000,
      'demo-bank',
      'Monthly salary',
      category: 'income-0',
    );
    add(
      date(2),
      EntryType.expense,
      132000,
      'demo-bank',
      'Apartment rent',
      category: 'expense-5',
    );
    add(
      date(4),
      EntryType.expense,
      6100,
      'demo-bank',
      'Transit pass',
      category: 'expense-2',
    );
    add(
      date(5),
      EntryType.expense,
      3499,
      'demo-card',
      'Streaming and music',
      category: 'expense-9',
    );
    for (var week = 0; week < (offset == 0 ? (now.day + 6) ~/ 7 : 4); week++) {
      add(
        date(4 + week * 6),
        EntryType.expense,
        6100 + rng.nextInt(3900),
        'demo-card',
        'Weekly groceries',
        category: 'expense-1',
      );
      add(
        date(6 + week * 6),
        EntryType.expense,
        2600 + rng.nextInt(3300),
        'demo-card',
        'Dinner with friends',
        category: 'expense-0',
      );
      add(
        date(7 + week * 6),
        EntryType.expense,
        600 + rng.nextInt(900),
        'demo-cash',
        'Neighborhood coffee',
        category: 'expense-0',
      );
    }
    add(
      date(12),
      EntryType.expense,
      5600 + rng.nextInt(5000),
      'demo-bank',
      'Electricity and water',
      category: 'expense-6',
    );
    add(
      date(16),
      EntryType.expense,
      4800 + rng.nextInt(18000),
      'demo-card',
      'Weekend shopping',
      category: 'expense-3',
    );
    add(
      date(18),
      EntryType.expense,
      6700 + rng.nextInt(3300),
      'demo-card',
      'Art supplies',
      category: 'demo-hobby',
    );
    add(
      date(20),
      EntryType.transfer,
      25000,
      'demo-bank',
      'Travel savings',
      destination: 'demo-travel',
    );
    if (offset < 0) {
      add(
        date(24),
        EntryType.transfer,
        54000,
        'demo-bank',
        'Credit card payment',
        destination: 'demo-card',
      );
    }
  }
  return Ledger(
    wallets: wallets,
    categories: [
      ...defaultCategories(),
      const Category(
        'demo-hobby',
        'Creative hobbies',
        EntryType.expense,
        0xff865598,
        'shopping',
      ),
    ],
    entries: entries,
    budgets: [
      for (var offset = -5; offset <= 0; offset++) ...[
        Budget(
          'demo-overall-$offset',
          'USD',
          Period.month(now, offset).monthKey,
          240000,
          first,
        ),
        Budget(
          'demo-food-$offset',
          'USD',
          Period.month(now, offset).monthKey,
          22000,
          first,
          categoryId: 'expense-0',
        ),
        Budget(
          'demo-shop-$offset',
          'USD',
          Period.month(now, offset).monthKey,
          14000,
          first,
          categoryId: 'expense-3',
        ),
      ],
    ],
  );
}
