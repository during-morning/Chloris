import 'dart:async';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import '../persist/kv_settings.dart';
import 'search_match.dart';

/// 换源验证等级：L1 只验证目录，L2 还验证了正文探针。
enum SourceVerificationLevel { none, l1Catalog, l2Content }

class SourceVerification {
  const SourceVerification({
    required this.level,
    this.chapterCount = 0,
    this.contentLength = 0,
    this.failureCode,
  });

  const SourceVerification.rejected(String code)
    : level = SourceVerificationLevel.none,
      chapterCount = 0,
      contentLength = 0,
      failureCode = code;

  final SourceVerificationLevel level;
  final int chapterCount;
  final int contentLength;
  final String? failureCode;

  bool get accepted => level.index >= SourceVerificationLevel.l1Catalog.index;

  Map<String, Object?> toJson() => {
    'level': level.name,
    'chapterCount': chapterCount,
    'contentLength': contentLength,
    if (failureCode != null) 'failureCode': failureCode,
  };
}

class SourceSwitchCandidate {
  const SourceSwitchCandidate({
    required this.source,
    required this.book,
    required this.score,
    required this.reasons,
  });

  final BookSource source;
  final SearchBook book;
  final int score;
  final List<String> reasons;

  String get key => '${source.bookSourceUrl}\u0001${book.bookUrl}';
}

class SourceSwitchDecision {
  const SourceSwitchDecision({
    required this.algorithmVersion,
    required this.sourceUrl,
    required this.bookUrl,
    required this.score,
    required this.reasons,
    required this.verification,
    required this.selected,
    required this.createdAt,
  });

  final String algorithmVersion;
  final String sourceUrl;
  final String bookUrl;
  final int score;
  final List<String> reasons;
  final SourceVerification verification;
  final bool selected;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'algorithmVersion': algorithmVersion,
    'sourceUrl': sourceUrl,
    'bookUrl': bookUrl,
    'score': score,
    'reasons': reasons,
    'verification': verification.toJson(),
    'selected': selected,
    'createdAt': createdAt.toIso8601String(),
  };
}

class SourceSwitchSelection {
  const SourceSwitchSelection({
    required this.candidate,
    required this.verification,
    required this.decision,
  });

  final SourceSwitchCandidate candidate;
  final SourceVerification verification;
  final SourceSwitchDecision decision;
}

typedef SourceCandidateVerifier =
    Future<SourceVerification> Function(SourceSwitchCandidate candidate);

/// 自动换源和换源面板共享的领域服务。
///
/// UI 只负责收集候选和触发动作；评分、去重、验证顺序以及选择理由都由
/// 这里决定，避免两个入口在站点质量变化后产生不同结果。
class SourceSwitchService {
  SourceSwitchService({required this.verify});

  static const algorithmVersion = 'source-switch-v1';

  final SourceCandidateVerifier verify;
  final decisions = <SourceSwitchDecision>[];

  static int score(
    SearchBook book, {
    required String bookName,
    String bookAuthor = '',
  }) => sourceCandidateScore(book, bookName: bookName, bookAuthor: bookAuthor);

  static bool accepts(
    SearchBook book, {
    required String bookName,
    String bookAuthor = '',
  }) => isAcceptableSourceCandidate(
    book,
    bookName: bookName,
    bookAuthor: bookAuthor,
  );

  SourceSwitchCandidate? candidate(
    BookSource source,
    SearchBook book, {
    required String bookName,
    String bookAuthor = '',
  }) {
    if (!accepts(book, bookName: bookName, bookAuthor: bookAuthor)) return null;
    final value = score(book, bookName: bookName, bookAuthor: bookAuthor);
    final reasons = <String>[];
    final normalizedName = normalizeSearchText(book.name);
    final normalizedQuery = normalizeSearchText(bookName);
    if (normalizedName == normalizedQuery) {
      reasons.add('书名完全匹配');
    } else if (normalizedName.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedName)) {
      reasons.add('书名包含匹配');
    } else {
      reasons.add(
        '书名相似度 ${searchMatchRatio(book, bookName).toStringAsFixed(2)}',
      );
    }
    if (bookAuthor.trim().isNotEmpty &&
        normalizeSearchText(book.author) == normalizeSearchText(bookAuthor)) {
      reasons.add('作者匹配');
    }
    if (book.tocUrl.trim().isNotEmpty) reasons.add('已有目录入口');
    return SourceSwitchCandidate(
      source: source,
      book: book,
      score: value,
      reasons: List.unmodifiable(reasons),
    );
  }

  /// 按来源去重并按解释性分数排序，保留每个源最好的命中。
  List<SourceSwitchCandidate> rank(Iterable<SourceSwitchCandidate> input) {
    final best = <String, SourceSwitchCandidate>{};
    for (final item in input) {
      final key = item.source.bookSourceUrl;
      final old = best[key];
      if (old == null || item.score > old.score) best[key] = item;
    }
    final out = best.values.toList();
    out.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.source.bookSourceUrl.compareTo(b.source.bookSourceUrl);
    });
    return out;
  }

  /// 逐个验证候选，达到 L1 即可选中；L2 可由调用方在正文探针成功后返回。
  Future<SourceSwitchSelection?> select(
    Iterable<SourceSwitchCandidate> input, {
    int? maxVerify,
    bool Function()? isCancelled,
  }) async {
    final cancelled = isCancelled ?? () => false;
    final ranked = rank(input);
    final candidates = maxVerify == null ? ranked : ranked.take(maxVerify);
    for (final candidate in candidates) {
      if (cancelled()) return null;
      SourceVerification verification;
      try {
        verification = await verify(candidate);
      } catch (error) {
        verification = SourceVerification.rejected(_failureCode(error));
      }
      final selected = verification.accepted;
      final decision = SourceSwitchDecision(
        algorithmVersion: algorithmVersion,
        sourceUrl: candidate.source.bookSourceUrl,
        bookUrl: candidate.book.bookUrl,
        score: candidate.score,
        reasons: [
          ...candidate.reasons,
          if (verification.chapterCount > 0)
            '目录 ${verification.chapterCount} 章',
          if (verification.contentLength > 0)
            '正文探针 ${verification.contentLength} 字',
          if (!selected && verification.failureCode != null)
            '验证失败：${verification.failureCode}',
        ],
        verification: verification,
        selected: selected,
        createdAt: DateTime.now(),
      );
      decisions.add(decision);
      // Diagnostics are best-effort and must not add a preferences round-trip
      // to the foreground source switch path.
      unawaited(SourceSelectionLog.record(decision));
      if (selected) {
        return SourceSwitchSelection(
          candidate: candidate,
          verification: verification,
          decision: decision,
        );
      }
    }
    return null;
  }

  static String _failureCode(Object error) {
    if (error is DomainError) return error.code;
    return 'verification_failed';
  }
}

/// 最近选择记录供诊断页和问题回放使用；容量有界，不影响主流程。
class SourceSelectionLog {
  SourceSelectionLog._();

  static const key = 'sourceSelectionDecisionsV1';
  static const maxEntries = 100;

  static Future<void> record(SourceSwitchDecision decision) async {
    try {
      final prefs = await KvSettings.ready();
      final raw = prefs.getString(key);
      final list = <dynamic>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list.addAll(decoded);
      }
      list.add(decision.toJson());
      final start = list.length > maxEntries ? list.length - maxEntries : 0;
      await prefs.setString(key, jsonEncode(list.sublist(start)));
    } catch (_) {
      // Diagnostics must never make a successful source switch fail.
    }
  }
}
