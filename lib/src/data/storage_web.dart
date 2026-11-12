import 'package:sembast_web/sembast_web.dart';
import 'package:web/web.dart';

import 'storage.dart';

Future<LocalStore> openStore() async {
  final scope = window.document.baseURI;
  return _IndexedStore(
    await databaseFactoryWeb.openDatabase('moneymate-v1:$scope'),
  );
}

class _IndexedStore implements LocalStore {
  _IndexedStore(this.db);
  final Database db;
  final _store = StoreRef<String, String>('snapshots');

  @override
  Future<String?> read(String key) => _store.record(key).get(db);

  @override
  Future<void> write(String key, String value, {String? expected}) =>
      db.transaction((txn) async {
        final record = _store.record(key);
        if (await record.get(txn) != expected) throw const StoreConflict();
        await record.put(txn, value);
      });
}
