import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'dart:io';

import 'storage.dart';

Future<LocalStore> openStore() async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    final dir = await getApplicationSupportDirectory();
    return _DesktopStore(
      await databaseFactoryIo.openDatabase('${dir.path}/moneymate-v1.db'),
    );
  }
  final root = await sql.getDatabasesPath();
  final db = await sql.openDatabase(
    '$root/moneymate.db',
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE snapshots (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    ),
  );
  return _SqliteStore(db);
}

class _SqliteStore implements LocalStore {
  _SqliteStore(this.db);
  final sql.Database db;

  Future<String?> _read(sql.DatabaseExecutor executor, String key) async {
    final rows = await executor.query(
      'snapshots',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.firstOrNull?['value'] as String?;
  }

  @override
  Future<String?> read(String key) => _read(db, key);

  @override
  Future<void> write(String key, String value, {String? expected}) =>
      db.transaction((txn) async {
        if (await _read(txn, key) != expected) throw const StoreConflict();
        await txn.insert('snapshots', {
          'key': key,
          'value': value,
        }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
      });
}

class _DesktopStore implements LocalStore {
  _DesktopStore(this.db);
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
