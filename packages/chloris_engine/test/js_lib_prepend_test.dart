import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

class _Rec implements JsRuntime {
  String? last;
  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    last = code;
    return 'ok';
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async =>
      (await eval(code, scope))?.toString() ?? '';
}

void main() {
  test('evalJs prepends jsLib', () async {
    final rec = _Rec();
    final rule = AnalyzeRule(
      jsRuntime: rec,
      source: BookSource(
        bookSourceUrl: 'https://x',
        jsLib: 'var lib=1;',
      ),
    );
    await rule.evalJs('result', 'hi');
    expect(rec.last, contains('var lib=1;'));
    expect(rec.last, contains('result'));
  });
}
