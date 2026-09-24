import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import '../../core/http/http_session.dart';
import 'rss_models.dart';
import 'rss_parser.dart';

/// RSS 网络端口。页面和状态层只依赖该端口，不直接持有 HTTP 会话。
abstract interface class RssFeedPort {
  Future<StrResponse> fetch(String url, {required String session});

  void cancel(String session);
}

/// 基于引擎 HTTP 端口的 RSS 适配器。
class EngineRssFeedAdapter implements RssFeedPort {
  const EngineRssFeedAdapter(this._http);

  final HttpPort _http;

  @override
  Future<StrResponse> fetch(String url, {required String session}) =>
      HttpSession.bind(session, () => _http.send(HttpRequestSpec(url: url)));

  @override
  void cancel(String session) {
    final port = _http;
    if (port is SessionAwareHttp) {
      (port as SessionAwareHttp).cancelSession(session);
    }
  }
}

/// RSS 正文 URL 黑/白名单判定（对齐 legado `ReadRssActivity.kt:639-665`
/// 的 shouldInterceptRequest 语义）：
/// - 逗号分隔条目，URL 以条目为前缀 **或** 匹配其正则即命中；
/// - 正则语法错误：跳过该条目（legado 记日志后跳过，不整体失败）；
/// - **黑名单优先**：非空且命中 → 拦截；黑名单为空时白名单才生效——
///   白名单非空且 URL 不命中 → 拦截。
bool rssArticleAllowed(String url, {String? whitelist, String? blacklist}) {
  final hits = (String raw) sync* {
    for (final it in raw.split(',')) {
      final e = it.trim();
      if (e.isEmpty) continue;
      yield e;
    }
  };
  final blocked = blacklist ?? '';
  if (blocked.trim().isNotEmpty) {
    for (final e in hits(blocked)) {
      if (url.startsWith(e)) return false;
      try {
        if (RegExp(e).hasMatch(url)) return false;
      } on FormatException {
        // 非法正则：跳过该条目（对齐 legado 行为）。
      }
    }
    return true;
  }
  final allowed = whitelist ?? '';
  if (allowed.trim().isNotEmpty) {
    for (final e in hits(allowed)) {
      if (url.startsWith(e)) return true;
      try {
        if (RegExp(e).hasMatch(url)) return true;
      } on FormatException {
        // 非法正则：跳过该条目。
      }
    }
    return false;
  }
  return true;
}

class LoadRssArticlesUseCase {
  const LoadRssArticlesUseCase(
    this._port, {
    this.jsRuntime = const NoJsRuntime(),
  });

  final RssFeedPort _port;

  /// Real JS runtime for subscription rules that use `<js>` / `@js:`.
  ///
  /// This used to be a hard-coded [LenientJsRuntime], so every unsupported RSS
  /// rule silently returned its input instead of failing. Callers now pass the
  /// engine runtime explicitly.
  final JsRuntime jsRuntime;

  Future<List<RssArticle>> call(
    RssSource source, {
    int maxPages = 5,
    String? startUrl,
  }) async {
    var url = startUrl ?? source.sourceUrl;
    final seenPages = <String>{};
    final articles = <RssArticle>[];
    for (var page = 0; page < maxPages && seenPages.add(url); page++) {
      final res = await _port.fetch(url, session: 'rss');
      if (res.code >= 400) {
        throw DomainError(
          code: 'rss_http_${res.code}',
          stage: DomainErrorStage.request,
          message: 'RSS 请求失败 HTTP ${res.code}',
          sourceId: source.sourceUrl,
          retryable: res.code >= 500,
          suggestedAction: '请重试或检查订阅源地址',
        );
      }
      final body = res.body ?? '';
      final parsed = await parseRssByRule(
        body,
        source,
        jsRuntime: jsRuntime,
        baseUrl: url,
      );
      final seenArticles = {
        for (final article in articles)
          article.link.isNotEmpty ? article.link : article.title,
      };
      for (final article in parsed) {
        final key = article.link.isNotEmpty ? article.link : article.title;
        if (key.isNotEmpty && seenArticles.add(key)) {
          // 正文 URL 黑/白名单过滤（黑名单优先）。
          if (!rssArticleAllowed(
            article.link,
            whitelist: source.contentWhitelist,
            blacklist: source.contentBlacklist,
          )) {
            continue;
          }
          articles.add(article);
        }
      }
      final next = rssNextPageUrl(body, source, baseUrl: url);
      if (next == null || next == url) break;
      url = next;
    }
    return articles;
  }

  void cancel() => _port.cancel('rss');
}

class ImportRssSourcesUseCase {
  const ImportRssSourcesUseCase(this._port);

  final RssFeedPort _port;

  Future<List<RssSource>> call(String url) async {
    final res = await _port.fetch(url, session: 'rss-import');
    if (res.code >= 400) {
      throw DomainError(
        code: 'rss_import_http_${res.code}',
        stage: DomainErrorStage.request,
        message: '订阅源导入请求失败 HTTP ${res.code}',
        retryable: res.code >= 500,
        suggestedAction: '请检查地址后重试',
      );
    }
    try {
      final list = RssSource.listFromJson(jsonDecode(res.body ?? ''));
      if (list.isEmpty) {
        throw DomainError(
          code: 'rss_import_empty',
          stage: DomainErrorStage.search,
          message: '没有解析到订阅源',
          retryable: false,
          suggestedAction: '请使用 Legado 订阅源 JSON 地址',
        );
      }
      return list;
    } on DomainError {
      rethrow;
    } catch (error) {
      throw DomainError(
        code: 'rss_import_invalid',
        stage: DomainErrorStage.search,
        message: '订阅源格式无效',
        cause: error,
        recoverable: true,
        retryable: false,
        suggestedAction: '请检查 JSON 格式',
      );
    }
  }

  void cancel() => _port.cancel('rss-import');
}
