import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import 'api_contract.dart';

/// One HTTP round trip, as the client needs it.
typedef ApiTransport =
    Future<({int status, String body})> Function(
      String method,
      String path, {
      Map<String, String>? query,
      Object? body,
    });

/// Client for the [ChlorisApiRoute] contract.
///
/// This is what turns the Web build into a renderer: instead of running the
/// engine in the browser, it asks a Chloris server for the catalogue and the
/// body text over the same contract that server was written against.
///
/// The transport is injected so the client can be tested without a socket.
class ChlorisApiClient {
  ChlorisApiClient({required this.transport, this.token = ''});

  final ApiTransport transport;

  /// Shared secret the server requires. Empty means "unauthenticated", which
  /// only a server started without a token would accept.
  final String token;

  /// Sends one request and unwraps the [ApiEnvelope].
  Future<Object?> _call(
    ChlorisApiRoute route, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final res = await transport(
      route.method,
      route.path,
      query: query,
      body: body,
    );

    Object? decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      throw DomainError(
        code: 'api_malformed_response',
        stage: DomainErrorStage.request,
        message: '服务端返回了非 JSON response',
        cause: res.body.length > 200 ? res.body.substring(0, 200) : res.body,
        recoverable: false,
        suggestedAction: '确认客户端与服务端的 apiVersion 是否一致',
      );
    }

    if (decoded is! Map) {
      throw DomainError(
        code: 'api_malformed_envelope',
        stage: DomainErrorStage.request,
        message: '服务端响应缺少 ApiEnvelope',
        recoverable: false,
      );
    }

    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['isSuccess'] != true) {
      throw DomainError(
        code: 'api_error',
        stage: _stageOf(envelope['stage']),
        message: envelope['errorMsg']?.toString() ?? '服务端返回错误',
        retryable: envelope['retryable'] == true,
        suggestedAction: envelope['suggestedAction']?.toString(),
      );
    }
    return envelope['data'];
  }

  static DomainErrorStage _stageOf(Object? raw) {
    final name = raw?.toString();
    for (final s in DomainErrorStage.values) {
      if (s.name == name) return s;
    }
    return DomainErrorStage.unknown;
  }

  /// `/version` — never authenticated, so a client can discover a mismatch
  /// before it has a token.
  Future<ServerInfo> version() async {
    final data = await _call(ChlorisApiRoute.version);
    if (data is! Map) {
      throw const DomainError(
        code: 'api_malformed_envelope',
        stage: DomainErrorStage.request,
        message: '/version 未返回 ServerInfo',
        recoverable: false,
      );
    }
    return ServerInfo.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Map<String, dynamic>>> bookshelf() async {
    final data = await _call(ChlorisApiRoute.getBookshelf);
    return _mapList(data);
  }

  Future<List<BookChapter>> chapterList(
    String bookUrl, {
    bool refresh = false,
  }) async {
    final route = refresh
        ? ChlorisApiRoute.refreshToc
        : ChlorisApiRoute.getChapterList;
    final data = await _call(
      route,
      query: ChapterListQuery(bookUrl: bookUrl, refresh: refresh).toQuery(),
    );
    return [
      for (final raw in _mapList(data))
        BookChapter(
          url: raw['url']?.toString() ?? '',
          title: raw['title']?.toString() ?? '',
          index: (raw['index'] as num?)?.toInt() ?? 0,
          isVolume: raw['isVolume'] == true,
          isVip: raw['isVip'] == true,
          isPay: raw['isPay'] == true,
          bookUrl: bookUrl,
        ),
    ];
  }

  Future<
    ({
      String title,
      String content,
      String? resourceUrl,
      String? variable,
      Map<String, String> mediaHeaders,
    })
  >
  bookContent(String bookUrl, int chapterIndex) async {
    final data = await _call(
      ChlorisApiRoute.getBookContent,
      query: BookContentQuery(
        bookUrl: bookUrl,
        chapterIndex: chapterIndex,
      ).toQuery(),
    );
    if (data is! Map) {
      throw const DomainError(
        code: 'content_empty',
        stage: DomainErrorStage.content,
        message: '服务端未返回正文',
        recoverable: false,
      );
    }
    return (
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      resourceUrl: data['resourceUrl']?.toString(),
      variable: data['variable']?.toString(),
      mediaHeaders: data['mediaHeaders'] is Map
          ? (data['mediaHeaders'] as Map).map<String, String>(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
  }

  Future<List<SearchBook>> explore(
    String sourceUrl,
    String url, {
    int page = 1,
  }) async {
    final data = await _call(
      ChlorisApiRoute.exploreBooks,
      body: OnlineBookRequest(
        sourceUrl: sourceUrl,
        url: url,
        page: page,
      ).toJson(),
    );
    if (data is! List) {
      throw const DomainError(
        code: 'capability_missing',
        stage: DomainErrorStage.search,
        message: '服务端尚未提供在线探索能力',
        recoverable: false,
      );
    }
    return [for (final raw in _mapList(data)) SearchBook.fromJson(raw)];
  }

  Future<Book> bookInfo(String sourceUrl, Book book) async {
    final data = await _call(
      ChlorisApiRoute.getBookInfo,
      body: OnlineBookRequest(sourceUrl: sourceUrl, book: book).toJson(),
    );
    if (data is! Map ||
        (data['bookUrl']?.toString().trim().isEmpty ?? true) &&
            (data['name']?.toString().trim().isEmpty ?? true)) {
      throw const DomainError(
        code: 'capability_missing',
        stage: DomainErrorStage.detail,
        message: '服务端尚未提供书籍详情能力',
        recoverable: false,
      );
    }
    return Book.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveProgress(BookProgressBody progress) =>
      _call(ChlorisApiRoute.saveBookProgress, body: progress.toJson());

  static List<Map<String, dynamic>> _mapList(Object? data) {
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }
}

/// An [ApiTransport] that goes through the engine's HTTP port.
///
/// Using the existing port rather than a fresh `HttpClient` keeps the client on
/// the same cookie jar, rate limiter and timeout policy as the rest of the app.
ApiTransport httpPortTransport(
  HttpPort http,
  String baseUrl, {
  String token = '',
}) {
  return (method, path, {query, body}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final res = await http.send(
      HttpRequestSpec(
        url: uri.toString(),
        method: method,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          if (token.isNotEmpty) 'authorization': 'Bearer $token',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return (status: res.code, body: res.body ?? '');
  };
}
