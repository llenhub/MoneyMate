import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_service.dart';
import 'ai_unsupported.dart' show UnsupportedAi;
import 'local_inference.dart';

AiService createAiService() {
  final abi = Abi.current();
  return Platform.isAndroid &&
          (abi == Abi.androidArm64 || abi == Abi.androidX64)
      ? AndroidAi()
      : const UnsupportedAi();
}

class AndroidAi implements AiService {
  static const _revision = '8e42d41f70cb6c571f58c3f31bd9287b372d97cc';
  static const _name = 'Qwen3-0.6B-Q4_K_M.gguf';
  static const _sha =
      'b0638f08417a2d3c8652760462eb5407c6e30173cf9608ad0820757a281eea0e';
  static const _maxBytes = 420000000;
  static const _channel = MethodChannel('dev.moneymate/platform');

  @override
  bool get supported => true;

  Future<File> _model() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_name');

  @override
  Future<bool> installed() async => (await _model()).exists();

  @override
  Future<void> download(void Function(double progress) onProgress) async {
    final available = await _channel.invokeMethod<int>('freeBytes');
    if (available == null || available < 500000000) {
      throw const FormatException(
        'Free at least 500 MB of internal storage to install the model.',
      );
    }
    final target = await _model();
    final partial = File('${target.path}.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/$_revision/$_name',
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode != 200 || response.contentLength > _maxBytes) {
        throw const FormatException('The model download could not be started.');
      }
      final sink = partial.openWrite();
      var bytes = 0;
      var lastPercent = -1;
      final expected = response.contentLength > 0
          ? response.contentLength
          : 397000000;
      try {
        await sink.addStream(
          response.timeout(const Duration(seconds: 45)).map((chunk) {
            bytes += chunk.length;
            if (bytes > _maxBytes) {
              throw const FormatException('The downloaded file is too large.');
            }
            final percent = (bytes * 100 ~/ expected).clamp(0, 99);
            if (percent != lastPercent) {
              lastPercent = percent;
              onProgress(percent / 100);
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      if ((await sha256.bind(partial.openRead()).first).toString() != _sha) {
        throw const FormatException(
          'Model verification failed. Try downloading again.',
        );
      }
      await partial.rename(target.path);
      onProgress(1);
    } finally {
      client.close(force: true);
      if (await partial.exists()) await partial.delete();
    }
  }

  @override
  Future<void> remove() async {
    final model = await _model();
    if (await model.exists()) await model.delete();
  }

  @override
  Future<int?> chooseSuggestion(
    String question,
    String financialContext,
    List<String> suggestions,
  ) async => selectWithLocalModel(
    (await _model()).path,
    question,
    financialContext,
    suggestions,
  );
}
