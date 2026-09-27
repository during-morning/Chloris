/// Versioned wire contract between a Chloris client and the Chloris server.
///
/// The plan moves the rule engine, the HTTP layer and the database into a
/// server process, leaving the Web build as a pure renderer. That only stays
/// maintainable if both sides agree on one explicit contract instead of
/// drifting route by route — so every route, request shape and error mapping
/// lives here rather than being re-invented at each call site.
///
/// Status: versioned contract. Book search, discovery, detail, catalogue and
/// content have concrete client/server adapters; remaining routes may still
/// report an explicit capability error.
library;

import 'package:chloris_engine/chloris_engine.dart';

/// Bumped whenever a request or response shape changes incompatibly.
///
/// A client refuses to talk to a server whose major version differs, instead
/// of silently mis-decoding responses.
const int chlorisApiVersion = 1;

/// How a client should behave when the server is unreachable or mismatched.
enum ServerAvailability {
  /// No server configured or reachable. The Web build is unusable here, by
  /// design: it owns no local storage of its own any more.
  unreachable,

  /// Reachable but speaking a different contract version.
  versionMismatch,

  /// Reachable, authenticated and compatible.
  ready,
}

/// One endpoint. Keeping method and path together makes it impossible to
/// document a route the server does not serve.
enum ChlorisApiRoute {
  getBookSources('GET', '/getBookSources'),
  getBookSource('GET', '/getBookSource'),
  saveBookSource('POST', '/saveBookSource'),
  saveBookSources('POST', '/saveBookSources'),
  deleteBookSources('POST', '/deleteBookSources'),

  getBookshelf('GET', '/getBookshelf'),
  saveBook('POST', '/saveBook'),
  deleteBook('POST', '/deleteBook'),
  saveBookProgress('POST', '/saveBookProgress'),

  getChapterList('GET', '/getChapterList'),
  refreshToc('GET', '/refreshToc'),
  getBookContent('GET', '/getBookContent'),
  exploreBooks('POST', '/exploreBooks'),
  getBookInfo('POST', '/getBookInfo'),
  getCover('GET', '/cover'),
  getImage('GET', '/image'),

  getReadConfig('GET', '/getReadConfig'),
  saveReadConfig('POST', '/saveReadConfig'),

  getRssSources('GET', '/getRssSources'),
  getRssSource('GET', '/getRssSource'),
  saveRssSource('POST', '/saveRssSource'),
  saveRssSources('POST', '/saveRssSources'),
  deleteRssSources('POST', '/deleteRssSources'),

  getReplaceRules('GET', '/getReplaceRules'),
  saveReplaceRule('POST', '/saveReplaceRule'),
  deleteReplaceRule('POST', '/deleteReplaceRule'),
  testReplaceRule('POST', '/testReplaceRule'),

  /// Version probe. Unauthenticated on purpose: a client must be able to
  /// discover a mismatch *before* it has a token.
  version('GET', '/version');

  const ChlorisApiRoute(this.method, this.path);

  final String method;
  final String path;
}

/// The Legado-E style response envelope, kept for wire compatibility.
///
/// Chloris additionally carries [DomainError] fields so the client can render a
/// stage and a recovery action rather than a bare string.
class ApiEnvelope {
  const ApiEnvelope({
    required this.isSuccess,
    this.data,
    this.errorMsg,
    this.stage,
    this.retryable,
    this.suggestedAction,
  });

  factory ApiEnvelope.ok(Object? data) =>
      ApiEnvelope(isSuccess: true, data: data);

  factory ApiEnvelope.failure(DomainError error) => ApiEnvelope(
    isSuccess: false,
    errorMsg: error.message,
    stage: error.stage,
    retryable: error.retryable,
    suggestedAction: error.suggestedAction,
  );

  final bool isSuccess;
  final Object? data;
  final String? errorMsg;
  final DomainErrorStage? stage;
  final bool? retryable;
  final String? suggestedAction;

