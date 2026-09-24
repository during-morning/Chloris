import 'dart:io';

import 'package:chloris/core/persist/kv_settings.dart';
import 'package:chloris/core/persist/settings_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the version gate is applied by KvSettings.ready', () {
    test('a fresh store gets the current version written', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SettingsMigrations.versionKey), isNull);

      await KvSettings.ready();

      expect(
        prefs.getInt(SettingsMigrations.versionKey),
        SettingsMigrations.currentVersion,
      );
    });

    test('an already-current store is left alone', () async {
      SharedPreferences.setMockInitialValues({
        SettingsMigrations.versionKey: SettingsMigrations.currentVersion,
        'librarySort': 'recent',
      });
      await KvSettings.ready();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('librarySort'), 'recent');
      expect(
        prefs.getInt(SettingsMigrations.versionKey),
        SettingsMigrations.currentVersion,
      );
    });

    test('an older version is upgraded exactly once', () async {
      SharedPreferences.setMockInitialValues({
        SettingsMigrations.versionKey: 1,
        'themeMode': 'dark',
      });
      await KvSettings.ready();
      await KvSettings.ready();
      await KvSettings.ready();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SettingsMigrations.versionKey), 3);
      // Unknown user data survives the upgrade.
      expect(prefs.getString('themeMode'), 'dark');
    });

    test('the gate does not destroy the plain-text credential', () async {
      // CredentialStore owns relocating this value. If the KV migration
      // deleted it first, a password would be lost rather than moved.
      SharedPreferences.setMockInitialValues({'webdavPass': 'hunter2'});
      await KvSettings.ready();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('webdavPass'), 'hunter2');
    });

    test('every acquisition goes through the gate, not just the first',
        () async {
      SharedPreferences.setMockInitialValues({});
      await KvSettings.ready();
      // Simulate a downgrade/rollback writing an older marker.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(SettingsMigrations.versionKey, 1);

      await KvSettings.ready();

      expect(prefs.getInt(SettingsMigrations.versionKey), 3);
    });

    test('the one-shot facade is gated too', () async {
      SharedPreferences.setMockInitialValues({});
      await KvSettings.instance.getString('anything');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(SettingsMigrations.versionKey),
        SettingsMigrations.currentVersion,
      );
    });
  });

  group('structural guard', () {
    /// The only files allowed to touch SharedPreferences directly: they are the
    /// storage layer itself. Everything else must go through KvSettings so the
    /// migration gate cannot be skipped.
    const allowed = {
      'lib/core/persist/kv_settings.dart',
      'lib/core/persist/blob_store.dart',
      'lib/services/persist/cookie_vault.dart',
      'lib/services/persist/credentials.dart',
    };

    test('no feature reaches SharedPreferences directly', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (allowed.contains(path)) continue;
        final source = entity.readAsStringSync();
        if (source.contains('SharedPreferences.getInstance()')) {
          offenders.add(path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'these files bypass the KvSettings migration gate: $offenders',
      );
    });

    test('the allowlist itself is not stale', () {
      // A listed file that no longer touches SharedPreferences would silently
      // widen the exemption for a future edit.
      for (final path in allowed) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        expect(
          file.readAsStringSync(),
          contains('SharedPreferences.getInstance()'),
          reason: '$path no longer needs its exemption',
        );
      }
    });
  });
}
