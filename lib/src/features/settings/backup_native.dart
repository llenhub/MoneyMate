import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

Future<bool> saveBackup(String name, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  if (Platform.isAndroid) {
    return await const MethodChannel(
          'dev.moneymate/platform',
        ).invokeMethod<bool>('saveBackup', {'name': name, 'data': data}) ??
        false;
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    data,
    name: name,
    mimeType: 'application/json',
  ).saveTo(location.path);
  return true;
}
