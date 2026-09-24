// Characterization tests for Legado-compatible behavior and known platform
// boundaries. Keep every assertion tied to a reproducible fixture.
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('RULE-01: replacement suffix is preserved through selector makeup', () async {
    final rule = AnalyzeRule(jsRuntime: const NoJsRuntime())
      ..setContent('<p>old</p>');
    expect(await rule.getString('tag.p@text##old##new'), 'new');
    // Legado replaceRegex remains attached after interpolation.
  });

  test('CONTENT-01: valid short content is preserved', () async {
    final http = _FixtureHttp((_) => '<div id="novel">完。</div>');
    expect(await _read(http), contains('完。'));
    // Legado BookContent preserves short chapters; no 24-character threshold.
  });

  test('CONTENT-01b: short structural fallback is preserved', () async {
    final http = _FixtureHttp((_) => '<div id="content">完。</div>');
    expect(await _read(http), contains('完。'));
  });

  test('CONTENT-02: pagination follows six pages', () async {
    final http = _FixtureHttp((i) => _page(i, next: i < 6));
    final text = await _read(http, paginate: true);
    expect(text, allOf(contains('page4'), contains('page5'), contains('page6')));
    // Legado loops until next URL ends/repeats or reaches next chapter.
  });

  test('CONTENT-03: failed continuation is surfaced as a content error', () async {
    final http = _FixtureHttp((i) {
      if (i == 2) throw StateError('fixture continuation failure');
      return _page(i, next: true);
    });
    await expectLater(
      _read(http, paginate: true),
      throwsA(isA<DomainError>()),
    );
  });

  test('CONTENT-04: navigation-only extraction is rejected as empty content', () async {
    final http = _FixtureHttp(
      (_) => '<div id="novel">'
          '我的模拟长生路 小说在线阅读 返回 取消 前往客户端获取'
          '搜标签 更精确的搜索结果 大家都在搜 去App听书'
          '</div>',
    );
    await expectLater(
      _read(http),
      throwsA(isA<ContentEmptyException>()),
    );
  });

  test('RULE-02: JSON interleave follows Legado first-list semantics', () {
    final json = AnalyzeByJsonPath({'a': ['A'], 'b': ['B', 'C']});
    expect(json.getStringList(r'$.a[*]%%$.b[*]'), ['A', 'B']);
    // Legado AnalyzeByJSonPath uses results[0].indices.
  });

  test('IR-01: quoted JS marker in CSS stays inside the selector', () {
    final program = const RuleCompiler().compile('a[data-value="@js:literal"]@text');
    expect(program.steps, hasLength(1));
    expect(program.steps.single.mode, RuleMode.css);
    // Quote-aware scanning matches Legado's selector context.
  });
}

Future<String> _read(_FixtureHttp http, {bool paginate = false}) {
  final source = BookSource(
    bookSourceUrl: 'https://fixture.invalid',
    ruleContent: ContentRule(
      content: 'id.novel@text',
      nextContentUrl: paginate ? 'tag.a@href' : null,
    ),
  );
  final book = Book(bookUrl: 'https://fixture.invalid/book', tocUrl: 'https://fixture.invalid/toc');
  final chapter = BookChapter(url: 'https://fixture.invalid/1', title: 'fixture');
  return WebBook(http: http, jsRuntime: const NoJsRuntime()).getContent(source, book, chapter);
}

String _page(int i, {required bool next}) =>
    '<div id="novel">page$i ${'这是足够长的确定性正文。' * 4}</div>'
    '${next ? '<a href="/${i + 1}">继续</a>' : ''}';

class _FixtureHttp extends HttpPort {
  _FixtureHttp(this.response);
  final String Function(int page) response;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async => StrResponse(
    url: spec.url,
    body: response(int.parse(Uri.parse(spec.url).pathSegments.last)),
  );

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async => Uint8List(0);
}
