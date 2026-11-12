import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/src/app.dart';
import 'package:moneymate/src/core/models.dart';
import 'package:moneymate/src/data/state.dart';
import 'package:moneymate/src/features/assistant/ai_service.dart';
import 'package:moneymate/src/features/assistant/model_panel.dart';

import 'support/memory_store.dart';

class FakeAi implements AiService {
  String? context;

  @override
  bool get supported => true;
  @override
  Future<bool> installed() async => true;
  @override
  Future<void> download(void Function(double) onProgress) async =>
      onProgress(1);
  @override
  Future<void> remove() async {}
  @override
  Future<int?> chooseSuggestion(
    String question,
    String financialContext,
    List<String> suggestions,
  ) async {
    context = financialContext;
    return suggestions.length - 1;
  }
}

void main() {
  testWidgets('mobile wallet form creates a wallet and updates the overview', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWith((ref) async => MemoryStore())],
        child: const MoneyMateApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('List of Accounts'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .whereType<NavigationDestination>()
          .last
          .label,
      'AI Chat',
    );
    await tester.tap(find.text('Add Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pocket cash');
    final save = find.text('Save wallet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Pocket cash'), findsOneWidget);
    await tester.tap(find.byTooltip('Add transaction'));
    await tester.pumpAndSettle();
    for (final key in ['1', '+', '2', '=']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(find.text('3.00'), findsOneWidget);
    await tester.tap(find.text('Select category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food & Drinks'));
    await tester.pumpAndSettle();
    expect(find.text('3.00'), findsOneWidget);
    final included = find.widgetWithText(
      CheckboxListTile,
      'Already included in the balance?',
    );
    expect(tester.widget<CheckboxListTile>(included).value, isFalse);
    await tester.ensureVisible(included);
    await tester.tap(included);
    await tester.pumpAndSettle();
    final need = find.widgetWithText(ChoiceChip, 'Need');
    await tester.ensureVisible(need);
    await tester.tap(need);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Records'));
    await tester.pumpAndSettle();
    expect(find.text('Food & Drinks'), findsOneWidget);
    await tester.tap(find.text('Food & Drinks'));
    await tester.pumpAndSettle();
    expect(find.text('Need'), findsOneWidget);
    expect(find.text('Already included in my balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Planning persists a label, budget alert and two-step goal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWith((ref) async => store)],
        child: const MoneyMateApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Planning'));
    await tester.pumpAndSettle();

    Future<void> tapText(String value) async {
      final target = find.text(value);
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.45);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String text) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tapText('Create Label');
    await enter('Label name', 'Travel');
    await tapText('Save label');

    await tapText('Create Budget');
    await enter('Budget limit', '120');
    await tapText('Risk of Overspending');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    await tapText('Create Goal');
    await tapText('Holiday Trip');
    await enter('Target amount', '400');
    await enter('Saved already', '125');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final ledger = Ledger.decode(store.values['ledger']!);
    expect(ledger.labels.single.name, 'Travel');
    expect(ledger.budgets.single.amount, 12000);
    expect(ledger.budgets.single.notifyRisk, isTrue);
    expect(ledger.goals.single.name, 'Holiday Trip');
    expect(ledger.goals.single.saved, 12500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop demo navigation, charts, and mocked AI context', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1350, 1000);
    addTearDown(tester.view.reset);
    final ai = FakeAi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeProvider.overrideWith((ref) async => MemoryStore()),
          aiProvider.overrideWithValue(ai),
        ],
        child: const MoneyMateApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo mode'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode · Fictional data'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses Structure'), findsOneWidget);
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Spending by Categories or Labels'), findsOneWidget);
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(find.text('Balance by Accounts'), findsOneWidget);
    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();
    expect(find.text('Create Budget'), findsOneWidget);
    expect(find.text('Create Goal'), findsOneWidget);
    expect(find.text('Create Label'), findsOneWidget);
    await tester.tap(find.text('AI Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Where am I spending the most?'));
    await tester.pumpAndSettle();
    expect(ai.context, contains('"expenseMinor":'));
    expect(
      find.textContaining(
        'Set aside money for regular bills',
        findRichText: true,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
