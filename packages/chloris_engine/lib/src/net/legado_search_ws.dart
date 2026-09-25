import 'dart:async';
import 'dart:convert';

import '../models/book.dart';
import '../models/book_source.dart';
import '../models/domain_protocol.dart';
import 'engine_limits.dart';
import 'ws_port.dart';

/// Codec for the Legado-compatible searchBook socket stream. The server may
/// return one array, one book per frame, or an explicit end/error frame.
class LegadoSearchBookProtocol {
  const LegadoSearchBookProtocol._();

  static const path = '/searchBook';

  static Map<String, dynamic> request({
    required BookSource source,
    required String query,
    int page = 1,
    String? requestId,
  }) => {
    'tag': source.bookSourceUrl,
    'key': query,
    'page': page,
    if (requestId != null) 'id': requestId,
  };

  static List<SearchBook> decode(Object? frame, {String? sourceId}) {
    Object? raw = frame;
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (e) {
        throw _error('ws_protocol_malformed', '搜索响应不是有效 JSON', sourceId, e);
      }
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['error'] != null || map['isSuccess'] == false) {
        throw _error(
          'ws_search_error',
          map['errorMsg']?.toString() ?? map['error']?.toString() ?? '搜索失败',
          sourceId,
        );
      }
      final data = map['data'] ?? map['books'] ?? map['result'];
      if (data != null) return decode(data, sourceId: sourceId);
      if (map.containsKey('name') || map.containsKey('bookUrl')) {
        return [SearchBook.fromJson(map)];
      }
      return const [];
    }
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map) SearchBook.fromJson(Map<String, dynamic>.from(item)),
      ];
    }
    if (raw == null || raw == 'end') return const [];
    throw _error('ws_protocol_malformed', '搜索响应格式不支持', sourceId);
  }

  static bool isEnd(Object? frame) {
    if (frame == null) return true;
    if (frame is String && (frame == 'end' || frame == 'finish')) return true;
    if (frame is Map) {
      return frame['end'] == true ||
          frame['type'] == 'end' ||
          frame['state'] == 'end';
    }
    return false;
  }

  static DomainError _error(
    String code,
    String message,
    String? sourceId, [
    Object? cause,
  ]) => DomainError(
    code: code,
    stage: DomainErrorStage.search,
    message: message,
    sourceId: sourceId,
    cause: cause,
    recoverable: true,
    retryable: code == 'ws_timeout',
    suggestedAction: '检查 WebSocket 服务和书源配置后重试',
  );
}

Future<List<SearchBook>> searchOverWebSocket({
  required WsPort port,
  required BookSource source,
  required String query,
  int page = 1,
  bool Function(String name, String author, String? kind)? filter,
  Duration? timeout,
}) async {
  final uri = Uri.parse(
    source.webSocketUrl ?? source.searchUrl ?? source.bookSourceUrl,
  );
  final connection = await port
      .connect(
        WsRequestSpec(
          uri: uri,
          timeout: timeout ?? EngineLimits.searchTimeout,
          session: 'search',
        ),
      )
      .timeout(timeout ?? EngineLimits.searchTimeout);
  final results = <SearchBook>[];
  final done = Completer<List<SearchBook>>();
  late final StreamSubscription<Object?> subscription;
  subscription = connection.messages.listen(
    (frame) {
      try {
        if (LegadoSearchBookProtocol.isEnd(frame)) {
          if (!done.isCompleted) done.complete(results);
        } else {
          results.addAll(
            LegadoSearchBookProtocol.decode(
              frame,
              sourceId: source.bookSourceUrl,
            ),
          );
        }
      } catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!done.isCompleted) done.completeError(error, stack);
    },
    onDone: () {
      if (!done.isCompleted) done.complete(results);
    },
  );
  try {
    connection.send(
      jsonEncode(
        LegadoSearchBookProtocol.request(
          source: source,
          query: query,
          page: page,
        ),
      ),
    );
    final found = await done.future.timeout(
      timeout ?? EngineLimits.searchTimeout,
      onTimeout: () => throw LegadoSearchBookProtocol._error(
        'ws_timeout',
        'WebSocket 搜索超时',
        source.bookSourceUrl,
      ),
    );
    return filter == null
        ? found
        : [
            for (final b in found)
              if (filter(b.name, b.author, b.kind)) b,
          ];
  } finally {
    await subscription.cancel();
    await connection.close();
  }
}
