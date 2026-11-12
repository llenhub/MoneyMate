import 'dart:convert';
import 'dart:math';

enum WalletType {
  cash('Cash'),
  debit('Debit card'),
  credit('Credit card'),
  bank('Bank account'),
  digital('E-wallet');

  const WalletType(this.label);
  final String label;
}

enum EntryType { income, expense, transfer }

enum SpendingNature { must, need, want }

enum BudgetCadence { weekly, monthly, yearly, custom }

class LedgerLabel {
  const LedgerLabel(this.id, this.name, this.color, this.icon);
  final String id, name, icon;
  final int color;
  LedgerLabel.fromJson(Json json)
    : this(json['id'], json['name'], json['color'], json['icon']);
  Json toJson() => {'id': id, 'name': name, 'color': color, 'icon': icon};
}

class SavingsGoal {
  const SavingsGoal(
    this.id,
    this.name,
    this.currency,
    this.target,
    this.saved,
    this.color,
    this.icon, {
    this.due,
    this.note = '',
  });
  final String id, name, currency, icon, note;
  final int target, saved, color;
  final DateTime? due;
  SavingsGoal.fromJson(Json json)
    : this(
        json['id'],
        json['name'],
        json['currency'],
        json['target'],
        json['saved'],
        json['color'],
        json['icon'],
        due: json['due'] == null ? null : DateTime.parse(json['due']),
        note: json['note'] ?? '',
      );
  Json toJson() => {
    'id': id,
    'name': name,
    'currency': currency,
    'target': target,
    'saved': saved,
    'color': color,
    'icon': icon,
    'due': due?.toIso8601String(),
    'note': note,
  };
}

const currencies = [
  'USD',
  'TWD',
  'EUR',
  'GBP',
  'JPY',
  'CAD',
  'AUD',
  'KRW',
  'SGD',
  'HKD',
  'INR',
];
const maxMinor = 1000000000000;
const _maxLedgerMinor = 90000000000000;

int fractionDigits(String currency) =>
    ['JPY', 'KRW'].contains(currency) ? 0 : 2;

int? parseMoney(String value, String currency) {
  final match = RegExp(
    r'^(-?)(\d{1,13})(?:\.(\d{1,2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final digits = fractionDigits(currency);
  final fraction = match[3] ?? '';
  if (fraction.length > digits) return null;
  final whole = int.parse(match[2]!) * (digits == 0 ? 1 : 100);
  final minor =
      whole + (digits == 0 ? 0 : int.parse(fraction.padRight(digits, '0')));
  if (minor > maxMinor) return null;
  return match[1]!.isEmpty ? minor : -minor;
}

String decimalMoney(int minor, String currency) {
  if (fractionDigits(currency) == 0) return '$minor';
  final absolute = minor.abs();
  return '${minor < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

String newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

typedef Json = Map<String, dynamic>;

class Wallet {
  const Wallet(
    this.id,
    this.name,
    this.type,
    this.currency,
    this.opening,
    this.color,
    this.icon,
    this.created, {
    this.archived = false,
    this.limit,
  });

  final String id, name, currency, icon;
  final WalletType type;
  final int opening, color;
  final int? limit;
  final DateTime created;
  final bool archived;

  Wallet.fromJson(Json json)
    : this(
        json['id'],
        json['name'],
        WalletType.values.byName(json['type']),
        json['currency'],
        json['opening'],
        json['color'],
        json['icon'],
        DateTime.parse(json['created']),
        archived: json['archived'],
        limit: json['limit'],
      );

  Json toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'currency': currency,
    'opening': opening,
    'color': color,
    'icon': icon,
    'created': created.toIso8601String(),
    'archived': archived,
    'limit': limit,
  };
}

class Category {
  const Category(
    this.id,
    this.name,
    this.type,
    this.color,
    this.icon, {
    this.archived = false,
    this.isDefault = false,
  });

  final String id, name, icon;
  final EntryType type;
  final int color;
  final bool archived, isDefault;

  Category.fromJson(Json json)
    : this(
        json['id'],
        json['name'],
        EntryType.values.byName(json['type']),
        json['color'],
        json['icon'],
        archived: json['archived'],
        isDefault: json['default'],
      );

  Json toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'color': color,
    'icon': icon,
    'archived': archived,
    'default': isDefault,
  };
}

class Entry {
  const Entry(
    this.id,
    this.type,
    this.amount,
    this.walletId,
    this.date,
    this.created,
    this.updated, {
    this.destinationId,
    this.categoryId,
    this.description = '',
    this.notes = '',
    this.labelIds = const [],
    this.nature,
  });

