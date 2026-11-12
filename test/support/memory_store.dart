import 'package:moneymate/src/data/storage.dart';

class MemoryStore implements LocalStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value, {String? expected}) async {
    if (values[key] != expected) throw const StoreConflict();
    values[key] = value;
  }
}
