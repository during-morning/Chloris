import '../../core/persist/kv_settings.dart';

import 'cookie_vault.dart';

/// Mirror a compact settings/books snapshot into the encrypted cookie vault.
Future<void> syncVaultFromPrefs() async {
  final p = await KvSettings.ready();
  final patch = <String, Object?>{
    'themeMode': p.getString('themeMode'),
    'themeFamily': p.getString('themeFamily'),
    'einkTheme': p.getBool('einkTheme'),
    'uiStyle': p.getString('uiStyle'),
    'locale': p.getString('locale'),
    'readerSettings': p.getString('readerSettings'),
    'readingProgressV1': p.getString('readingProgressV1'),
    'onlineShelf': p.getString('onlineShelf'),
    'searchLastQuery': p.getString('searchLastQuery'),
    'homeBranch': p.getInt('homeBranch'),
  };
  await CookieVault.instance.putAll(patch);
}

Future<void> hydratePrefsFromVault() async {
  final snap = await CookieVault.instance.snapshot();
  if (snap.isEmpty) return;
  final p = await KvSettings.ready();
  Future<void> str(String k) async {
    final v = snap[k];
    if (v is String && v.isNotEmpty && (p.getString(k) == null)) {
      await p.setString(k, v);
    }
  }
  Future<void> flag(String k) async {
    final v = snap[k];
    if (v is bool && p.getBool(k) == null) await p.setBool(k, v);
  }
  Future<void> numKey(String k) async {
    final v = snap[k];
    if (v is int && p.getInt(k) == null) await p.setInt(k, v);
  }
  await str('themeMode');
  await str('themeFamily');
  await flag('einkTheme');
  await str('uiStyle');
  await str('locale');
  await str('readerSettings');
  await str('readingProgressV1');
  await str('onlineShelf');
  await str('searchLastQuery');
  await numKey('homeBranch');
}
