import 'ai_unsupported.dart' if (dart.library.io) 'ai_native.dart' as platform;

abstract interface class AiService {
  bool get supported;
  Future<bool> installed();
  Future<void> download(void Function(double progress) onProgress);
  Future<void> remove();
  Future<int?> chooseSuggestion(
    String question,
    String financialContext,
    List<String> suggestions,
  );
}

AiService createAiService() => platform.createAiService();
