import 'package:chloris/core/persist/kv_settings.dart';
import 'package:chloris/engine/host_environment_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are used when no settings are stored', () async {
    SharedPreferences.setMockInitialValues({});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.userAgent(), contains('Mozilla'));
    expect(env.themeMode(), 0);
    expect(env.readBookConfig(), isEmpty);
  });

  test('the user agent comes from settings', () async {
    SharedPreferences.setMockInitialValues({'userAgent': 'UA/from-settings'});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.userAgent(), 'UA/from-settings');
  });

  test('an empty stored user agent falls back rather than blanking the header',
      () async {
    SharedPreferences.setMockInitialValues({'userAgent': ''});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.userAgent(), isNotEmpty);
  });

  test('theme mode maps the stored string', () async {
    for (final (stored, expected) in const [
      ('light', 1),
      ('dark', 2),
      ('system', 0),
      ('nonsense', 0),
    ]) {
      SharedPreferences.setMockInitialValues({'themeMode': stored});
      final env = AppHostEnvironment();
      await env.refresh();
      expect(env.themeMode(), expected, reason: stored);
    }
  });

  test('reading config is decoded from JSON', () async {
    SharedPreferences.setMockInitialValues({
      'readerSettings': '{"textSize":22,"lineHeight":1.8}',
    });
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.readBookConfig()['textSize'], 22);
    expect(env.readBookConfig()['lineHeight'], 1.8);
  });

  test('malformed reading config degrades to empty, not a crash', () async {
    SharedPreferences.setMockInitialValues({'readerSettings': '{not json'});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.readBookConfig(), isEmpty);
  });

  test('a settings write after construction refreshes the snapshot', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'light'});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.themeMode(), 1);
    await (await KvSettings.ready()).setString('themeMode', 'dark');
    // The KvSettings change stream delivers the write asynchronously.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(env.themeMode(), 2);
    env.dispose();
  });

  test('writes that bypass KvSettings leave the snapshot stale', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'light'});
    final env = AppHostEnvironment();
    await env.refresh();
    expect(env.themeMode(), 1);
    await (await SharedPreferences.getInstance()).setString('themeMode', 'dark');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(env.themeMode(), 1);
    await (await KvSettings.ready()).setString('themeMode', 'system');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(env.themeMode(), 0);
    env.dispose();
  });

  test('theme config reports family, style and e-ink', () async {
    SharedPreferences.setMockInitialValues({
      'themeFamily': 'sepia',
      'uiStyle': 'compact',
      'einkTheme': true,
      'themeMode': 'dark',
    });
    final env = AppHostEnvironment();
    await env.refresh();
    final cfg = env.themeConfig();
    expect(cfg['family'], 'sepia');
    expect(cfg['style'], 'compact');
    expect(cfg['eink'], isTrue);
    expect(cfg['mode'], 2);
  });

  test('openUrl refuses a relative url instead of failing silently later',
      () async {
    SharedPreferences.setMockInitialValues({});
    final env = AppHostEnvironment();
    expect(await env.openUrl('not a url'), isFalse);
    expect(await env.openUrl(''), isFalse);
  });

  test('capabilities with no host UI still fail loudly', () async {
    SharedPreferences.setMockInitialValues({});
    final env = AppHostEnvironment();
    await expectLater(
      env.startBrowser('https://x.test'),
      throwsA(isA<Object>()),
    );
  });
}
