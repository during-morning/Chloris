import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('SourceRule parses nested @put maps without truncating braces', () {
    final rule = SourceRule(
      r'''@put:{"selector":"id.content@text","meta":{"close":"}"},"quoted":"a\"b"} @get:{selector}''',
    );
    expect(rule.putMap['selector'], 'id.content@text');
    expect(rule.putMap['meta'], contains('"close"'));
    expect(rule.putMap['quoted'], 'a"b');
    expect(rule.rule.trim(), '@get:{selector}');
    final shorthand = SourceRule('@put:{seed:"继承作者"}tag.li');
    expect(shorthand.putMap, {'seed': '继承作者'});
    expect(shorthand.rule, 'tag.li');
  });

  test(
    'AnalyzeRule exposes original src and independent nextChapterUrl',
    () async {
      final runtime = _CaptureRuntime();
      final rule = AnalyzeRule(jsRuntime: runtime)
        ..setContent('<p>body</p>', 'https://example.test/ch/1')
        ..setNextChapterUrl('https://example.test/ch/2');
      await rule.evalJs('result', 'value');
      expect(runtime.lastScope.variables['src'], '<p>body</p>');
      expect(
        runtime.lastScope.variables['nextChapterUrl'],
        'https://example.test/ch/2',
      );
    },
  );

  test('put/get request variable round-trip', () async {
    final data = RuleData();
    final rule = AnalyzeRule(ruleData: data, jsRuntime: const NoJsRuntime())
      ..setContent('<ul><li>A</li><li>B</li></ul>');
    final items = await rule.getElements('@put:{seed:"继承作者"}tag.li');
    expect(items, hasLength(2));
    expect(data.get('seed'), '继承作者');
    final item = AnalyzeRule(
      ruleData: RuleData()..values.addAll(data.values),
      jsRuntime: const NoJsRuntime(),
    )..setContent(items.first);
    expect(await item.getString('@get:{seed}'), '继承作者');
  });

  test('JSONPath expands balanced legado embedded rules', () {
    final json = AnalyzeByJsonPath(
      jsonEncode({
        'title': '章节 } 一',
        'nested': {'value': '正文'},
      }),
    );
    expect(json.getString(r'标题:{$.title}'), '标题:章节 } 一');
    expect(json.getString(r'{$.nested.value}'), '正文');
  });

  test(
    'JSONPath filter keeps a quoted closing bracket inside the predicate',
    () {
      final json = AnalyzeByJsonPath({
        'items': [
          {'label': '] keep'},
          {'label': 'other'},
        ],
      });
      expect(json.getStringList(r'''$.items[?(@.label=="] keep")].label'''), [
        '] keep',
      ]);
    },
  );

  test(
    'malformed replacement regex falls back to literal replacement',
    () async {
      final rule = AnalyzeRule(jsRuntime: const NoJsRuntime())
        ..setContent('<p>abc</p>');
      // `[` is not a valid regex; Legado falls back to String.replace.
      expect(await rule.getString(r'tag.p@text##[##x'), 'abc');
    },
  );
}

class _CaptureRuntime implements JsRuntime {
  JsScope lastScope = JsScope();

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    lastScope = scope;
    return scope.variables['result'];
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async {
    return (await eval(code, scope))?.toString() ?? '';
  }
}
