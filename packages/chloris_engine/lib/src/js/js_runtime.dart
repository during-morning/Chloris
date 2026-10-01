import '../js/java_host.dart';
import '../models/domain_protocol.dart';

class JsScope {
  JsScope({this.variables = const {}});

  final Map<String, Object?> variables;

  JsScope copyWith(Map<String, Object?> extra) {
    return JsScope(variables: {...variables, ...extra});
  }
}

/// Injected by the app (QuickJS / browser). Engine never ships a JS VM.
abstract class JsRuntime {
  /// Evaluates [code] in [scope].
  ///
  /// [timeout] is an **optional, best-effort** deadline hint. A runtime that can
  /// interrupt its own VM (for example a QuickJS binding running with a step
  /// budget, or a browser worker carrying a kill switch) SHOULD honour it and
  /// return early. A runtime that cannot -- the engine never holds the VM, it
  /// is injected by the app and a synchronous `eval` cannot be force-cancelled
  /// from the Dart side -- is free to ignore it.
  ///
  /// Callers that need a hard guarantee that they are not left hanging must wrap
  /// the call in [JsHostBridge.evalWithDeadline], which uses [Future.timeout] at
  /// the boundary. See its documentation for the honest "the VM may still be
  /// running in the background" caveat.
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout});

  Future<String> evalToString(String code, JsScope scope) async {
    final result = await eval(code, scope);
    return result?.toString() ?? '';
  }
}

class NoJsRuntime implements JsRuntime {
  const NoJsRuntime();

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) {
    throw UnsupportedError(
      'JS is required for this rule but no runtime is attached:\\n$code',
    );
  }

  @override
  Future<String> evalToString(String code, JsScope scope) =>
      eval(code, scope).then((v) => v?.toString() ?? '');
}

/// A rule the best-effort interpreter could not evaluate faithfully.
///
/// Both silent failure modes of [LenientJsRuntime] -- returning the input
/// unchanged, and returning an empty string for an unknown `java.*` call --
/// are indistinguishable from a successful evaluation at the call site. The
/// caller sees a plausible string, caches it as chapter content, and no error
/// is ever raised. Routing them through one sink is what makes the
/// degradation observable before it becomes a hard error.
class JsDegradation {
  const JsDegradation({
    required this.code,
    required this.message,
    required this.rule,
  });

  /// Stable identifier for the failure family, e.g. `js_unsupported`.
  final String code;
  final String message;

  /// The rule JavaScript that could not be interpreted.
  final String rule;

  @override
  String toString() => 'JsDegradation($code): $message <- $rule';
}

typedef JsDegradationSink = void Function(JsDegradation event);

/// Best-effort JS for sources that interpolate key/page/result, literal URLs,
/// and common java.* helper calls. Never throws; unsupported JS falls back to [result].
class LenientJsRuntime implements JsRuntime {
  const LenientJsRuntime();

  /// Reports every rule this runtime could not evaluate faithfully.
  ///
  /// Attach a sink to surface degraded evaluations in logs, diagnostics or
  /// tests. Left null the runtime stays silent.
  static JsDegradationSink? onDegrade;

  /// When true (the default), a rule the interpreter cannot evaluate throws a
  /// [DomainError] instead of returning its input unchanged.
  ///
  /// Returning the input made an unevaluated rule indistinguishable from a
  /// successful one: the caller cached the wrong text as chapter content and
  /// nothing was ever raised. Set this to false only where best-effort
  /// behaviour is genuinely wanted, such as a diagnostic probe or a one-off
  /// migration of legacy data.
  static bool strict = true;

  static void _report(String code, String message, String rule) {
    onDegrade?.call(JsDegradation(code: code, message: message, rule: rule));
  }

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    // The lenient interpreter is a pattern-matching best-effort evaluator that
    // returns synchronously: there is no event loop to interrupt and no step
    // budget to enforce. [timeout] is therefore accepted for signature
    // compatibility with [JsRuntime] but never used -- this call always
    // completes immediately, so no interruption is needed.
    final java = scope.variables['java'];
    if (java is JavaHost) {
      final call = RegExp(
        r'^java\.(\w+)\((.*)\)\s*;?\s*$',
        dotAll: true,
      ).firstMatch(code.trim());
      if (call != null) {
        final result = await java.invoke(
          call.group(1)!,
          _argList(call.group(2)!),
        );
        if (result == null) {
          _report(
            'js_java_unsupported',
            'java.${call.group(1)} 未被宿主实现或返回空',
            code.trim(),
          );
        }
        return result;
      }
    }
    return interpretJs(code, scope);
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async {
    final v = await eval(code, scope);
    return v?.toString() ?? '';
  }

