import 'package:chloris/services/persist/cookie_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vault round-trips compressed encrypted JSON', () async {
    SharedPreferences.setMockInitialValues({});
    await CookieVault.instance.putAll({
      'themeMode': 'dark',
      'onlineShelf': '[{"name":"demo"}]',
    });
    final snap = await CookieVault.instance.snapshot();
    expect(snap['themeMode'], 'dark');
    expect(snap['onlineShelf'], contains('demo'));
    final packed = (await SharedPreferences.getInstance())
        .getString(CookieVault.instance.prefsKey);
    expect(packed, isNotNull);
    expect(packed, startsWith('CA1.'));
    expect(packed!.contains('demo'), isFalse);
  });

  test('the credentials vault uses its own key and no cookie mirror', () async {
    SharedPreferences.setMockInitialValues({});
    await CookieVault.credentials.put('webdavPass', 'hunter2');

    // Separate storage: a settings snapshot must not expose credentials, and
    // vice versa.
    expect(CookieVault.credentials.prefsKey,
        isNot(CookieVault.instance.prefsKey));
    expect(CookieVault.credentials.mirrorToCookie, isFalse);
    expect(await CookieVault.instance.snapshot(), isEmpty);
    expect(await CookieVault.credentials.get<String>('webdavPass'), 'hunter2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(CookieVault.credentials.prefsKey), isNotNull);
    // Nothing about the password is readable without the key.
    expect(
      prefs.getString(CookieVault.credentials.prefsKey)!.contains('hunter2'),
      isFalse,
    );
  });
}
