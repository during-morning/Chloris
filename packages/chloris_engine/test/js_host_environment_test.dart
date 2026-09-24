import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// A host with a UI and settings, as a native build would provide.
class _FakeEnvironment implements HostEnvironment {
  final openedUrls = <String>[];
  final openedVideos = <String>[];
  String? browserBody;

  @override
  String userAgent() => 'FakeUA/1.0';

  @override
  Future<bool> openUrl(String url, {String? mimeType}) async {
    openedUrls.add(url);
    return true;
  }

  @override
  Future<bool> openVideo(String url, String title, {bool float = false}) async {
    openedVideos.add('$title@$url');
    return true;
  }

  @override
  Future<String> startBrowser(
    String url, {
    String title = '',
    bool refetchAfterSuccess = false,
  }) async => browserBody ?? '<html>$url</html>';

  @override
  Future<String> verificationCode(String imageUrl) async => '1234';

  @override
  Map<String, Object?> readBookConfig() => const {'textSize': 20};

  @override
  Map<String, Object?> themeConfig() => const {'primary': '#336699'};

  @override
  int themeMode() => 2;
}

class _NoHttp implements HttpPort {
  _NoHttp({this.bodies = const {}});

  final Map<String, String> bodies;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async => StrResponse(
    url: spec.url,
    body: bodies[spec.url] ?? '',
  );

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List.fromList(utf8.encode(bodies[url] ?? ''));

  @override
  void cancelInFlight() {}
}

JavaHost _host({HostEnvironment? env, HttpPort? http}) => JavaHost(
  http: http ?? _NoHttp(),
  cookieStore: CookieStore(),
  hostEnvironment: env ?? const DefaultHostEnvironment(),
);

void main() {
  group('DefaultHostEnvironment', () {
    const env = DefaultHostEnvironment();

    test('still answers the questions that have an answer', () {
      expect(env.userAgent(), contains('Mozilla'));
      expect(env.readBookConfig(), isEmpty);
      expect(env.themeConfig(), isEmpty);
      expect(env.themeMode(), 0);
    });

    test('fire-and-forget actions report false rather than pretending', () async {
      expect(await env.openUrl('https://x.test'), isFalse);
      expect(await env.openVideo('https://x.test/v.mp4', 't'), isFalse);
    });

    test('data-returning actions throw, so no rule caches a blank answer',
        () async {
      await expectLater(
        env.startBrowser('https://x.test'),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        env.verificationCode('https://x.test/c.png'),
        throwsA(isA<DomainError>()),
      );
    });
  });

  group('java.* environment surface', () {
    test('user agent and settings come from the host', () {
      final host = _host(env: _FakeEnvironment());
      expect(host.getWebViewUA(), 'FakeUA/1.0');
      expect(host.getThemeMode(), 2);
      expect(jsonDecode(host.getReadBookConfig()), {'textSize': 20});
      expect(jsonDecode(host.getThemeConfig()), {'primary': '#336699'});
      expect(host.getReadBookConfigMap()['textSize'], 20);
      expect(host.getThemeConfigMap()['primary'], '#336699');
    });

    test('openUrl and openVideoPlayer reach the host', () async {
      final env = _FakeEnvironment();
      final host = _host(env: env);
      expect(await host.openUrl('https://a.test'), isTrue);
      expect(await host.openVideoPlayer('https://a.test/v.mp4', '标题'), isTrue);
      expect(env.openedUrls, ['https://a.test']);
      expect(env.openedVideos, ['标题@https://a.test/v.mp4']);
    });

    test('startBrowserAwait returns the body', () async {
      final env = _FakeEnvironment()..browserBody = '<p>ok</p>';
      expect(await _host(env: env).startBrowserAwait('https://a.test', 't'),
          '<p>ok</p>');
    });

    test('getVerificationCode returns the user answer', () async {
      expect(
        await _host(env: _FakeEnvironment())
            .getVerificationCode('https://a.test/c.png'),
        '1234',
      );
    });

    test('startBrowserAwait without a host UI fails loudly', () async {
      await expectLater(
        _host().startBrowserAwait('https://a.test', 't'),
        throwsA(isA<DomainError>()),
      );
    });
  });

  group('toURL', () {
    final host = _host();

    test('leaves an absolute url alone', () {
      expect(host.toURL('https://a.test/x'), 'https://a.test/x');
    });

    test('resolves a relative url against the source', () {
      expect(
        host.toURL('/chapter/1', 'https://a.test/book/9'),
        'https://a.test/chapter/1',
      );
      expect(
        host.toURL('c1.html', 'https://a.test/book/9'),
        'https://a.test/book/c1.html',
      );
    });

    test('returns the input when there is nothing to resolve against', () {
      expect(host.toURL('/x'), '/x');
    });
  });

  group('ajaxTestAll', () {
    test('collects every response, keeping failures as entries', () async {
      final host = _host(
        http: _NoHttp(bodies: const {'https://a.test': 'A'}),
      );
      final list = await host.ajaxTestAll(['https://a.test'], 5000);
      expect(list, hasLength(1));
      expect(list.single.body, 'A');
    });
  });

  group('bridge wiring', () {
    test('async environment calls ride the two-pass cycle', () {
      for (final name in const [
        'ajaxTestAll',
        'startBrowserAwait',
        'getVerificationCode',
      ]) {
        expect(JsHostSession.isNetwork(name), isTrue, reason: name);
      }
    });

    test('the prelude exposes the whole environment surface', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final name in const [
        'getWebViewUA',
        'toURL',
        'getSource',
        'getTag',
        'getThemeMode',
        'getReadBookConfig',
        'getReadBookConfigMap',
        'getThemeConfig',
        'getThemeConfigMap',
        'longToast',
        'logType',
        'openUrl',
        'openVideoPlayer',
        'startBrowser',
        'startBrowserAwait',
        'getVerificationCode',
        'ajaxTestAll',
      ]) {
        expect(prelude, contains('$name:'), reason: name);
      }
    });

    test('the Map getters parse JSON instead of returning a Dart toString', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      // A raw `invokeSync` result reaches JS as a string, so the prelude has to
      // parse it for the *Map variants to behave like objects.
      expect(prelude, contains("JSON.parse(__chlorisJava('getReadBookConfigMap'"));
      expect(prelude, contains("JSON.parse(__chlorisJava('getThemeConfigMap'"));
    });
  });
}
