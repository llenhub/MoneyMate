import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import 'repository.dart';
import 'storage.dart';

final storeProvider = FutureProvider<LocalStore>((ref) => openStore());
final financeProvider = AsyncNotifierProvider<FinanceController, FinanceState>(
  FinanceController.new,
);

class Preferences {
  const Preferences({
    this.theme = 'system',
    this.currency = 'USD',
    this.dateFormat = 'MMM d, yyyy',
    this.demo = false,
  });

  final String theme, currency, dateFormat;
  final bool demo;

  Preferences copy({
    String? theme,
    String? currency,
    String? dateFormat,
    bool? demo,
  }) => Preferences(
    theme: theme ?? this.theme,
    currency: currency ?? this.currency,
    dateFormat: dateFormat ?? this.dateFormat,
    demo: demo ?? this.demo,
  );

  String encode() => jsonEncode({
    'theme': theme,
    'currency': currency,
    'dateFormat': dateFormat,
    'demo': demo,
  });

  static Preferences decode(String? source) {
    if (source == null) return const Preferences();
    final json = jsonDecode(source) as Json;
    return Preferences(
      theme: json['theme'],
      currency: json['currency'],
      dateFormat: json['dateFormat'],
      demo: json['demo'],
    );
  }
}

class FinanceState {
  FinanceState(this.ledger, this.preferences);
  final Ledger ledger;
  final Preferences preferences;
}

class FinanceController extends AsyncNotifier<FinanceState> {
  late FinanceRepository _repository;
  String? _storedPreferences;
  bool _saving = false;

  @override
  Future<FinanceState> build() async {
    final store = await ref.watch(storeProvider.future);
    _repository = FinanceRepository(store);
    _storedPreferences = await store.read('preferences');
    final preferences = Preferences.decode(_storedPreferences);
    return FinanceState(
      await _repository.load(demo: preferences.demo),
      preferences,
    );
  }

  Future<void> change(
    Ledger Function(Ledger) update, {
    bool? expectedDemo,
  }) async {
    if (_saving) {
      throw const FormatException('A change is already being saved.');
    }
    final current = state.requireValue;
    if (expectedDemo != null && current.preferences.demo != expectedDemo) {
      throw const StoreConflict();
    }
    final ledger = update(current.ledger);
    _saving = true;
    try {
      await _repository.save(
        ledger,
        demo: current.preferences.demo,
        previous: current.ledger,
      );
      state = AsyncData(FinanceState(ledger, current.preferences));
    } finally {
      _saving = false;
    }
  }

  Future<void> settings(
    Preferences preferences, {
    Ledger Function()? demoSeed,
  }) async {
    if (_saving) {
      throw const FormatException('A change is already being saved.');
    }
    final current = state.requireValue;
    _saving = true;
    try {
      var ledger = current.ledger;
      if (preferences.demo != current.preferences.demo) {
        ledger = await _repository.load(
          demo: preferences.demo,
          seed: preferences.demo ? demoSeed : null,
        );
      }
      final encoded = preferences.encode();
      await _repository.store.write(
        'preferences',
        encoded,
        expected: _storedPreferences,
      );
      _storedPreferences = encoded;
      state = AsyncData(FinanceState(ledger, preferences));
    } finally {
      _saving = false;
    }
  }
}
