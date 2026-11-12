import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/src/app.dart';
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
    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is NavigationDestination && widget.label == 'Wallets',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No wallets yet'), findsOneWidget);
    await tester.tap(find.text('New wallet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pocket cash');
    final save = find.text('Save wallet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Pocket cash'), findsOneWidget);
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
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo mode'));
    await tester.pumpAndSettle();
    expect(find.text('Demo mode · Fictional data'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Spending by category'), findsOneWidget);
    await tester.tap(find.text('AI Assistant'));
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
