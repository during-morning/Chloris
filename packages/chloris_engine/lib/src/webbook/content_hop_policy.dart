import '../net/network_utils.dart';

/// Pure hop / page-identity rules for chapter content (and TOC page walks).
/// WebBook fetches; this module decides which URLs are the same page, the
/// next chapter, or site chrome mistaken for body text.
class ContentHopPolicy {
  const ContentHopPolicy._();

  /// Drop fragments and cache-busting query keys so a next-page rule that
  /// appends `?t=` or `#page` cannot walk the same document to the hop limit.
  static String canonicalPageUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) {
      return url.split('#').first.trim();
    }
    const drop = {
      't',
      '_',
      '_t',
      'ts',
      'time',
      'timestamp',
      'rnd',
      'random',
      'r',
      'nocache',
    };
    final kept = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (!drop.contains(key.toLowerCase())) kept[key] = value;
    });
    var path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: path,
      queryParameters: kept.isEmpty ? null : kept,
    ).toString();
  }

  static bool markSeen(Set<String> seen, String url) =>
      seen.add(canonicalPageUrl(url));

  static String contentFingerprint(String html) =>
      html.replaceAll(RegExp(r'\s+'), '');

  static bool isRepeatContent(String html, String? lastFingerprint) {
    final fingerprint = contentFingerprint(html);
    return fingerprint.isNotEmpty && fingerprint == lastFingerprint;
  }

  /// Absolute continuation URLs that are new and not the next chapter.
  /// Accepted canons are added to [seen].
  static List<String> acceptNextUrls({
    required String currentUrl,
    required Iterable<String> candidates,
    required Set<String> seen,
    String? nextChapterUrl,
    int? limit,
  }) {
    final nextChapterCanon = (nextChapterUrl == null || nextChapterUrl.isEmpty)
        ? ''
        : canonicalPageUrl(getAbsoluteUrl(currentUrl, nextChapterUrl));
    final out = <String>[];
    for (final candidate in candidates) {
      if (limit != null && out.length >= limit) break;
      final abs = getAbsoluteUrl(currentUrl, candidate);
      if (abs.isEmpty) continue;
      final canon = canonicalPageUrl(abs);
      if (nextChapterCanon.isNotEmpty && canon == nextChapterCanon) {
        continue;
      }
      if (!seen.add(canon)) continue;
      out.add(abs);
    }
    return out;
  }

  /// Site chrome mistaken for a chapter body. Mixed pages that still have
  /// sentence punctuation are kept — a real chapter may start with a header.
  static bool isNavigationOnly(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return false;
    const markers = [
      '小说在线阅读',
      '前往客户端',
      '搜标签',
      '更精确的搜索结果',
      '大家都在搜',
      '去App听书',
      '返回',
      '取消',
    ];
    final hits = markers.where(compact.contains).length;
    if (hits < 2) return false;
    final sentencePunctuation = RegExp(r'[。！？；]').allMatches(compact).length;
    return sentencePunctuation == 0 || compact.length < 180;
  }
}