  final String id, walletId, description, notes;
  final String? destinationId, categoryId;
  final List<String> labelIds;
  final SpendingNature? nature;

  Entry withoutLabel(String id) => Entry(
    this.id,
    type,
    amount,
    walletId,
    date,
    created,
    updated,
    destinationId: destinationId,
    categoryId: categoryId,
    description: description,
    notes: notes,
    nature: nature,
    labelIds: List.unmodifiable(labelIds.where((label) => label != id)),
  );
  final EntryType type;
  final int amount;
  final DateTime date, created, updated;

  Entry.fromJson(Json json)
    : this(
        json['id'],
        EntryType.values.byName(json['type']),
        json['amount'],
        json['walletId'],
        DateTime.parse(json['date']).toLocal(),
        DateTime.parse(json['created']),
        DateTime.parse(json['updated']),
        destinationId: json['destinationId'],
        categoryId: json['categoryId'],
        description: json['description'],
        notes: json['notes'],
        labelIds: List.unmodifiable(
          (json['labelIds'] as List? ?? []).cast<String>(),
        ),
        nature: json['nature'] == null
            ? null
            : SpendingNature.values.byName(json['nature']),
      );

  Json toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'walletId': walletId,
    'destinationId': destinationId,
    'categoryId': categoryId,
    'description': description,
    'notes': notes,
    'labelIds': labelIds,
    'nature': nature?.name,
    'date': date.toUtc().toIso8601String(),
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
  };
}

class Budget {
  const Budget(
    this.id,
    this.currency,
    this.month,
    this.amount,
    this.created, {
    this.categoryId,
    this.walletId,
    this.labelId,
    this.name = '',
    this.cadence = BudgetCadence.monthly,
    this.start,
    this.end,
    this.notifyOverspent = false,
    this.notifyRisk = false,
  });
  final String id, currency, month, name;
  final int amount;
  final String? categoryId, walletId, labelId;
  final DateTime created;
  final DateTime? start, end;
  final BudgetCadence cadence;
  final bool notifyOverspent, notifyRisk;

  Budget withoutLabel() => Budget(
    id,
    currency,
    month,
    amount,
    created,
    categoryId: categoryId,
    walletId: walletId,
    name: name,
    cadence: cadence,
    start: start,
    end: end,
    notifyOverspent: notifyOverspent,
    notifyRisk: notifyRisk,
  );

  Budget.fromJson(Json json)
    : this(
        json['id'],
        json['currency'],
        json['month'],
        json['amount'],
        DateTime.parse(json['created']),
        categoryId: json['categoryId'],
        walletId: json['walletId'],
        labelId: json['labelId'],
        name: json['name'] ?? '',
        cadence: BudgetCadence.values.byName(json['cadence'] ?? 'monthly'),
        start: json['start'] == null ? null : DateTime.parse(json['start']),
        end: json['end'] == null ? null : DateTime.parse(json['end']),
        notifyOverspent: json['notifyOverspent'] ?? false,
        notifyRisk: json['notifyRisk'] ?? false,
      );

  Json toJson() => {
    'id': id,
    'currency': currency,
    'month': month,
    'amount': amount,
    'created': created.toIso8601String(),
    'categoryId': categoryId,
    'walletId': walletId,
    'labelId': labelId,
    'name': name,
    'cadence': cadence.name,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'notifyOverspent': notifyOverspent,
    'notifyRisk': notifyRisk,
  };
}

class ChatMessage {
  const ChatMessage(this.id, this.user, this.text, this.time);
  final String id, text;
  final bool user;
  final DateTime time;

  ChatMessage.fromJson(Json json)
    : this(
        json['id'],
        json['user'],
        json['text'],
        DateTime.parse(json['time']),
      );
  Json toJson() => {
    'id': id,
    'user': user,
    'text': text,
    'time': time.toIso8601String(),
  };
}

const palette = [
  0xff246b52,
  0xff3b62bb,
  0xff9451a4,
  0xffb55332,
  0xff087c89,
  0xff946416,
];

