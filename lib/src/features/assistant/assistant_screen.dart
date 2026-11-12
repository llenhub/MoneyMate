import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/models.dart';
import '../../data/state.dart';
import '../../ui/shared.dart';
import 'answers.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String question) async {
    final prompt = question.trim();
    if (prompt.isEmpty || _sending) return;
    final state = ref.read(financeProvider).requireValue;
    final controller = ref.read(financeProvider.notifier);
    setState(() {
      _sending = true;
    });
    _input.clear();
    final analytics = Analytics(state.ledger);
    final currency = state.preferences.currency;
    final now = DateTime.now();
    try {
      final answer = spendingAnswer(analytics, now, currency, prompt);
      await controller.change(
        (ledger) => ledger.copy(
          messages: [
            ...ledger.messages,
            ChatMessage(newId(), true, prompt, now),
            ChatMessage(newId(), false, answer, DateTime.now()),
          ],
        ),
        expectedDemo: state.preferences.demo,
      );
    } catch (error) {
      if (mounted) {
        _input.text = prompt;
        showProblem(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider).requireValue;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Assistant',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear conversation',
                      onPressed: _sending || state.ledger.messages.isEmpty
                          ? null
                          : () async {
                              if (!await confirm(
                                    context,
                                    'Clear conversation?',
                                    'This deletes chat history for the active ledger.',
                                    'Clear',
                                  ) ||
                                  !context.mounted) {
                                return;
                              }
                              await runAction(
                                context,
                                () => ref
                                    .read(financeProvider.notifier)
                                    .change(
                                      (ledger) => ledger.copy(messages: []),
                                      expectedDemo: state.preferences.demo,
                                    ),
                              );
                            },
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Spending answers use your local ledger.'),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    children: [
                      if (state.ledger.messages.isEmpty)
                        Panel(
                          child: Column(
                            children: [
                              const EmptyPanel(
                                Icons.auto_awesome_outlined,
                                'Ask about your spending',
                                'Get answers from the transactions and budgets in this ledger.',
                              ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final question in starterQuestions)
                                    ActionChip(
                                      label: Text(question),
                                      onPressed: _sending
                                          ? null
                                          : () => _send(question),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      for (final message in state.ledger.messages)
                        Align(
                          alignment: message.user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 620),
                            decoration: BoxDecoration(
                              color: message.user
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(message.text),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 400,
                        enabled: !_sending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                          labelText: 'Ask a spending question',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending ? null : () => _send(_input.text),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
