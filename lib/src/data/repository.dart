import '../core/models.dart';
import 'storage.dart';

class FinanceRepository {
  FinanceRepository(this.store);
  final LocalStore store;
  final _snapshots = <String, String?>{};
  final _ledgers = <String, Ledger>{};

  Future<Ledger> load({required bool demo, Ledger Function()? seed}) async {
    final key = demo ? 'demo' : 'ledger';
    var snapshot = await store.read(key);
    if (snapshot == null && seed != null) {
      final initial = seed();
      initial.validate();
      snapshot = initial.encode(includeChat: true);
      try {
        await store.write(key, snapshot);
      } on StoreConflict {
        snapshot = await store.read(key);
      }
    }
    _snapshots[key] = snapshot;
    final ledger = snapshot == null ? Ledger() : Ledger.decode(snapshot);
    _ledgers[key] = ledger;
    return ledger;
  }

  Future<void> save(
    Ledger ledger, {
    required bool demo,
    required Ledger previous,
  }) async {
    final key = demo ? 'demo' : 'ledger';
    if (!identical(_ledgers[key], previous)) throw const StoreConflict();
    ledger.validate();
    final snapshot = ledger.encode(includeChat: true);
    await store.write(key, snapshot, expected: _snapshots[key]);
    _snapshots[key] = snapshot;
    _ledgers[key] = ledger;
  }
}
