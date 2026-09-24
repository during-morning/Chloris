import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// 验证 evalJs 的兜底路径遵守 strict 语义（对齐差异文档 §12 P1）。
///
/// 关键语义：
/// - 「没有 JS 引擎可用」（NoJsRuntime / LenientJsRuntime，用于 Web/测试）仍可宽松回退；
/// - 「有完整 JS 引擎但脚本执行失败」在 strict 下必须抛出可见的 DomainError，
///   而不是静默退化为宽松解释器「猜中」的看似合理的值。
///
/// 我们用一个「会失败但既不是 NoJsRuntime 也不是 LenientJsRuntime」的运行时模拟真实 VM
/// 执行失败，来触发 strict 可见错误分支。
class _FailingRealRuntime implements JsRuntime {
  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    // 模拟一个「有 JS 引擎但脚本执行失败」的真实 VM（如 QuickJS 抛错）。
    throw StateError('simulated real-engine failure for: $code');
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async =>
      throw StateError('simulated real-engine failure');
}

void main() {
  test('真实引擎失败时 strict 下必须抛可见 DomainError，而非静默猜中值', () async {
    final rule = AnalyzeRule(jsRuntime: _FailingRealRuntime())
      ..setContent('abcd');
    // 宽松解释器对 result.substring(1,3) 会「猜中」返回 'bc'；strict 下不得静默返回该值。
    await expectLater(
      rule.evalJs('result.substring(1,3)', 'abcd'),
      throwsA(
        isA<DomainError>()
            .having((e) => e.code, 'code', 'js_eval_failed')
            .having((e) => e.stage, 'stage', DomainErrorStage.render),
      ),
    );
  });

  test('result.replace 形态在 strict 失败下也不得静默返回替换结果', () async {
    final rule = AnalyzeRule(jsRuntime: _FailingRealRuntime())
      ..setContent('a/b/c');
    // 宽松解释器会执行 result.replace('a','b') → 'b/b/c'；必须改为可见错误。
    await expectLater(
      rule.evalJs("result.replace('a','b')", 'a/b/c'),
      throwsA(isA<DomainError>()),
    );
  });

  test('非 strict 下真实引擎失败仍允许宽松回退（保留有价值的回退）', () async {
    final rule = AnalyzeRule(jsRuntime: _FailingRealRuntime())
      ..setContent('abcd');
    final out = await rule.evalJs(
      'result.substring(1,3)',
      'abcd',
      strict: false,
    );
    expect(out, 'bc');
  });

  test('NoJsRuntime（无 VM）仍回退到宽松解释器的结果', () async {
    final rule = AnalyzeRule(jsRuntime: const NoJsRuntime())
      ..setContent('abcd');
    final out = await rule.evalJs('result.substring(1,3)', 'abcd');
    expect(out, 'bc');
  });

  test('LenientJsRuntime（无 VM）仍回退到宽松解释器的结果', () async {
    final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent('a/b/c');
    final out = await rule.evalJs("result.replace('a','b')", 'a/b/c');
    expect(out, 'b/b/c');
  });
}
