import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';

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
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveGrid(
          minWidth: 355,
          children: [
            Panel(
              title: 'About MoneyMate',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MoneyMate 1.0.0'),
                  const SizedBox(height: 8),
                  const Text(
                    'Your wallets, transactions, and budgets stay in local app or browser storage.',
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
