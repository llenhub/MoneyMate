import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/calculator.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/editor_page.dart';
import '../../ui/report_widgets.dart';
import '../../ui/shared.dart';
import '../planning/labels.dart';
import '../settings/settings_screen.dart';
import '../wallets/wallets_screen.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor(this.original, this.preferences, {super.key});
  final Entry? original;
  final Preferences preferences;

  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  late final _description = TextEditingController(
    text: widget.original?.description,
  );
  late final _notes = TextEditingController(text: widget.original?.notes);
  late final _labels = {...?widget.original?.labelIds};
  late var _type = widget.original?.type ?? EntryType.expense;
  late var _date = widget.original?.date ?? DateTime.now();
  late var _walletId = widget.original?.walletId;
  late var _destinationId = widget.original?.destinationId;
  late var _categoryId = widget.original?.categoryId;
  late var _nature = widget.original?.nature;
  late var _includedInBalance = widget.original?.includedInBalance ?? false;
  String? _expression, _error;
  bool _busy = false, _evaluated = false;

  @override
  void dispose() {
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Iterable<Wallet> _sourceOptions(Ledger ledger) => ledger.wallets.where(
    (wallet) =>
        (!wallet.archived || wallet.id == widget.original?.walletId) &&
        (_type != EntryType.transfer || wallet.type != WalletType.credit),
  );

  Wallet? _source(Ledger ledger) {
    final options = _sourceOptions(ledger);
    return options.where((wallet) => wallet.id == _walletId).firstOrNull ??
        options.firstOrNull;
  }

  String _initialAmount(Ledger ledger) {
    final original = widget.original;
    if (original == null) return '';
    return decimalMoney(
      original.amount,
      ledger.wallet(original.walletId)?.currency ?? widget.preferences.currency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider).requireValue;
    final ledger = finance.ledger;
    final wallet = _source(ledger);
    final currency = wallet?.currency ?? widget.preferences.currency;
    final expression = _expression ?? _initialAmount(ledger);
    final target = ledger.wallet(_destinationId);
    final category = ledger.category(_categoryId);
    final selectedCategory = category?.type == _type ? category : null;
    final colors = Theme.of(context).colorScheme;
    final wasIncluded = widget.original?.includedInBalance ?? false;

    return EditorPage(
      title: widget.original == null ? 'New Transaction' : 'Edit Transaction',
      onSave: () => _save(wallet, currency, expression),
      busy: _busy,
      error: _error,
      children: [
        SegmentedButton<EntryType>(
          showSelectedIcon: false,
          segments: [
            for (final type in EntryType.values)
              ButtonSegment(value: type, label: Text(titleCase(type.name))),
          ],
          selected: {_type},
          onSelectionChanged: (selection) => setState(() {
            _walletId = wallet?.id;
            _type = selection.single;
            _error = null;
          }),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Text(
                  currency,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _display(expression),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _pickerButton(
                title: _type == EntryType.transfer ? 'From account' : 'Account',
                value: wallet?.name ?? 'Select account',
                icon: namedIcon(wallet?.icon ?? 'wallet'),
                onTap: () => _pickAccount(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _type == EntryType.transfer
                  ? _pickerButton(
                      title: 'To account',
                      value:
                          target?.currency == wallet?.currency &&
                              target?.id != wallet?.id
                          ? target?.name ?? 'Select account'
                          : 'Select account',
                      icon: Icons.swap_horiz,
                      onTap: wallet == null
                          ? null
                          : () => _pickAccount(source: wallet),
                    )
                  : _pickerButton(
                      title: 'Category',
                      value: selectedCategory?.name ?? 'Select category',
                      icon: namedIcon(selectedCategory?.icon ?? 'category'),
                      onTap: _pickCategory,
                    ),
            ),
          ],
        ),
        _keypad(expression, currency),
        TextField(
          controller: _description,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
          ),
        ),
        if (_type != EntryType.transfer)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Already included in the balance?'),
            subtitle: Text(
              wasIncluded && !_includedInBalance
                  ? 'Saving with this unchecked will apply the amount to your balance.'
                  : 'Add an older transaction without changing your current balance.',
            ),
            value: _includedInBalance,
            onChanged: (value) => setState(() {
              _includedInBalance = value ?? false;
              _error = null;
            }),
          )
        else if (wasIncluded)
          const Text('Saving as a transfer will change both account balances.'),
        OutlinedButton.icon(
          icon: const Icon(Icons.sell_outlined),
          label: Text(
            _labels.isEmpty
                ? 'Add Labels'
                : _labels
                      .map((id) => ledger.label(id)?.name)
                      .whereType<String>()
                      .join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () async {
            final selected = await pickLabels(context, _labels);
            if (selected != null && mounted) {
              setState(() {
                _labels.clear();
                _labels.addAll(selected);
              });
            }
          },
        ),
        if (_type == EntryType.expense) ...[
          Text(
            'Spending nature',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final nature in SpendingNature.values)
                ChoiceChip(
                  label: Text(titleCase(nature.name)),
                  selected: _nature == nature,
                  onSelected: (selected) =>
                      setState(() => _nature = selected ? nature : null),
                ),
            ],
          ),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Date, time and notes'),
          subtitle: Text(dateLabel(_date, widget.preferences.dateFormat)),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                  label: Text(dateLabel(_date, widget.preferences.dateFormat)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  onPressed: _pickTime,
                  label: Text(TimeOfDay.fromDateTime(_date).format(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLength: 800,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        if (_type == EntryType.transfer)
          const Text(
            'Transfers require distinct accounts in the same currency and a non-credit source.',
          ),
      ],
    );
  }

  String _display(String expression) {
    if (expression.isEmpty) return '0';
    final match = RegExp(r'^(-?\d+)(\.\d*)?$').firstMatch(expression);
    if (match == null) return expression;
    final value = int.tryParse(match[1]!);
    if (value == null) return expression;
    return '${NumberFormat.decimalPattern('en').format(value)}${match[2] ?? ''}';
  }

  Widget _keypad(String expression, String currency) => GridView(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 5,
      crossAxisSpacing: 6,
      mainAxisExtent: 48,
    ),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (final key in [
        '7',
        '8',
        '9',
        '÷',
        '4',
        '5',
        '6',
        '×',
        '1',
        '2',
        '3',
        '−',
        '.',
        '0',
        '⌫',
        '+',
      ])
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 20),
          ),
          onPressed: _busy ? null : () => _key(expression, currency, key),
          child: key == '⌫'
              ? const Icon(
                  Icons.backspace_outlined,
                  semanticLabel: 'Backspace',
                  size: 20,
                )
              : Text(key),
        ),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _expression = '';
                _error = null;
                _evaluated = false;
              }),
        child: const Text('Clear'),
      ),
      FilledButton(
        onPressed: _busy ? null : () => _key(expression, currency, '='),
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: const Text('='),
      ),
    ],
  );

  void _key(String expression, String currency, String key) {
    setState(() {
      _error = null;
      if (key == '⌫') {
        _expression = expression.isEmpty
            ? ''
            : expression.substring(0, expression.length - 1);
        _evaluated = false;
        return;
      }
      if (key == '=') {
        try {
          _expression = decimalMoney(
            evaluateAmount(expression, currency),
            currency,
          );
          _evaluated = true;
        } on FormatException catch (error) {
          _error = error.message;
        }
        return;
      }
      const operators = '+−×÷';
      final isOperator = operators.contains(key);
      final input = _evaluated && !isOperator ? '' : expression;
      _evaluated = false;
      if (isOperator) {
        if (input.isEmpty || input == '-') return;
        _expression = operators.contains(input[input.length - 1])
            ? input.substring(0, input.length - 1) + key
            : input + key;
        return;
      }
      if (input.length >= 72) return;
      if (key == '.' && input.split(RegExp('[+−×÷]')).last.contains('.')) {
        return;
      }
      _expression = input + key;
    });
  }

  Future<void> _pickAccount({Wallet? source}) async {
    final id = await openEditorPage<String>(
      context,
      _AccountPicker(
        original: source == null
            ? widget.original?.walletId
            : widget.original?.destinationId,
        type: _type,
        source: source,
      ),
    );
    if (id == null || !mounted) return;
    setState(() {
      _error = null;
      if (source == null) {
        if (_walletId != id) _destinationId = null;
        _walletId = id;
      } else {
        _destinationId = id;
      }
    });
  }

  Future<void> _pickCategory() async {
    final id = await openEditorPage<String>(
      context,
      _CategoryPicker(_type, widget.original?.categoryId),
    );
    if (id != null && mounted) {
      setState(() {
        _categoryId = id;
        _error = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date != null && mounted) {
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      setState(
        () => _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save(Wallet? source, String currency, String expression) async {
    try {
      if (source == null) throw const FormatException('Select an account.');
      final amount = evaluateAmount(expression, currency);
      if (amount <= 0) {
        throw const FormatException('Enter an amount greater than zero.');
      }
      final previous = widget.original;
      final now = DateTime.now().toUtc();
      final includedInBalance =
          _type != EntryType.transfer && _includedInBalance;
      if (includedInBalance && _date.isAfter(now)) {
        throw const FormatException(
          'Choose a past date and time for a transaction already in your balance.',
        );
      }
      final id = previous?.id ?? newId();
      setState(() {
        _busy = true;
        _error = null;
      });
      await ref.read(financeProvider.notifier).change((ledger) {
        final destination = ledger.wallet(_destinationId);
        if (_type == EntryType.transfer &&
            (destination == null ||
                destination.id == source.id ||
                destination.currency != currency ||
                source.type == WalletType.credit ||
                (destination.archived &&
                    destination.id != previous?.destinationId))) {
          throw const FormatException(
            'Select a different destination account in the same currency.',
          );
        }
        final category = ledger.category(_categoryId);
        if (_type != EntryType.transfer &&
            (category?.type != _type ||
                (category!.archived && category.id != previous?.categoryId))) {
          throw const FormatException(
            'Select a category for this transaction type.',
          );
        }
        final entry = Entry(
          id,
          _type,
          amount,
          source.id,
          _date,
          previous?.created ?? now,
          now,
          destinationId: _type == EntryType.transfer ? destination?.id : null,
          categoryId: _type == EntryType.transfer ? null : _categoryId,
          description: _description.text.trim(),
          notes: _notes.text.trim(),
          labelIds: List.unmodifiable(
            _labels.where((id) => ledger.label(id) != null),
          ),
          nature: _type == EntryType.expense ? _nature : null,
          includedInBalance: includedInBalance,
        );
        if (previous != null && !ledger.entries.any((item) => item.id == id)) {
          throw const FormatException('This record was removed while editing.');
        }
        return ledger.copy(
          entries: [
            for (final item in ledger.entries) item.id == id ? entry : item,
            if (previous == null) entry,
          ],
        );
      }, expectedDemo: widget.preferences.demo);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is FormatException ? error.message : error.toString();
        });
      }
    }
  }
}

Widget _pickerButton({
  required String title,
  required String value,
  required IconData icon,
  required VoidCallback? onTap,
}) => OutlinedButton(
  onPressed: onTap,
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  ),
  child: Row(
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  ),
);

