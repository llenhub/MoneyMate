import 'storage_native.dart'
    if (dart.library.js_interop) 'storage_web.dart'
    as platform;

abstract interface class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value, {String? expected});
}

class StoreConflict implements Exception {
  const StoreConflict();
  @override
  String toString() =>
      'This data changed in another window. Reopen the app and try again.';
}

Future<LocalStore> openStore() => platform.openStore();
