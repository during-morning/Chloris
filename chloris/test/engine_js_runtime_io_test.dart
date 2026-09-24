import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/engine/js_runtime/js_runtime_io.dart';
import 'package:chloris_engine/chloris_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('IO JS runtime 保留合法空字符串并区分 undefined', () async {
    final runtime = FlutterJsRuntime();
    final scope = JsScope(variables: {'result': 'fallback'});

    expect(await runtime.eval("''", scope), '');
    expect(await runtime.eval('undefined', scope), 'fallback');
  });
}