class _AccountPicker extends ConsumerWidget {
  const _AccountPicker({required this.type, this.original, this.source});
  final EntryType type;
  final String? original;
  final Wallet? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider).requireValue;
    final options = finance.ledger.wallets.where(
      (wallet) =>
          (!wallet.archived || wallet.id == original) &&
          (source != null
              ? wallet.id != source!.id && wallet.currency == source!.currency
              : type != EntryType.transfer || wallet.type != WalletType.credit),
    );
    return EditorPage(
      title: 'Account',
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add account',
        onPressed: () => openWalletEditor(context, finance),
        child: const Icon(Icons.add),
      ),
      children: [
        if (options.isEmpty)
          const Text('No eligible accounts. Add an account to continue.'),
        for (final wallet in options)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(wallet.color),
              foregroundColor: Colors.white,
              child: Icon(namedIcon(wallet.icon)),
            ),
            title: Text(wallet.name),
            subtitle: Text('${wallet.type.label} · ${wallet.currency}'),
            onTap: () => Navigator.pop(context, wallet.id),
          ),
        const SizedBox(height: 56),
      ],
    );
  }
}

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker(this.type, this.original);
  final EntryType type;
  final String? original;
  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(financeProvider).requireValue.ledger;
    final options = ledger.categories
        .where(
          (category) =>
              category.type == widget.type &&
              (!category.archived || category.id == widget.original) &&
              category.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    final uses = <String, int>{};
    for (final entry in ledger.entries.where(
      (entry) => entry.type == widget.type,
    )) {
      if (entry.categoryId case final String id) {
        uses.update(id, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final frequent =
        options.where((category) => uses.containsKey(category.id)).toList()
          ..sort((a, b) => uses[b.id]!.compareTo(uses[a.id]!));
    Widget icon(Category category) => CircleAvatar(
      backgroundColor: categoryColor(ledger, category.id),
      foregroundColor: Colors.white,
      child: Icon(namedIcon(category.icon)),
    );
    return EditorPage(
      title: 'Category',
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (query) => setState(() => _query = query),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search categories',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Manage categories',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => openCategories(context),
            ),
          ],
        ),
        if (frequent.isNotEmpty && _query.isEmpty) ...[
          Text('Most Frequent', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in frequent.take(6))
                  SizedBox(
                    width: 95,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, category.id),
                      child: Column(
                        children: [
                          icon(category),
                          const SizedBox(height: 6),
                          Text(
                            category.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Text('All Categories', style: Theme.of(context).textTheme.titleMedium),
        if (options.isEmpty) const Text('No matching categories.'),
        for (final category in options)
          ListTile(
            leading: icon(category),
            title: Text(category.name),
            onTap: () => Navigator.pop(context, category.id),
          ),
      ],
    );
  }
}