List<Category> defaultCategories() {
  const expense = [
    'Food & Drinks',
    'Groceries',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Housing',
    'Utilities',
    'Healthcare',
    'Education',
    'Subscriptions',
    'Travel',
    'Personal Care',
    'Gifts',
    'Miscellaneous',
  ];
  const income = [
    'Salary',
    'Freelance',
    'Business',
    'Investments',
    'Gifts',
    'Refunds',
    'Other Income',
  ];
  return [
    for (final (type, names) in [
      (EntryType.expense, expense),
      (EntryType.income, income),
    ])
      for (final (index, name) in names.indexed)
        Category(
          '${type.name}-$index',
          name,
          type,
          palette[index % palette.length],
          type == EntryType.income ? 'income' : 'category',
          isDefault: true,
        ),
  ];
}

class Ledger {
  Ledger({
    Iterable<Wallet> wallets = const [],
    Iterable<Category>? categories,
    Iterable<Entry> entries = const [],
    Iterable<Budget> budgets = const [],
    Iterable<ChatMessage> messages = const [],
    Iterable<LedgerLabel> labels = const [],
    Iterable<SavingsGoal> goals = const [],
  }) : wallets = List.unmodifiable(wallets),
       categories = List.unmodifiable(categories ?? defaultCategories()),
       entries = List.unmodifiable(entries),
       budgets = List.unmodifiable(budgets),
       messages = List.unmodifiable(messages),
       labels = List.unmodifiable(labels),
       goals = List.unmodifiable(goals);

  final List<Wallet> wallets;
  final List<Category> categories;
  final List<Entry> entries;
  final List<Budget> budgets;
  final List<ChatMessage> messages;
  final List<LedgerLabel> labels;
  final List<SavingsGoal> goals;

  Ledger copy({
    Iterable<Wallet>? wallets,
    Iterable<Category>? categories,
    Iterable<Entry>? entries,
    Iterable<Budget>? budgets,
    Iterable<ChatMessage>? messages,
    Iterable<LedgerLabel>? labels,
    Iterable<SavingsGoal>? goals,
  }) => Ledger(
    wallets: wallets ?? this.wallets,
    categories: categories ?? this.categories,
    entries: entries ?? this.entries,
    budgets: budgets ?? this.budgets,
    messages: messages ?? this.messages,
    labels: labels ?? this.labels,
    goals: goals ?? this.goals,
  );

  Wallet? wallet(String? id) =>
      wallets.where((wallet) => wallet.id == id).firstOrNull;
  Category? category(String? id) =>
      categories.where((category) => category.id == id).firstOrNull;

  LedgerLabel? label(String? id) =>
      labels.where((label) => label.id == id).firstOrNull;

  Ledger deleteLabel(String id) => copy(
    labels: labels.where((label) => label.id != id),
    entries: entries.map(
      (entry) => entry.labelIds.contains(id) ? entry.withoutLabel(id) : entry,
    ),
    budgets: budgets.map(
      (budget) => budget.labelId == id ? budget.withoutLabel() : budget,
    ),
  );

  String encode({bool includeChat = false, bool? demo}) => jsonEncode({
    'schemaVersion': 2,
    'demo': ?demo,
    'wallets': wallets.map((item) => item.toJson()).toList(),
    'categories': categories.map((item) => item.toJson()).toList(),
    'transactions': entries.map((item) => item.toJson()).toList(),
    'budgets': budgets.map((item) => item.toJson()).toList(),
    'labels': labels.map((item) => item.toJson()).toList(),
    'goals': goals.map((item) => item.toJson()).toList(),
    if (includeChat) 'messages': messages.map((item) => item.toJson()).toList(),
  });

  static Ledger decode(String source, {bool? expectedDemo}) {
    final json = jsonDecode(source) as Json;
    if (expectedDemo != null && (json['demo'] ?? false) != expectedDemo) {
      throw const FormatException(
        'Restore the backup in the matching personal or demo ledger.',
      );
    }
    final version = json['schemaVersion'];
    if (![1, 2].contains(version)) {
      throw const FormatException('Unsupported backup version.');
    }
    final result = Ledger(
      wallets: (json['wallets'] as List).cast<Json>().map(Wallet.fromJson),
      categories: (json['categories'] as List).cast<Json>().map(
        Category.fromJson,
      ),
      entries: (json['transactions'] as List).cast<Json>().map(Entry.fromJson),
      budgets: (json['budgets'] as List).cast<Json>().map(Budget.fromJson),
      labels: ((json['labels'] ?? []) as List).cast<Json>().map(
        LedgerLabel.fromJson,
      ),
      goals: ((json['goals'] ?? []) as List).cast<Json>().map(
        SavingsGoal.fromJson,
      ),
      messages: ((json['messages'] ?? []) as List).cast<Json>().map(
        ChatMessage.fromJson,
      ),
    );
    result.validate();
    return result;
  }

