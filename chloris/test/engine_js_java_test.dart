import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';

void main() {
  test('LenientJsRuntime 处理 java.md5 与 java.getCookie', () async {
    final http = PackageHttpPort();
    final cookieStore = CookieStore()..set('https://a.com', 'k=v');
    final java = JavaHost(http: http, cookieStore: cookieStore);
    final rt = const LenientJsRuntime();
    final md5 = await rt.eval(
      'java.md5Encode("abc")',
      JsScope(variables: {'java': java}),
    );
    expect(md5, '900150983cd24fb0d6963f7d28e17f72');
    final ck = await rt.eval(
      'java.getCookie("https://a.com")',
      JsScope(variables: {'java': java}),
    );
    expect(ck, 'k=v');
  });
}
