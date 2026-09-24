import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'rss_models.dart';

/// 纯 Dart RSS 2.0 / Atom 解析器。
List<RssArticle> parseRss(String body, {String? sourceName}) {
  final trimmed = body.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _parseJsonFeed(body, sourceName: sourceName);
  }
  final doc = XmlDocument.parse(body);
  final articles = <RssArticle>[];

  for (final item in _elems(doc, 'item')) {
    final title = _firstText(item, 'title');
    final link = _firstText(item, 'link');
    final author = _firstText(item, 'author').isEmpty
        ? _firstText(item, 'creator')
        : _firstText(item, 'author');
    final pubDate = _firstText(item, 'pubDate').isEmpty
        ? _firstText(item, 'published')
        : _firstText(item, 'pubDate');
    final description = _firstText(item, 'description');
    final content = _firstText(item, 'encoded').isEmpty
        ? description
        : _firstText(item, 'encoded');
    articles.add(
      RssArticle(
        title: title,
        link: link,
        author: author,
        pubDate: pubDate,
        description: description,
        content: content,
        sourceName: sourceName ?? '',
      ),
    );
  }

  if (articles.isEmpty) {
    for (final entry in _elems(doc, 'entry')) {
      final title = _firstText(entry, 'title');
      final link = _linkHref(entry);
      final author = _firstText(entry, 'name');
      final pubDate = _firstText(entry, 'updated');
      final content = _firstText(entry, 'content');
      final summary = _firstText(entry, 'summary');
      articles.add(
        RssArticle(
          title: title,
          link: link,
          author: author,
          pubDate: pubDate,
          description: summary,
          content: content.isEmpty ? summary : content,
          sourceName: sourceName ?? '',
        ),
      );
    }
  }
  return articles;
}

List<RssArticle> _parseJsonFeed(String body, {String? sourceName}) {
  dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return [];
  }
  final rawItems = decoded is Map ? decoded['items'] : decoded;
  if (rawItems is! List) return [];
  final feedTitle = decoded is Map ? decoded['title']?.toString() ?? '' : '';
  final out = <RssArticle>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final author = raw['author'] is Map
        ? (raw['author']['name']?.toString() ?? '')
        : raw['author']?.toString() ?? '';
    final content = raw['content_html']?.toString().isNotEmpty == true
        ? raw['content_html'].toString()
        : raw['content_text']?.toString() ?? '';
    final description = raw['summary']?.toString() ?? '';
    out.add(
      RssArticle(
        title: raw['title']?.toString() ?? '',
        link: raw['url']?.toString() ?? raw['external_url']?.toString() ?? '',
        author: author,
        pubDate:
            raw['date_published']?.toString() ??
            raw['date_modified']?.toString() ??
            '',
        description: description,
        content: content.isEmpty ? description : content,
        sourceName: sourceName ?? feedTitle,
        image:
            raw['image']?.toString() ?? raw['banner_image']?.toString() ?? '',
      ),
    );
  }
  return out;
}

Iterable<XmlElement> _elems(XmlNode node, String local) => node.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local);

String _firstText(XmlNode node, String local) {
  for (final e in _elems(node, local)) {
    final t = e.innerText.trim();
    if (t.isNotEmpty) return t;
  }
  return '';
}

String _linkHref(XmlNode node) {
  for (final e in _elems(node, 'link')) {
    final href = e.getAttribute('href');
    if (href != null && href.isNotEmpty) return href;
  }
  return '';
}

/// Parses custom Legado RSS rules (ruleArticles and per-article fields).
/// A leading '-' on ruleArticles reverses the resulting article order.
Future<List<RssArticle>> parseRssByRule(
  String body,
  RssSource source, {
  required JsRuntime jsRuntime,
  String? baseUrl,
}) async {
  if (body.trim().isEmpty) return [];
  var articlesRule = source.ruleArticles?.trim() ?? '';
  if (articlesRule.isEmpty) {
    return parseRss(body, sourceName: source.sourceName);
  }
  var reverse = false;
  if (articlesRule.startsWith('-')) {
    reverse = true;
    articlesRule = articlesRule.substring(1).trim();
  }
  final analyzer = AnalyzeRule(jsRuntime: jsRuntime)
    ..setContent(body)
    ..setBaseUrl(baseUrl ?? source.sourceUrl);
  var items = await analyzer.getElements(articlesRule);
  if (body.contains('<')) {
    final cssRule = _normalizeCssRule(articlesRule);
    final direct = AnalyzeByCss(body).getElements(cssRule);
    if (direct.isNotEmpty) items = direct;
  }
  final result = <RssArticle>[];
  for (final item in items) {
    final itemAnalyzer = AnalyzeByCss(item);
    final title = itemAnalyzer.getString(
      _normalizeCssRule(source.ruleTitle ?? ''),
    );
    if (title.trim().isEmpty) continue;
    final link = _resolveUrl(
      itemAnalyzer.getString0(_normalizeCssRule(source.ruleLink ?? '')),
      baseUrl ?? source.sourceUrl,
    );
    final image = _resolveUrl(
      itemAnalyzer.getString0(_normalizeCssRule(source.ruleImage ?? '')),
      baseUrl ?? source.sourceUrl,
    );
    final description = itemAnalyzer.getString(
      _normalizeCssRule(source.ruleDescription ?? ''),
    );
    final contentRule = source.ruleContent ?? source.ruleDescription ?? '';
    final content = contentRule.isEmpty
        ? description
        : itemAnalyzer.getString(_normalizeCssRule(contentRule));
    final pubDate = itemAnalyzer.getString(
      _normalizeCssRule(source.rulePubDate ?? ''),
    );
    result.add(
      RssArticle(
        title: title,
        link: link,
        pubDate: pubDate,
        description: description,
        content: content.isEmpty ? description : content,
        sourceName: source.sourceName,
        image: image,
      ),
    );
  }
  if (reverse) return result.reversed.toList();
  return result;
}

String _normalizeCssRule(String rule) {
  final trimmed = rule.trim();
  if (trimmed.startsWith('tag.')) return trimmed.substring(4);
  if (trimmed.startsWith('class.')) return '.${trimmed.substring(6)}';
  return trimmed;
}

/// Extracts a custom next-page URL from a feed document.
String? rssNextPageUrl(String body, RssSource source, {String? baseUrl}) {
  final rule = source.ruleNextPage?.trim() ?? '';
  if (rule.isEmpty) return null;
  final value = AnalyzeByCss(body).getString0(_normalizeCssRule(rule));
  if (value.trim().isEmpty) return null;
  return _resolveUrl(value.trim(), baseUrl ?? source.sourceUrl);
}

String _resolveUrl(String value, String base) {
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  return Uri.parse(base).resolve(value).toString();
}
