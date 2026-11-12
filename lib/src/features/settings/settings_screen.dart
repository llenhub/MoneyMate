import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';
import 'backup.dart';
import 'demo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider).requireValue;
    final prefs = state.preferences;
    final controller = ref.read(financeProvider.notifier);
    return PageBody(
      title: 'Settings',
      subtitle: 'Customize MoneyMate and manage your local data.',
      children: [
        AdaptiveGrid(
          minWidth: 355,
          children: [
            Panel(
              title: 'Preferences',
              child: formFields([
                Choice(
                  'Appearance',
                  prefs.theme,
                  const {'system': 'System', 'light': 'Light', 'dark': 'Dark'},
                  (value) => runAction(
                    context,
                    () => controller.settings(prefs.copy(theme: value)),
                  ),
                ),
                Choice(
                  'Default and reporting currency',
                  prefs.currency,
                  {for (final currency in currencies) currency: currency},
                  (value) => runAction(
                    context,
                    () => controller.settings(prefs.copy(currency: value)),
                  ),
                ),
                Choice(
                  'Date format',
                  prefs.dateFormat,
                  {
                    for (final format in [
                      'MMM d, yyyy',
                      'yyyy-MM-dd',
                      'dd/MM/yyyy',
                      'MM/dd/yyyy',
                    ])
                      format: dateLabel(DateTime(2026, 11, 7), format),
                  },
                  (value) => runAction(
                    context,
                    () => controller.settings(prefs.copy(dateFormat: value)),
                  ),
                ),
              ]),
            ),
            Panel(
              title: 'Data and backup',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Demo mode'),
                    subtitle: const Text(
                      'Explore a separate fictional ledger.',
                    ),
                    value: prefs.demo,
                    onChanged: (enabled) => runAction(
                      context,
                      () => controller.settings(
                        prefs.copy(demo: enabled),
                        demoSeed: () => demoLedger(DateTime.now()),
                      ),
                    ),
                  ),
                  if (prefs.demo)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restart_alt),
                      title: const Text('Reset demo data'),
                      onTap: () async {
                        if (!await confirm(
                              context,
                              'Reset the demo?',
                              'This replaces the demo ledger with fresh sample data.',
                              'Reset',
                            ) ||
                            !context.mounted) {
                          return;
                        }
                        await runAction(
                          context,
                          () => controller.change(
                            (_) => demoLedger(DateTime.now()),
                            expectedDemo: true,
                          ),
                        );
                      },
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: Text(
                      prefs.demo ? 'Export demo backup' : 'Export JSON backup',
                    ),
                    onTap: () => runAction(context, () async {
                      final saved = await exportBackup(
                        state.ledger,
                        demo: prefs.demo,
                      );
                      if (saved && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup exported.')),
                        );
                      }
                    }),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(
                      prefs.demo
                          ? 'Restore into demo ledger'
                          : 'Restore JSON backup',
                    ),
                    onTap: () => runAction(context, () async {
                      final ledger = await selectBackup(demo: prefs.demo);
                      if (ledger == null || !context.mounted) return;
                      if (!await confirm(
                            context,
                            'Replace ${prefs.demo ? 'demo' : 'personal'} ledger?',
                            'The backup contains ${ledger.wallets.length} wallets and ${ledger.entries.length} transactions. '
                                'Restoring replaces the active ledger.',
                            'Restore',
                          ) ||
                          !context.mounted) {
                        return;
                      }
                      await controller.change(
                        (data) => ledger.copy(messages: data.messages),
                        expectedDemo: prefs.demo,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup restored.')),
                        );
                      }
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          minWidth: 355,
          children: [
            Panel(
              title: 'Categories',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sell_outlined),
                    title: const Text('Manage categories'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => editDialog<void>(
                      context,
                      'Manage categories',
                      const _Categories(),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pie_chart_outline),
                    title: const Text('Monthly budgets'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/budgets'),
                  ),
                ],
              ),
            ),
            Panel(
              title: 'About MoneyMate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MoneyMate 1.0.0'),
                  const SizedBox(height: 8),
                  const Text(
                    'Your wallets, transactions, budgets, and chat stay in local app or browser storage.',
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: state.ledger.messages.isEmpty
                        ? null
                        : () async {
                            if (!await confirm(
                                  context,
                                  'Clear chat history?',
                                  'This deletes the conversation in the active ledger.',
                                  'Clear',
                                ) ||
                                !context.mounted) {
                              return;
                            }
                            await runAction(
                              context,
                              () => controller.change(
                                (data) => data.copy(messages: []),
                                expectedDemo: prefs.demo,
                              ),
                            );
                          },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear chat history'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider).requireValue;
    void edit([Category? category]) => editDialog<void>(
      context,
      category == null ? 'New category' : 'Edit category',
      _CategoryForm(state, category),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: edit,
          icon: const Icon(Icons.add),
          label: const Text('New category'),
        ),
        for (final type in [EntryType.expense, EntryType.income]) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              titleCase(type.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final category in state.ledger.categories.where(
            (item) => item.type == type,
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                namedIcon(category.icon),
                color: Color(category.color),
              ),
              title: Text(category.name),
              subtitle: category.archived ? const Text('Archived') : null,
              onTap: () => edit(category),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'edit') {
                    edit(category);
                    return;
                  }
                  if (action == 'delete' &&
                      !await confirm(
                        context,
                        'Delete category?',
                        category.name,
                        'Delete',
                      )) {
                    return;
                  }
                  if (!context.mounted) return;
                  await runAction(
                    context,
                    () => ref
                        .read(financeProvider.notifier)
                        .change(
                          (data) => data.copy(
                            categories: [
                              for (final c in data.categories)
                                if (c.id != category.id)
                                  c
                                else if (action != 'delete')
                                  Category(
                                    c.id,
                                    c.name,
                                    c.type,
                                    c.color,
                                    c.icon,
                                    archived: !c.archived,
                                    isDefault: c.isDefault,
                                  ),
                            ],
                          ),
                          expectedDemo: state.preferences.demo,
                        ),
                  );
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(category.archived ? 'Unarchive' : 'Archive'),
                  ),
                  if (!state.ledger.entries.any(
                        (e) => e.categoryId == category.id,
                      ) &&
                      !state.ledger.budgets.any(
                        (b) => b.categoryId == category.id,
                      ))
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm(this.state, this.category);
  final FinanceState state;
  final Category? category;
  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final _name = TextEditingController(text: widget.category?.name);
  late var _type = widget.category?.type ?? EntryType.expense;
  late var _color = widget.category?.color ?? palette.first;
  late var _icon = widget.category?.icon ?? 'category';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => formFields([
    TextField(
      controller: _name,
      autofocus: true,
      maxLength: 60,
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    Choice<EntryType>(
      'Category type',
      _type,
      const {EntryType.expense: 'Expense', EntryType.income: 'Income'},
      widget.category == null ? (value) => setState(() => _type = value) : null,
    ),
    AppearanceFields(
      _color,
      _icon,
      (value) => setState(() => _color = value),
      (value) => setState(() => _icon = value),
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
              final name = _name.text.trim();
              if (name.isEmpty) {
                setState(() => _error = 'Enter a category name.');
                return;
              }
              setState(() {
                _busy = true;
                _error = null;
              });
              final old = widget.category;
              final category = Category(
                old?.id ?? newId(),
                name,
                _type,
                _color,
                _icon,
                archived: old?.archived ?? false,
                isDefault: old?.isDefault ?? false,
              );
              try {
                await ref
                    .read(financeProvider.notifier)
                    .change(
                      (data) => data.copy(
                        categories: [
                          for (final item in data.categories)
                            if (item.id == category.id) category else item,
                          if (old == null) category,
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
      child: const Text('Save category'),
    ),
  ]);
}
