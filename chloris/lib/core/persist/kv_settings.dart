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

  String? getString(String key) => _p.getString(key);
  Future<void> setString(String key, String value) async =>
      _p.setString(key, value);

  bool? getBool(String key) => _p.getBool(key);
  Future<void> setBool(String key, bool value) async => _p.setBool(key, value);

  int? getInt(String key) => _p.getInt(key);
  Future<void> setInt(String key, int value) async => _p.setInt(key, value);

  double? getDouble(String key) => _p.getDouble(key);
  Future<void> setDouble(String key, double value) async =>
      _p.setDouble(key, value);

  List<String>? getStringList(String key) => _p.getStringList(key);
  Future<void> setStringList(String key, List<String> value) async =>
      _p.setStringList(key, value);

  Future<void> remove(String key) async => _p.remove(key);
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
