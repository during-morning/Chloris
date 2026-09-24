import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('set/get/remove by domain', () {
    final s = CookieStore();
    s.set('https://a.com/x', 'k=v');
    expect(s.get('https://a.com/y'), 'k=v');
    expect(s.getKey('https://a.com/', 'k'), 'v');
    s.remove('https://a.com');
    expect(s.get('https://a.com'), '');
  });

  test('mergeSetCookie adds keys', () {
    final s = CookieStore();
    s.set('https://a.com', 'a=1');
    s.mergeSetCookie('https://a.com', 'b=2; Path=/');
    expect(s.get('https://a.com'), contains('a=1'));
    expect(s.get('https://a.com'), contains('b=2'));
  });

  test('mergeSetCookie keeps Expires comma and reads multiple cookies', () {
    final s = CookieStore();
    s.mergeSetCookie(
      'https://a.com',
      'sid=abc; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Path=/, token=xyz; Path=/',
    );
    expect(s.getKey('https://a.com', 'sid'), 'abc');
    expect(s.getKey('https://a.com', 'token'), 'xyz');
  });

  test('mergeSetCookie removes expired cookie', () {
    final s = CookieStore()..set('https://a.com', 'sid=abc; keep=1');
    s.mergeSetCookie('https://a.com', 'sid=gone; Max-Age=0; Path=/');
    expect(s.getKey('https://a.com', 'sid'), '');
    expect(s.getKey('https://a.com', 'keep'), '1');
  });
}
