import 'package:chloris/application/online/http_online_book_port.dart';
import 'package:chloris/app/providers.dart';
import 'package:chloris/services/persist/credentials.dart';
import 'package:chloris/services/web/server_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ServerConnection', () {
    test('is unconfigured until an address is saved', () async {
      expect((await ServerConnection.load()).isConfigured, isFalse);

      await ServerConnection.save(
        baseUrl: 'http://127.0.0.1:1234',
        token: 'abc',
      );

      final loaded = await ServerConnection.load();
      expect(loaded.isConfigured, isTrue);
      expect(loaded.baseUrl, 'http://127.0.0.1:1234');
      expect(loaded.token, 'abc');
    });

    test('a trailing slash is stripped so paths do not double up', () {
      const c = ServerConnection(
        baseUrl: 'http://127.0.0.1:1234///',
        token: '',
      );
      expect(c.normalizedBaseUrl, 'http://127.0.0.1:1234');
    });

    test('saving an empty address clears the configuration', () async {
      await ServerConnection.save(baseUrl: 'http://x:1', token: 't');
      await ServerConnection.save(baseUrl: '   ', token: '');
      expect((await ServerConnection.load()).isConfigured, isFalse);
    });

    test('the token goes to the vault, not to plain preferences', () async {
      await ServerConnection.save(
        baseUrl: 'http://127.0.0.1:1234',
        token: 'super-secret',
      );
      final prefs = await SharedPreferences.getInstance();
      // The address is not a secret and may live in preferences...
      expect(prefs.getString(ServerConnection.baseUrlKey), isNotNull);
      // ...but the token must not be readable there.
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        expect('$value', isNot(contains('super-secret')), reason: key);
      }
      expect(await CredentialStore.serverToken(), 'super-secret');
    });
  });

  group('port selection', () {
    test('falls back to the engine when no server is configured', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Resolve the connection first so the provider sees the loaded value.
      await container.read(serverConnectionProvider.future);

      final port = container.read(onlineBookPortProvider);
      expect(
        port,
        isNot(isA<HttpOnlineBookPort>()),
        reason: 'without a server the engine must keep working',
      );
    });

    test('uses the HTTP port once a server is configured', () async {
      await ServerConnection.save(baseUrl: 'http://127.0.0.1:1234', token: 't');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(serverConnectionProvider.future);

      expect(container.read(onlineBookPortProvider), isA<HttpOnlineBookPort>());
    });
  });
}
