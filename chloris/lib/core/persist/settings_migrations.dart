import 'package:shared_preferences/shared_preferences.dart';

/// Versioned key/value migration boundary.
///
/// Applied by `KvSettings.ready()` on every acquisition, so a feature cannot
/// bypass it by taking the settings handle directly. Before this the gate lived
/// in `SettingsMigrations.ready()`, which only 3 of 30 call sites used — the
/// other 27 read settings without any migration having run.
///
/// This file deliberately does not import `KvSettings`, which keeps the
/// dependency one-way.
abstract final class SettingsMigrations {
  /// Bump when a stored key changes shape or meaning.
  ///
  /// - 2: boundary recorded; V1 keys were audited and left untouched.
  /// - 3: credentials moved to the encrypted vault (owned by `CredentialStore`)
  ///      and the replace-rule table gained four columns.
  static const currentVersion = 3;

  static const versionKey = 'chlorisSettingsSchemaVersion';

  /// Runs every pending migration. Idempotent and safe on every read.
  ///
  /// Note: this intentionally does **not** delete the legacy `webdavPass`
  /// preference. Relocating that value is `CredentialStore.migrateFromPrefs`'s
  /// job, and deleting here would race it — a migration that runs before the
  /// credential store would destroy the password instead of moving it.
  static Future<void> ensure(SharedPreferences prefs) async {
    final version = prefs.getInt(versionKey) ?? 1;
    if (version >= currentVersion) return;

    if (version < 2) {
      // V1 already stored the current values under stable names. The first
      // migration records that those keys were audited and keeps all unknown
      // user data untouched for forward compatibility.
    }
    if (version < 3) {
      // Structural only; see the class doc. No key is rewritten here.
    }

    await prefs.setInt(versionKey, currentVersion);
  }
}
