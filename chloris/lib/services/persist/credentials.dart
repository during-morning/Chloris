import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cookie_vault.dart';

/// Secret values that used to sit in SharedPreferences as plain text.
///
/// A WebDAV password and every per-source login form value were readable by
/// anything that could read the preferences file — a rooted device, the
/// desktop filesystem, or browser storage. They now live in an AES-GCM vault
/// that is separate from the settings vault and is never mirrored into a
/// cookie.
///
/// Honest limitation: the vault key is compiled into the binary, so this
/// protects against casual inspection and accidental exposure, not against an
/// attacker who can read process memory. Replacing the derived key with a
/// user-supplied passphrase is a separate, larger change.
abstract final class CredentialStore {
  static const webdavPasswordKey = 'webdavPass';

  /// Token this client presents to a Chloris server.
  ///
  /// A secret like any other, so it lives in the vault rather than next to the
  /// server address in plain preferences.
  static const serverTokenKey = 'serverToken';

  static Future<String> serverToken() async =>
      await CookieVault.credentials.get<String>(serverTokenKey) ?? '';

  static Future<void> setServerToken(String value) =>
      CookieVault.credentials.put(
        serverTokenKey,
        value.isEmpty ? null : value,
      );

  static String loginFieldsKey(String sourceUrl) => 'loginUi:$sourceUrl';

  /// Moves plaintext credentials from SharedPreferences into the vault.
  ///
  /// Idempotent: safe to call on every start. A value already in the vault
  /// wins, so a half-finished migration cannot destroy the good copy.
  static Future<void> migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final vault = CookieVault.credentials;
    final existing = await vault.snapshot();

    final updates = <String, Object?>{};

    final pass = prefs.getString(webdavPasswordKey);
    if (pass != null) {
      if (pass.isNotEmpty && !existing.containsKey(webdavPasswordKey)) {
        updates[webdavPasswordKey] = pass;
      }
      await prefs.remove(webdavPasswordKey);
    }

    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('loginUi:')) continue;
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty && !existing.containsKey(key)) {
        updates[key] = raw;
      }
      await prefs.remove(key);
    }

    if (updates.isEmpty) return;
    await vault.putAll(updates);
  }

  static Future<String> webdavPassword() async =>
      await CookieVault.credentials.get<String>(webdavPasswordKey) ?? '';

  static Future<void> setWebdavPassword(String value) =>
      CookieVault.credentials.put(
        webdavPasswordKey,
        value.isEmpty ? null : value,
      );

  static Future<Map<String, String>> loginFields(String sourceUrl) async {
    final raw = await CookieVault.credentials.get<String>(
      loginFieldsKey(sourceUrl),
    );
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return const {};
      return {
        for (final e in map.entries) e.key.toString(): e.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<void> setLoginFields(
    String sourceUrl,
    Map<String, String> fields,
  ) => CookieVault.credentials.put(
    loginFieldsKey(sourceUrl),
    jsonEncode(fields),
  );
}
