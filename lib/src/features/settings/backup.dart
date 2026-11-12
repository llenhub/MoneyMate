import 'dart:convert';
import 'package:file_selector/file_selector.dart';

import '../../core/models.dart';
import 'backup_native.dart'
    if (dart.library.js_interop) 'backup_web.dart'
    as platform;

const backupLimit = 20 * 1024 * 1024;

Future<Ledger?> selectBackup({required bool demo}) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'MoneyMate JSON backup',
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > backupLimit) {
    throw const FormatException('Backups are limited to 20 MB.');
  }
  try {
    return Ledger.decode(await file.readAsString(), expectedDemo: demo);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'The selected file is not a valid MoneyMate backup.',
    );
  }
}

Future<bool> exportBackup(Ledger ledger, {required bool demo}) async {
  final bytes = utf8.encode(ledger.encode(demo: demo));
  if (bytes.length > backupLimit) {
    throw const FormatException('This ledger exceeds the 20 MB backup limit.');
  }
  final day = DateTime.now().toIso8601String().substring(0, 10);
  return platform.saveBackup(
    'moneymate-${demo ? 'demo-' : ''}$day.json',
    bytes,
  );
}
