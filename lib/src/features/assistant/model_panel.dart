import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/shared.dart';
import 'ai_service.dart';

final aiProvider = Provider<AiService>((ref) => createAiService());
final modelInstalledProvider = FutureProvider<bool>(
  (ref) => ref.watch(aiProvider).installed(),
);
final modelBusyProvider = NotifierProvider<ModelActivity, bool>(
  ModelActivity.new,
);

class ModelActivity extends Notifier<bool> {
  @override
  bool build() => false;

  Future<T> run<T>(Future<T> Function() action) async {
    if (state) throw const FormatException('The local model is busy.');
    state = true;
    try {
      return await action();
    } finally {
      state = false;
    }
  }
}

class ModelPanel extends ConsumerStatefulWidget {
  const ModelPanel({super.key});
  @override
  ConsumerState<ModelPanel> createState() => _ModelPanelState();
}

class _ModelPanelState extends ConsumerState<ModelPanel> {
  double? _progress;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(aiProvider);
    final installed = ref.watch(modelInstalledProvider);
    final busy = ref.watch(modelBusyProvider);
    return Panel(
      title: 'On-device AI model',
      child: !service.supported
          ? const Text(
              'Local language model inference is unavailable on this platform. The assistant still provides spending analytics.',
            )
          : formFields([
              const Text('Qwen3 0.6B · Q4_K_M GGUF · 397 MB'),
              Text(
                installed.value == true
                    ? 'Installed. Inference runs on this device.'
                    : 'Download the optional model over the internet. Installation needs 500 MB of free internal storage.',
              ),
              if (installed.isLoading || busy)
                LinearProgressIndicator(value: _progress),
              if (_progress != null)
                Text('${(_progress! * 100).round()}% downloaded'),
              if (installed.hasError)
                const Text('Could not check local model storage.'),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: busy || installed.isLoading
                      ? null
                      : () async {
                          final activity = ref.read(modelBusyProvider.notifier);
                          final container = ProviderScope.containerOf(
                            context,
                            listen: false,
                          );
                          await runAction(context, () async {
                            try {
                              if (installed.value == true) {
                                if (!await confirm(
                                      context,
                                      'Remove the AI model?',
                                      'You can download it again from Settings.',
                                      'Remove',
                                    ) ||
                                    !mounted) {
                                  return;
                                }
                                await activity.run(service.remove);
                              } else {
                                setState(() => _progress = 0);
                                await activity.run(
                                  () => service.download((value) {
                                    if (mounted) {
                                      setState(() => _progress = value);
                                    }
                                  }),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _progress = null);
                              container.invalidate(modelInstalledProvider);
                            }
                          });
                        },
                  child: Text(
                    installed.value == true ? 'Remove model' : 'Download model',
                  ),
                ),
              ),
            ]),
    );
  }
}