  /// Rebuilds the engine-level error so the client keeps one error type.
  DomainError? toDomainError({String? sourceId}) {
    if (isSuccess) return null;
    return DomainError(
      code: 'api_error',
      stage: stage ?? DomainErrorStage.unknown,
      message: errorMsg ?? '服务端返回错误',
      sourceId: sourceId,
      retryable: retryable ?? false,
      suggestedAction: suggestedAction,
    );
  }
}

/// Server identity, returned by [ChlorisApiRoute.version].
class ServerInfo {
  const ServerInfo({
    required this.apiVersion,
    required this.appVersion,
    required this.capabilities,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
    apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 0,
    appVersion: json['appVersion']?.toString() ?? '',
    capabilities: {
      for (final e in (json['capabilities'] as Map? ?? const {}).entries)
        e.key.toString(): e.value == true,
    },
  );

  final int apiVersion;
  final String appVersion;

  /// Feature flags the client must consult before showing a control, so the
  /// UI never offers an action the server cannot perform.
  final Map<String, bool> capabilities;

  bool get isCompatible => apiVersion == chlorisApiVersion;

  Map<String, dynamic> toJson() => {
    'apiVersion': apiVersion,
    'appVersion': appVersion,
    'capabilities': capabilities,
  };
}

/// Query for [ChlorisApiRoute.getChapterList].
class ChapterListQuery {
  const ChapterListQuery({required this.bookUrl, this.refresh = false});

  final String bookUrl;

  /// `true` re-scrapes the catalog instead of serving the cached one.
  final bool refresh;

  Map<String, String> toQuery() => {
    'url': bookUrl,
    if (refresh) 'refresh': 'true',
  };

  static ChapterListQuery fromQuery(Map<String, String> q) => ChapterListQuery(
    bookUrl: q['url'] ?? '',
    refresh: q['refresh'] == 'true',
  );
}

/// Query for [ChlorisApiRoute.getBookContent].
class BookContentQuery {
  const BookContentQuery({
    required this.bookUrl,
    required this.chapterIndex,
  });

  final String bookUrl;
  final int chapterIndex;

  Map<String, String> toQuery() => {
    'url': bookUrl,
    'index': '$chapterIndex',
  };

  static BookContentQuery fromQuery(Map<String, String> q) =>
      BookContentQuery(
        bookUrl: q['url'] ?? '',
        chapterIndex: int.tryParse(q['index'] ?? '') ?? 0,
      );
}

/// Body for server-side explore and book-info operations.
class OnlineBookRequest {
  const OnlineBookRequest({
    required this.sourceUrl,
    this.url = '',
    this.page = 1,
    this.book,
  });

  final String sourceUrl;
  final String url;
  final int page;
  final Book? book;

  Map<String, dynamic> toJson() => {
    'sourceUrl': sourceUrl,
    if (url.isNotEmpty) 'url': url,
    'page': page,
    if (book != null) 'book': book!.toJson(),
  };

  static OnlineBookRequest fromJson(Map<String, dynamic> json) {
    final rawBook = json['book'];
    final rawPage = (json['page'] as num?)?.toInt() ?? 1;
    return OnlineBookRequest(
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      page: rawPage < 1 ? 1 : rawPage,
      book: rawBook is Map
          ? Book.fromJson(Map<String, dynamic>.from(rawBook))
          : null,
    );
  }
}

/// Body for [ChlorisApiRoute.saveBookProgress].
class BookProgressBody {
  const BookProgressBody({
    required this.bookUrl,
    required this.chapterIndex,
    this.chapterTitle = '',
    this.chapterPos = 0,
    this.updatedAt = 0,
  });

  final String bookUrl;
  final int chapterIndex;
  final String chapterTitle;
  final int chapterPos;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
    'bookUrl': bookUrl,
    'chapterIndex': chapterIndex,
    'chapterTitle': chapterTitle,
    'chapterPos': chapterPos,
    'updatedAt': updatedAt,
  };

  static BookProgressBody fromJson(Map<String, dynamic> json) =>
      BookProgressBody(
        bookUrl: json['bookUrl']?.toString() ?? '',
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        chapterTitle: json['chapterTitle']?.toString() ?? '',
        chapterPos: (json['chapterPos'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}
