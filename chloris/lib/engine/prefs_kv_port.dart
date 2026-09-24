import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';

import '../core/persist/kv_settings.dart';

/// [KvPort] backed by [KvSettings] (SharedPreferences).
///
/// 这是 `BookSource.varStore` 的持久实现：书源规则里 `java.put`/`java.get`
/// 写的源级变量落在 SharedPreferences，键为 `v_<bookSourceUrl>_<key>`，
/// 无 TTL、重启仍在 —— 对齐 Legado-E `CacheManager` 的 Room 兜底
/// （`BaseSource.kt:275-286`）。
class PrefsKvPort implements KvPort {
  const PrefsKvPort(this._prefs);

  final KvSettings _prefs;

  @override
  bool get isPersistent => true;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  void write(String key, String value) {
    // SharedPreferences 先更新内存缓存再异步落盘：同步读立即可见，
    // 持久化在后台完成 —— 与 Legado 的 CacheManager 双写行为一致。
    unawaited(_prefs.setString(key, value));
  }

  @override
  void delete(String key) {
    unawaited(_prefs.remove(key));
  }
}