  void validate() {
    void require(bool valid, String message) {
      if (!valid) throw FormatException(message);
    }

    for (final ids in [
      wallets.map((w) => w.id),
      categories.map((c) => c.id),
      entries.map((e) => e.id),
      budgets.map((b) => b.id),
      messages.map((m) => m.id),
      labels.map((label) => label.id),
      goals.map((goal) => goal.id),
    ]) {
      require(
        ids.length == ids.toSet().length && ids.every((id) => id.isNotEmpty),
        'Missing or duplicate IDs.',
      );
    }
    final walletById = {for (final wallet in wallets) wallet.id: wallet};
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    var totalMinor = 0;
    for (final wallet in wallets) {
      require(
        wallet.name.trim().isNotEmpty &&
            currencies.contains(wallet.currency) &&
            wallet.opening.abs() <= maxMinor &&
            wallet.color >= 0 &&
            wallet.color <= 0xffffffff,
        'Invalid wallet.',
      );
      totalMinor += wallet.opening.abs();
      require(
        totalMinor <= _maxLedgerMinor,
        'Ledger exceeds the supported amount range.',
      );
      require(
        wallet.limit == null ||
            (wallet.type == WalletType.credit &&
                wallet.limit! > 0 &&
                wallet.limit! <= maxMinor),
        'Invalid credit limit.',
      );
    }
    for (final category in categories) {
      require(
        category.name.trim().isNotEmpty &&
            category.type != EntryType.transfer &&
            category.color >= 0 &&
            category.color <= 0xffffffff,
        'Invalid category.',
      );
    }
    final labelIds = labels.map((label) => label.id).toSet();
    final labelNames = <String>{};
    for (final label in labels) {
      require(
        label.name.trim().isNotEmpty &&
            labelNames.add(label.name.trim().toLowerCase()) &&
            label.color >= 0 &&
            label.color <= 0xffffffff,
        'Invalid or duplicate label name.',
      );
    }
    for (final goal in goals) {
      require(
        goal.name.trim().isNotEmpty &&
            currencies.contains(goal.currency) &&
            goal.target > 0 &&
            goal.target <= maxMinor &&
            goal.saved >= 0 &&
            goal.saved <= maxMinor &&
            goal.color >= 0 &&
            goal.color <= 0xffffffff,
        'Invalid savings goal.',
      );
    }
    for (final entry in entries) {
      require(
        entry.labelIds.toSet().length == entry.labelIds.length &&
            entry.labelIds.every(labelIds.contains) &&
            (entry.nature == null || entry.type == EntryType.expense),
        'Invalid transaction labels or spending nature.',
      );
      final source = walletById[entry.walletId];
      require(
        source != null && entry.amount > 0 && entry.amount <= maxMinor,
        'Invalid transaction amount or wallet.',
      );
      totalMinor += entry.amount;
      require(
        totalMinor <= _maxLedgerMinor,
        'Ledger exceeds the supported amount range.',
      );
      if (entry.type == EntryType.transfer) {
        final destination = walletById[entry.destinationId];
        require(
          destination != null &&
              destination.id != source!.id &&
              destination.currency == source.currency &&
              source.type != WalletType.credit &&
              entry.categoryId == null,
          'Transfers require two different wallets in the same currency and a non-credit source.',
        );
      } else {
        require(
          entry.destinationId == null &&
              categoryById[entry.categoryId]?.type == entry.type,
          'Transaction category does not match its type.',
        );
      }
    }
    final legacyBudgetKeys = <(String, String, String?)>{};
    for (final budget in budgets) {
      require(
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(budget.month) &&
            currencies.contains(budget.currency) &&
            budget.amount > 0 &&
            budget.amount <= maxMinor &&
            (budget.categoryId == null ||
                categoryById[budget.categoryId]?.type == EntryType.expense) &&
            (budget.walletId == null ||
                walletById[budget.walletId]?.currency == budget.currency) &&
            (budget.labelId == null || labelIds.contains(budget.labelId)) &&
            ((budget.start == null &&
                    budget.end == null &&
                    budget.cadence == BudgetCadence.monthly &&
                    legacyBudgetKeys.add((
                      budget.month,
                      budget.currency,
                      budget.categoryId,
                    ))) ||
                (budget.start != null &&
                    budget.end != null &&
                    budget.end!.isAfter(budget.start!))),
        'Invalid budget.',
      );
    }
  }
}
