import 'package:chloris/services/web/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('proxy SSRF guard', () {
    test('blocks loopback and private targets by default', () {
      for (final host in const [
        'localhost',
        'foo.localhost',
        '127.0.0.1',
        '127.1.2.3',
        '0.0.0.0',
        '10.0.0.5',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.1',
        '169.254.169.254', // cloud metadata endpoint
        '::1',
        'fc00::1',
        'fe80::1',
        '224.0.0.1',
      ]) {
        expect(
          isBlockedProxyHost(host),
          isTrue,
          reason: '$host should be refused',
        );
      }
    });

    test('allows public targets', () {
      for (final host in const [
        'example.com',
        'www.baidu.com',
        '8.8.8.8',
        '1.1.1.1',
        '172.32.0.1', // just outside the private range
        '2606:4700::1111',
      ]) {
        expect(
          isBlockedProxyHost(host),
          isFalse,
          reason: '$host should be allowed',
        );
      }
    });

    test('allowPrivate opts out for users who proxy their own LAN', () {
      expect(isBlockedProxyHost('192.168.1.1', allowPrivate: true), isFalse);
      expect(isBlockedProxyHost('localhost', allowPrivate: true), isFalse);
    });

    test('rejects non-http schemes and malformed urls', () {
      expect(proxyTargetError('file:///etc/passwd'), isNotNull);
      expect(proxyTargetError('ftp://example.com/x'), isNotNull);
      expect(proxyTargetError('not a url'), isNotNull);
      expect(proxyTargetError(''), isNotNull);
    });

    test('accepts a public http target', () {
      expect(proxyTargetError('https://example.com/book/1'), isNull);
      expect(proxyTargetError('http://example.com/book/1'), isNull);
    });

    test('reports the blocked host in the error', () {
      final err = proxyTargetError('http://169.254.169.254/latest/meta-data');
      expect(err, isNotNull);
      expect(err, contains('169.254.169.254'));
    });
  });

  group('CORS origin policy', () {
    test('accepts loopback origins only', () {
      expect(isLoopbackOrigin('http://localhost:2328'), isTrue);
      expect(isLoopbackOrigin('http://127.0.0.1:2328'), isTrue);
      expect(isLoopbackOrigin('http://[::1]:2328'), isTrue);
      // A wildcard here would let any visited site drive the API.
      expect(isLoopbackOrigin('https://evil.example'), isFalse);
      expect(isLoopbackOrigin('http://192.168.1.10:2328'), isFalse);
      expect(isLoopbackOrigin(''), isFalse);
    });
  });

  group('token comparison', () {
    test('is value-correct', () {
      expect(constantTimeEquals('abc', 'abc'), isTrue);
      expect(constantTimeEquals('abc', 'abd'), isFalse);
      expect(constantTimeEquals('abc', 'abcd'), isFalse);
      expect(constantTimeEquals('', ''), isTrue);
    });
  });

  group('token generation', () {
    test('produces distinct, url-safe, high-entropy tokens', () {
      final a = generateServerToken();
      final b = generateServerToken();
      expect(a, isNot(b));
      expect(a.length, greaterThanOrEqualTo(30));
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });
  });
}
