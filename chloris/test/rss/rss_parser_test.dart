import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/application/rss/rss_models.dart';
import 'package:chloris/application/rss/rss_parser.dart';

void main() {
  test('RSS 2.0 解析', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>示例</title>
<item><title>新闻一</title><link>https://example.com/1</link><description>摘要一</description><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate><author>作者甲</author></item>
<item><title>新闻二</title><link>https://example.com/2</link><description>摘要二</description></item>
</channel></rss>''';
    final articles = parseRss(xml, sourceName: '示例源');
    expect(articles.length, 2);
    expect(articles.first.title, '新闻一');
    expect(articles.first.link, 'https://example.com/1');
    expect(articles.first.sourceName, '示例源');
  });

  test('Atom 解析', () {
    const xml = '''
<feed xmlns="http://www.w3.org/2005/Atom"><title>示例Atom</title>
<entry><title>一</title><link href="https://example.com/a"/><updated>2024-01-01T00:00:00Z</updated><summary>概述</summary></entry>
</feed>''';
    final articles = parseRss(xml);
    expect(articles.length, 1);
    expect(articles.first.link, 'https://example.com/a');
  });

  test('JSON Feed 解析内容、作者和图片', () {
    const json = '''
    {"version":"https://jsonfeed.org/version/1.1","title":"JSON 源",
     "items":[{"id":"1","title":"文章一","url":"/one",
       "date_published":"2024-01-01T00:00:00Z",
       "author":{"name":"作者"},"content_html":"<p>正文</p>",
       "image":"https://example.com/cover.jpg"}]}
    ''';
    final articles = parseRss(json);
    expect(articles, hasLength(1));
    expect(articles.first.title, '文章一');
    expect(articles.first.author, '作者');
    expect(articles.first.content, '<p>正文</p>');
    expect(articles.first.sourceName, 'JSON 源');
    expect(articles.first.image, 'https://example.com/cover.jpg');
  });
  test('Legado ruleArticles 解析自定义文章字段并支持倒序', () async {
    const body =
        '<root><article class="article"><title>一</title><a href="/one">链接</a><desc>正文一</desc></article><article class="article"><title>二</title><a href="/two">链接</a><desc>正文二</desc></article></root>';
    final source = RssSource(
      sourceUrl: 'https://example.com/feed',
      sourceName: '自定义源',
      ruleArticles: '-@css:.article',
      ruleTitle: '@css:title',
      ruleLink: '@css:a@href',
      ruleDescription: '@css:desc',
    );
    final articles = await parseRssByRule(
      body,
      source,
      jsRuntime: const LenientJsRuntime(),
      baseUrl: source.sourceUrl,
    );
    expect(articles.map((e) => e.title), ['二', '一']);
    expect(articles.first.link, 'https://example.com/two');
    expect(articles.first.content, '正文二');
  });

  test('RssSource 保留 Legado rule 字段往返', () {
    final source = RssSource.fromJson({
      'sourceUrl': 'https://example.com',
      'ruleArticles': '.article',
      'ruleTitle': '.title',
      'rulePubDate': '.date',
      'ruleDescription': '.desc',
      'ruleImage': '.cover@src',
      'ruleLink': '.link@href',
      'ruleNextPage': '.next@href',
    });
    final json = source.toJson();
    expect(json['ruleArticles'], '.article');
    expect(json['ruleNextPage'], '.next@href');
    expect(RssSource.fromJson(json).ruleImage, '.cover@src');
  });
}
