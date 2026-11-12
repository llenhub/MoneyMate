import 'ai_service.dart';

AiService createAiService() => const UnsupportedAi();

class UnsupportedAi implements AiService {
  const UnsupportedAi();

  @override
  bool get supported => false;
  @override
  Future<bool> installed() async => false;
  @override
  Future<void> download(void Function(double progress) onProgress) async =>
      throw UnsupportedError(
        'Local language models are available on supported Android devices.',
      );
  @override
  Future<void> remove() async {}
  @override
  Future<int?> chooseSuggestion(
    String question,
    String financialContext,
    List<String> suggestions,
  ) async => null;
}
