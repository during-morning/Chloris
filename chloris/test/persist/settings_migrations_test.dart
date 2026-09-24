import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chloris/core/persist/kv_settings.dart';
import 'package:chloris/core/persist/settings_migrations.dart';

void main() {
  test('设置迁移写入版本标记且保留旧值', () async {
    SharedPreferences.setMockInitialValues({'welcomeAccepted': true});

    // The gate now lives inside KvSettings.ready(), so there is no separate
    // entry point a caller could forget. Full coverage of the gate — including
    // idempotence and the credential-ordering guard — is in kv_migration_test.
    final settings = await KvSettings.ready();

    expect(settings.getBool('welcomeAccepted'), isTrue);
    expect(
      settings.getInt(SettingsMigrations.versionKey),
      SettingsMigrations.currentVersion,
    );
  });
}
