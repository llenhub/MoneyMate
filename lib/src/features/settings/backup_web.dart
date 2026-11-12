import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<bool> saveBackup(String name, List<int> bytes) async {
  final blob = Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    BlobPropertyBag(type: 'application/json'),
  );
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = name;
  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => URL.revokeObjectURL(url),
  );
  return true;
}
