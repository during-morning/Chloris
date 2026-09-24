import 'package:chloris/services/persist/credentials.dart';
import 'package:chloris/services/persist/cookie_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('migration moves the WebDAV password out of plain-text prefs', () async {
    SharedPreferences.setMockInitialValues({'webdavPass': 'hunter2'});
    final prefs = await SharedPreferences.getInstance();

    await CredentialStore.migrateFromPrefs();

    // Gone from the readable store...
    expect(prefs.getString('webdavPass'), isNull);
    // ...and readable through the vault.
    expect(await CredentialStore.webdavPassword(), 'hunter2');
    final packed = prefs.getString(CookieVault.credentials.prefsKey);
    expect(packed, isNotNull);
    expect(packed!.contains('hunter2'), isFalse);
  });

  test('migration moves per-source login form values', () async {
    SharedPreferences.setMockInitialValues({
      'loginUi:https://a.test': '{"user":"alice","pass":"s3cret"}',
      'loginUi:https://b.test': '{"user":"bob"}',
      'webdavUrl': 'https://dav.test', // not a secret: must stay put
    });
    final prefs = await SharedPreferences.getInstance();

    await CredentialStore.migrateFromPrefs();

    expect(prefs.getString('loginUi:https://a.test'), isNull);
    expect(prefs.getString('loginUi:https://b.test'), isNull);
    expect(prefs.getString('webdavUrl'), 'https://dav.test');

    final fields = await CredentialStore.loginFields('https://a.test');
    expect(fields['user'], 'alice');
    expect(fields['pass'], 's3cret');
  });

  test('migration is idempotent', () async {
    SharedPreferences.setMockInitialValues({'webdavPass': 'once'});
    await CredentialStore.migrateFromPrefs();
    await CredentialStore.migrateFromPrefs();
    await CredentialStore.migrateFromPrefs();
    expect(await CredentialStore.webdavPassword(), 'once');
  });

  test('an existing vault value is never clobbered by stale prefs', () async {
    // Order matters: setMockInitialValues replaces the whole store, so the
    // vault value has to be written after the stale preference exists.
    SharedPreferences.setMockInitialValues({'webdavPass': 'stale'});
    await CredentialStore.setWebdavPassword('current');

    await CredentialStore.migrateFromPrefs();

    expect(await CredentialStore.webdavPassword(), 'current');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('webdavPass'), isNull);
  });

  test('migration tolerates an empty prefs store', () async {
    await CredentialStore.migrateFromPrefs();
    expect(await CredentialStore.webdavPassword(), '');
    expect(await CredentialStore.loginFields('https://none.test'), isEmpty);
  });

  test('login fields round-trip and clear', () async {
    await CredentialStore.setLoginFields('https://a.test', {'u': 'x'});
    expect(await CredentialStore.loginFields('https://a.test'), {'u': 'x'});
    await CredentialStore.setLoginFields('https://a.test', const {});
    expect(await CredentialStore.loginFields('https://a.test'), isEmpty);
  });

  test('setting an empty password removes it rather than storing ""', () async {
    await CredentialStore.setWebdavPassword('something');
    await CredentialStore.setWebdavPassword('');
    expect(await CredentialStore.webdavPassword(), '');
    expect(
      (await CookieVault.credentials.snapshot())
          .containsKey(CredentialStore.webdavPasswordKey),
      isFalse,
    );
  });
}
