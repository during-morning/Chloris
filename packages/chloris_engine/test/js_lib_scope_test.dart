import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// Records every script the engine hands to the JS runtime, without running JS.
///
/// This is the engine-side observable of the "minimal shared scope": because
/// the engine re-prepends the book source's `jsLib` in front of every `eval`,
/// each recorded script must begin with that lib source.
class _Recorder implements JsRuntime {
  final List<String> scripts = [];

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    scripts.add(code);
    return null;
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async {
    scripts.add(code);
    return '';
  }
}

void main() {
  group('jsLib 共享作用域（最小共享）', () {
    // ① 书源含 jsLib：同一书源在单次会话内的【每次】eval 脚本都以 jsLib 开头。
    test('① 含 jsLib 的书源：每次 eval 脚本前缀都包含 jsLib 代码', () async {
      final rec = _Recorder();
      final rule = AnalyzeRule(
        jsRuntime: rec,
        source: BookSource(
          bookSourceUrl: 'https://a.test',
          jsLib: 'var lib=1; function helper(){return 2;}',
        ),
      );
      // 两次独立 eval（模拟同一书源的不同规则求值）。
      await rule.evalJs('result', 'r1');
      await rule.evalJs('result', 'r2');

      expect(rec.scripts, hasLength(2));
      for (final script in rec.scripts) {
        expect(
          script,
          startsWith('var lib=1; function helper(){return 2;}'),
          reason: '每次 eval 都应以前置的 jsLib 声明开头',
        );
        // 规则代码紧随 jsLib 之后，声明型内容因此对本次 eval 可见。
        expect(script, contains('\nresult'));
      }
    });

    // ② 书源无 jsLib：脚本与现状完全一致（无前缀、等于原始规则代码）。
    test('② 无 jsLib 的书源：脚本与现状一致（无前缀）', () async {
      final rec = _Recorder();
      final rule = AnalyzeRule(
        jsRuntime: rec,
        source: BookSource(bookSourceUrl: 'https://b.test'),
      );
      await rule.evalJs('result', 'hello');

      expect(rec.scripts, hasLength(1));
      expect(rec.scripts.single, 'result');
      expect(rec.scripts.single, isNot(contains('var lib')));
    });

    // ③ 多书源：各源的 jsLib 互不串入对方的 eval 脚本。
    test('③ 多书源：jsLib 不串源', () async {
      final recA = _Recorder();
      final recB = _Recorder();
      final a = AnalyzeRule(
        jsRuntime: recA,
        source: BookSource(bookSourceUrl: 'https://a.test', jsLib: 'var LIB_A=1;'),
      );
      final b = AnalyzeRule(
        jsRuntime: recB,
        source: BookSource(bookSourceUrl: 'https://b.test', jsLib: 'var LIB_B=2;'),
      );
      await a.evalJs('result', 'x');
      await b.evalJs('result', 'y');

      expect(recA.scripts.single, contains('LIB_A=1'));
      expect(recA.scripts.single, isNot(contains('LIB_B=2')));
      expect(recB.scripts.single, contains('LIB_B=2'));
      expect(recB.scripts.single, isNot(contains('LIB_A=1')));
    });

    test('③b 多书源：无 jsLib 的源脚本里不出现另一源的 jsLib', () async {
      final recA = _Recorder();
      final recB = _Recorder();
      final a = AnalyzeRule(
        jsRuntime: recA,
        source: BookSource(bookSourceUrl: 'https://a.test', jsLib: 'var LIB_A=1;'),
      );
      final b = AnalyzeRule(jsRuntime: recB, source: BookSource(bookSourceUrl: 'https://b.test'));
      await a.evalJs('result', 'x');
      await b.evalJs('result', 'y');

      expect(recB.scripts.single, isNot(contains('LIB_A=1')));
      expect(recB.scripts.single, 'result');
    });

    // 边界：空白（仅空白字符）的 jsLib 视为无，脚本与现状一致。
    test('边界：trim 后为空的 jsLib 视为无', () async {
      final rec = _Recorder();
      final rule = AnalyzeRule(
        jsRuntime: rec,
        source: BookSource(bookSourceUrl: 'https://c.test', jsLib: '   \n  '),
      );
      await rule.evalJs('result', 'z');
      expect(rec.scripts.single, 'result');
    });

    // 边界文档化：引擎不为 jsLib 注入任何跨求值的持久全局容器。
    // 每次 eval 只是一段独立的 `(jsLib 源码 + 规则代码)`，不包裹在捕获外部
    // 状态的闭包 / IIFE 里。可变全局状态（eval 内 `x = 1`）跨求值是否保留，是
    // 具体 runtime 的属性，不在引擎保证范围内（对齐 legado preventExtensions）。
    test('边界：引擎不为 jsLib 注入持久全局容器（每次 eval 仅为独立脚本）', () async {
      final rec = _Recorder();
      final rule = AnalyzeRule(
        jsRuntime: rec,
        source: BookSource(bookSourceUrl: 'https://d.test', jsLib: 'var LIB=1;'),
      );
      await rule.evalJs('result', '1');
      final script = rec.scripts.single;
      expect(script, startsWith('var LIB=1;'));
      expect(script, isNot(contains('(function')));
      expect(script, isNot(contains('!function')));
      expect(script, isNot(contains('(() =>')));
    });
  });

  group('JsHostBridge.prependJsLib（共享作用域注入助手）', () {
    test('空 jsLib 原样返回 code', () {
      expect(JsHostBridge.prependJsLib(null, 'result'), 'result');
      expect(JsHostBridge.prependJsLib('', 'result'), 'result');
      expect(JsHostBridge.prependJsLib('   \n ', 'result'), 'result');
    });

    test('非空 jsLib 前置并以换行分隔', () {
      expect(
        JsHostBridge.prependJsLib('var a=1;', 'result'),
        'var a=1;\nresult',
      );
      // 两端空白被 trim，不影响内容。
      expect(
        JsHostBridge.prependJsLib('  var a=1;  ', 'result.substring(0,1)'),
        'var a=1;\nresult.substring(0,1)',
      );
    });
  });
}
