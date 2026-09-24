import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';

class SourceSearchResult {
  const SourceSearchResult({
    required this.source,
    this.books = const [],
    this.error,
    this.errorInfo,
  });

  final BookSource source;
  final List<SearchBook> books;
  final String? error;
  final DomainError? errorInfo;
}

class SearchSession {
  const SearchSession({
    required this.query,
    required this.rows,
    required this.done,
    required this.total,
    required this.finished,
    this.page = 1,
    this.group = '',
    this.remaining = 0,
    this.universe = 0,
    this.attemptedSourceUrls = const <String>{},
  });

  const SearchSession.empty()
    : query = '',
      rows = const [],
      done = 0,
      total = 0,
      finished = true,
      page = 1,
      group = '',
      remaining = 0,
      universe = 0,
      attemptedSourceUrls = const <String>{};

  final String query;
  final List<SourceSearchResult> rows;
  final int done;
  final int total;
  final bool finished;
  final int page;
  final String group;

  /// Sources not yet attempted in the current full scan.
  final int remaining;

  /// All sources in this scope (e.g. 3643).
  final int universe;

  /// Source URLs whose requests have already been started in this scan.
  ///
  /// This is separate from [rows] because UI progress updates are throttled;
  /// a request may finish between two rendered snapshots and must still be
  /// excluded when the user resumes a cancelled scan.
  final Set<String> attemptedSourceUrls;

  int get hits => rows.fold(0, (a, r) => a + r.books.length);
  int get failCount =>
      rows.where((r) => r.error != null && r.error!.isNotEmpty).length;

  TaskState<List<SourceSearchResult>> get taskState {
    if (!finished) {
      final progress = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
      return TaskRunning(progress: progress, value: rows);
    }
    if (remaining > 0) return TaskCancelled(value: rows);
    if (failCount > 0 && hits > 0) {
      final errors = rows
          .map((row) => row.errorInfo)
          .whereType<DomainError>()
          .toList(growable: false);
      return TaskPartial(value: rows, errors: errors);
    }
    if (failCount > 0) {
      final firstError = rows
          .map((row) => row.errorInfo)
          .whereType<DomainError>()
          .toList(growable: false);
      return TaskFailed(
        firstError.isEmpty
            ? const DomainError(
                code: 'search_failed',
                stage: DomainErrorStage.search,
                message: '所有书源均未返回结果',
              )
            : firstError.first,
        value: rows,
      );
    }
    return TaskCompleted(rows);
  }
}

String friendlySearchError(Object e) {
  if (e is DomainError) {
    final action = e.suggestedAction;
    return action == null || action.isEmpty
        ? e.message
        : '${e.message}（$action）';
  }
  final raw = e.toString();
  final lower = raw.toLowerCase();
  if (raw.contains('搜索代理未启动') || raw.contains('/proxy/http')) {
    return '搜索代理未启动';
  }
  if (kIsWeb &&
      (lower.contains('xmlhttprequest') ||
          lower.contains('failed to fetch') ||
          lower.contains('cors') ||
          lower.contains('clientexception'))) {
    return '浏览器跨域限制（代理未就绪）';
  }
  if (raw.contains('无法解析请求地址')) return '规则未解析';
  if (lower.contains('failed host lookup')) return '无法连接';
  return raw.split('\n').first;
}

String searchSourceHost(BookSource source) {
  return Uri.tryParse(source.bookSourceUrl)?.host ?? source.bookSourceUrl;
}