  static Object? interpretJs(String code, JsScope scope) {
    final vars = scope.variables;
    final result = vars['result'];
    final key = '${vars['key'] ?? ''}';
    final page = vars['page'] ?? 1;
    final baseUrl = '${vars['baseUrl'] ?? ''}';
    var c = code.trim();
    if (c.isEmpty) return result;
    if (c == 'result' || c == 'result;') return result;
    if (c == 'key' || c == 'key;') return key;
    if (c == 'page' || c == 'page;') return page;
    if (c == 'baseUrl' || c == 'baseUrl;') return baseUrl;
    if (c == 'encodeURIComponent(key)' || c == 'encodeURIComponent(key);') {
      return Uri.encodeQueryComponent(key);
    }
    if (c == 'encodeURI(key)' || c == 'encodeURI(key);') {
      return Uri.encodeFull(key);
    }

    final java = vars['java'];
    if (java != null) {
      final jm = RegExp(r'''java\.(\w+)\(\s*([^)]*)\s*\)''').firstMatch(c);
      if (jm != null) {
        final v = _callJava(java, jm.group(1)!, jm.group(2) ?? '');
        if (v != null) return v;
      }
    }

    var expanded = c
        .replaceAll('{{key}}', Uri.encodeQueryComponent(key))
        .replaceAll('{{page}}', '$page')
        .replaceAll('{{baseUrl}}', baseUrl)
        .replaceAll('{{result}}', result?.toString() ?? '');
    expanded = expanded.replaceAll(
      'encodeURIComponent(key)',
      "'" + Uri.encodeQueryComponent(key) + "'",
    );
    expanded = expanded.replaceAll(
      'encodeURI(key)',
      "'" + Uri.encodeFull(key) + "'",
    );
    final rs = result?.toString() ?? '';
    final repl = RegExp(
      "result.replace\\(\\s*['\"]([^'\"]*)['\"]\\s*,\\s*['\"]([^'\"]*)['\"]\\s*\\)",
    ).firstMatch(c);
    if (repl != null) {
      return rs.replaceAll(repl.group(1)!, repl.group(2)!);
    }
    final sub = RegExp(
      r'result\.substring\(\s*(\d+)\s*(?:,\s*(\d+)\s*)?\)',
    ).firstMatch(c);
    if (sub != null && rs.isNotEmpty) {
      final a = int.parse(sub.group(1)!);
      final b = sub.group(2) != null ? int.parse(sub.group(2)!) : rs.length;
      if (a >= 0 && b >= a && b <= rs.length) return rs.substring(a, b);
    }
    if (key.isNotEmpty) {
      expanded = expanded.replaceAllMapped(
        RegExp("'([^']*)'\\s*\\+\\s*key\\s*\\+\\s*'([^']*)'"),
        (m) =>
            "'" +
            m.group(1)! +
            Uri.encodeQueryComponent(key) +
            m.group(2)! +
            "'",
      );
      expanded = expanded.replaceAll(
        RegExp(r'''(['"'])\s*\+\s*key\s*\+\s*(['"'])'''),
        Uri.encodeQueryComponent(key),
      );
    }

    final url = RegExp(
      r'''https?://[^\s'"`,;]+''',
      caseSensitive: false,
    ).firstMatch(expanded);
    if (url != null) {
      return url
          .group(0)!
          .replaceAll('{{key}}', Uri.encodeQueryComponent(key))
          .replaceAll('{{page}}', '$page');
    }

    final quoted = RegExp(
      r'''['"]([^'"]+)['"]\s*;?\s*$''',
    ).firstMatch(expanded);
    if (quoted != null) {
      final q = quoted.group(1)!;
      if (q.startsWith('http') || q.startsWith('/') || q.contains('{{')) {
        return q
            .replaceAll('{{key}}', Uri.encodeQueryComponent(key))
            .replaceAll('{{page}}', '$page');
      }
    }
    // Nothing matched: previously the input was handed back as if the rule had
    // succeeded. Report it, then refuse to pretend unless explicitly asked to.
    _report('js_unsupported', '规则 JS 未被宽松解释器支持，已原样返回输入', c);
    if (strict) {
      throw DomainError(
        code: 'js_unsupported',
        stage: DomainErrorStage.render,
        message: '规则 JS 无法求值，且不允许回退为原输入',
        cause: c,
        recoverable: false,
        retryable: false,
        suggestedAction: '该规则需要完整 JS 运行时；请检查书源规则或改用受支持的写法',
      );
    }
    return result;
  }

  static Object? _callJava(Object java, String name, String args) {
    if (java is! JavaHost) return null;
    return java.invokeSync(name, _argList(args));
  }

  static List<Object?> _argList(String args) {
    if (args.trim().isEmpty) return const [];
    final out = <Object?>[];
    for (final part in _splitTop(args)) {
      final t = part.trim();
      if (t.isEmpty) continue;
      final unq = t.startsWith("'") || t.startsWith('"')
          ? (t.length >= 2 ? t.substring(1, t.length - 1) : t)
          : t;
      if (RegExp(r'^-?\d+$').hasMatch(unq)) {
        out.add(int.tryParse(unq));
      } else {
        out.add(unq);
      }
    }
    return out;
  }

  static List<String> _splitTop(String s) {
    final out = <String>[];
    var start = 0;
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        out.add(s.substring(start, i));
        start = i + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }
}

abstract interface class JsSessionLifecycle {
  void cancelSession(String id);
}
