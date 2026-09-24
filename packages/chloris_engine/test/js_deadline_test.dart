// JS 超时保护测试 —— JsHostBridge.evalWithDeadline：
// - 调用方在 deadline 到点后被释放并抛 DomainError('js_deadline')；
// - 降级告警进入 JsDegradation 流（诚实说明「VM 可能仍在后台执行」）；
// - 正常完成的求值不受影响。
import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

class _NeverRuntime implements JsRuntime {
  @override
  Future<String> evalToString(String code, JsScope scope) => eval(code, scope).then((v) => v?.toString() ?? '');

  @override
  Future<Object?> eval(
    String code,
    JsScope scope, {
    Duration? timeout,
  }) {
    return Completer<Object?>().future; // 永不完成，模拟死循环脚本
  }
}

class _OkRuntime implements JsRuntime {
  @override
  Future<String> evalToString(String code, JsScope scope) async => 'ok';

  @override
  Future<Object?> eval(
    String code,
    JsScope scope, {
    Duration? timeout,
  }) async =>
      'ok';
}

void main() {
  test('deadline 到点抛 js_deadline 并打降级告警', () async {
    final degradations = <JsDegradation>[];
    Object? caught;
    try {
      await JsHostBridge.evalWithDeadline(
        _NeverRuntime(),
        'while(true){}',
        JsScope(),
        timeout: const Duration(milliseconds: 50),
        rule: 'while(true){}',
        onDegrade: degradations.add,
      );
    } on DomainError catch (e) {
      caught = e;
    }
    expect(caught, isA<DomainError>());
    expect((caught! as DomainError).code, 'js_deadline');
    expect(degradations, isNotEmpty);
    expect(degradations.first.code, 'js_deadline');
    expect(degradations.first.message, contains('后台'));
  });

  test('正常完成的求值原样返回', () async {
    final out = await JsHostBridge.evalWithDeadline(
      _OkRuntime(),
      'result',
      JsScope(),
      timeout: const Duration(seconds: 2),
      rule: 'result',
    );
    expect(out, 'ok');
  });

  test('EngineLimits.jsEvalTimeout 有默认值且可配置', () {
    expect(EngineLimits.jsEvalTimeout, greaterThan(Duration.zero));
    EngineLimits.apply(jsEvalTimeoutSec: 3);
    expect(EngineLimits.jsEvalTimeout, const Duration(seconds: 3));
    EngineLimits.apply(jsEvalTimeoutSec: 15);
  });
}
