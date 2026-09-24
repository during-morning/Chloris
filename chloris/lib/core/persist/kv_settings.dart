import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_migrations.dart';

/// Small settings. Screens/providers go through this, not SharedPreferences.
///
/// [ready] is the only supported entry point, and it applies every pending key
/// migration before handing back the store. Keeping the gate here — rather than
/// in a separate call that features had to remember — is what makes it
/// enforceable: 30 call sites use this method, and none of them can skip the
/// migration by accident.
class KvSettings {
  KvSettings._(this._p);

  final SharedPreferences _p;

  static Future<KvSettings> ready() async {
    final prefs = await SharedPreferences.getInstance();
    await SettingsMigrations.ensure(prefs);
    return KvSettings._(prefs);
  }

  static final instance = _KvOneShot();

  static final StreamController<String> _changes =
      StreamController<String>.broadcast();

  /// Emits the written key after each mutation completes. Settings snapshots
  /// — like the host environment feeding `java.getThemeConfig()` — subscribe
  /// here instead of relying on every write site to remember a refresh.
  static Stream<String> get changes => _changes.stream;

  String? getString(String key) => _p.getString(key);
  Future<void> setString(String key, String value) async {
    await _p.setString(key, value);
    _changes.add(key);
  }

  bool? getBool(String key) => _p.getBool(key);
  Future<void> setBool(String key, bool value) async {
    await _p.setBool(key, value);
    _changes.add(key);
  }

  int? getInt(String key) => _p.getInt(key);
  Future<void> setInt(String key, int value) async {
    await _p.setInt(key, value);
    _changes.add(key);
  }

  double? getDouble(String key) => _p.getDouble(key);
  Future<void> setDouble(String key, double value) async {
    await _p.setDouble(key, value);
    _changes.add(key);
  }

  List<String>? getStringList(String key) => _p.getStringList(key);
  Future<void> setStringList(String key, List<String> value) async {
    await _p.setStringList(key, value);
    _changes.add(key);
  }

  Future<void> remove(String key) async {
    await _p.remove(key);
    _changes.add(key);
  }
}

class _KvOneShot {
  Future<String?> getString(String key) async =>
      (await KvSettings.ready()).getString(key);
  Future<void> setString(String key, String value) =>
      KvSettings.ready().then((k) => k.setString(key, value));
  Future<bool?> getBool(String key) async =>
      (await KvSettings.ready()).getBool(key);
  Future<void> setBool(String key, bool value) =>
      KvSettings.ready().then((k) => k.setBool(key, value));
  Future<int?> getInt(String key) async => (await KvSettings.ready()).getInt(key);
  Future<void> setInt(String key, int value) =>
      KvSettings.ready().then((k) => k.setInt(key, value));
}
