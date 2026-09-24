// The html package already carries the WHATWG/HTML4 entity table used by its
// tokenizer. Reusing that table keeps this lightweight text helper aligned
// with Legado's StringEscapeUtils.unescapeHtml4 without parsing surrounding
// markup.
import 'package:html/src/constants.dart' as html_constants;

import 'http_port.dart';

Uri? parseUri(String url) {
  try {
    return Uri.parse(url);
  } catch (_) {
    return null;
  }
}

/// 取域名基址。
///
/// 对齐 Legado-E `NetworkUtils.getBaseUrl`（`NetworkUtils.kt:192-203`）：**只**认
/// `http://` / `https://`，其它 scheme（`data:`、`file:` 等）一律返回 null。
/// 旧实现直接取 `Uri.origin`，遇到 `data:` 会抛
/// 「Origin is only applicable schemes http and https」—— 而 `data:` URI 是
/// Legado 支持的一等公民（`AnalyzeUrl.kt:634-645`），必须能走通。
String? getBaseUrl(String url) {
  final lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return null;
  }
  final uri = parseUri(url);
  if (uri == null || !uri.hasScheme) return null;
  return uri.origin;
}

String getSubDomain(String url) {
  final uri = parseUri(url);
  if (uri == null) return url;
  return uri.host;
}

/// Percent-encode a query/form value using the source charset.
///
/// UTF-8 keeps Dart's `Uri.encodeQueryComponent`. GBK/Big5 sites expect
/// `%D6%D0` style bytes, not UTF-8 `%E4%B8%AD`.
String encodeQueryWithCharset(String text, [String? charset]) {
  if (text.isEmpty) return '';
  final name = (charset ?? '').toLowerCase().replaceAll('-', '');
  if (name.isEmpty || name.contains('utf8') || name.contains('utf-8')) {
    return Uri.encodeQueryComponent(text);
  }
  final bytes = CharsetEncoder.encode(text, charset!);
  final out = StringBuffer();
  for (final raw in bytes) {
    final c = raw & 0xff;
    if ((c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        (c >= 0x30 && c <= 0x39) ||
        c == 0x2d ||
        c == 0x2e ||
        c == 0x5f ||
        c == 0x7e) {
      out.writeCharCode(c);
    } else if (c == 0x20) {
      out.write('+');
    } else {
      out.write('%');
      out.write(c.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return out.toString();
}

/// Restore legado placeholders that `Uri` percent-encoded (`{{page}}`, `<1,1>`).
String restoreLegadoPlaceholders(String input) {
  return input
      .replaceAll('%7B%7B', '{{')
      .replaceAll('%7D%7D', '}}')
      .replaceAll('%7b%7b', '{{')
      .replaceAll('%7d%7d', '}}')
      .replaceAll('%3C', '<')
      .replaceAll('%3E', '>')
      .replaceAll('%3c', '<')
      .replaceAll('%3e', '>');
}

int legadoOptionComma(String s) {
  var depth = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '{') depth++;
    if (c == '}') depth--;
    if (c == ',' && depth == 0) {
      final rest = s.substring(i + 1).trimLeft();
      if (rest.startsWith('{')) return i;
    }
  }
  return -1;
}

String getAbsoluteUrl(String? base, String rel) {
  var trimmed = restoreLegadoPlaceholders(rel.trim());
  if (trimmed.isEmpty) return base ?? '';
  if (trimmed.startsWith('data:')) return trimmed;
  String? option;
  final comma = legadoOptionComma(trimmed);
  if (comma >= 0) {
    option = trimmed.substring(comma);
    trimmed = trimmed.substring(0, comma);
  }
  String resolved;
  if (trimmed.toLowerCase().startsWith('http://') ||
      trimmed.toLowerCase().startsWith('https://')) {
    resolved = restoreLegadoPlaceholders(trimmed);
  } else if (base == null || base.isEmpty) {
    resolved = trimmed;
  } else {
    try {
      final holders = <String, String>{};
      var i = 0;
      final safeRel = trimmed.replaceAllMapped(
        RegExp(r'\{\{[\s\S]*?\}\}|<[^>\s][^>]*>'),
        (m) {
          final token = '__ph${i++}__';
          holders[token] = m.group(0)!;
          return token;
        },
      );
      var out = Uri.parse(base).resolve(safeRel).toString();
      holders.forEach((token, original) {
        out = out.replaceAll(token, original);
        out = out.replaceAll(Uri.encodeComponent(token), original);
      });
      resolved = restoreLegadoPlaceholders(out);
    } catch (_) {
      resolved = trimmed;
    }
  }
  return option == null ? resolved : '$resolved$option';
}

String htmlUnescape(String input) {
  final entity = RegExp(
    r'&(#(?:[xX][0-9A-Fa-f]+|[0-9]+)|[A-Za-z][A-Za-z0-9]+);?',
  );
  return input.replaceAllMapped(entity, (m) {
    final raw = m.group(1)!;
    if (raw.startsWith('#')) {
      final hex = raw.length > 1 && (raw[1] == 'x' || raw[1] == 'X');
      final digits = raw.substring(hex ? 2 : 1);
      final code = int.tryParse(digits, radix: hex ? 16 : 10);
      // Keep invalid/surrogate code points unchanged, matching HTML entity
      // decoders' safe replacement behavior for malformed numeric references.
      if (code == null ||
          code < 0 ||
          code > 0x10ffff ||
          (code >= 0xd800 && code <= 0xdfff)) {
        return m.group(0)!;
      }
      return String.fromCharCode(code);
    }
    return html_constants.entities[raw] ??
        html_constants.entities['$raw;'] ??
        m.group(0)!;
  });
}

/// Collapse whitespace (including newlines) inside a media URL.
/// Sites like SFACG wrap long `src` values across lines:
/// `http://rs.sfacg.com/.../Upload\nPic/2018/08/....jpg`.
String normalizeMediaUrl(String raw) {
  var s = htmlUnescape(raw.trim());
  s = s.replaceAll(RegExp(r'[\s\u00a0\u200b\u200c\u200d\ufeff]+'), '');
  if (s.length >= 2) {
    final a = s.codeUnitAt(0);
    final b = s.codeUnitAt(s.length - 1);
    if ((a == 34 && b == 34) || (a == 39 && b == 39)) {
      s = s.substring(1, s.length - 1);
    }
  }
  return s;
}

final _imgTag = RegExp(r'<img\b[\s\S]*?>', caseSensitive: false);
final _imgSrcAttr = RegExp(
  r'''(?:data-original|data-lazy-src|data-src|src)\s*=\s*(?:["']([^"']*)["']|([^\s>]+))''',
  caseSensitive: false,
);

/// Pull the first usable image URL out of an `<img>` tag, including
/// multiline / spaced `src` values.
String? extractImgSrc(String tag) {
  String? best;
  for (final m in _imgSrcAttr.allMatches(tag)) {
    final raw = m.group(1) ?? m.group(2) ?? '';
    final src = normalizeMediaUrl(raw);
    if (src.isEmpty || src.startsWith('data:image/svg')) continue;
    best = src;
    final name = m.group(0)!.toLowerCase();
    if (name.contains('data-original') ||
        name.contains('data-lazy-src') ||
        name.contains('data-src')) {
      return src;
    }
  }
  return best;
}

final _httpUrl = RegExp(r'https?://[^\s"<>]+', caseSensitive: false);
final _sourceSrc = RegExp(
  r'''<(?:source|video|audio)\b[\s\S]*?src\s*=\s*["']([^"']+)["']''',
  caseSensitive: false,
);

/// First playable http(s) URL in chapter content (audio / video sources).
String extractPlayableUrl(String content) {
  final fromTag = _sourceSrc.firstMatch(content)?.group(1);
  if (fromTag != null) {
    final u = normalizeMediaUrl(fromTag);
    if (u.startsWith('http')) return u;
  }
  final img = extractImgSrc(content);
  if (img != null && _looksMediaFile(img)) return img;
  for (final line in content.split('\n')) {
    final t = normalizeMediaUrl(line);
    if (t.startsWith('http') && !t.contains('<')) return t;
  }
  final m = _httpUrl.firstMatch(normalizeMediaUrl(content));
  return m == null ? content.trim() : normalizeMediaUrl(m.group(0)!);
}

bool _looksMediaFile(String url) {
  final u = url.toLowerCase();
  return u.contains('.mp3') ||
      u.contains('.m4a') ||
      u.contains('.aac') ||
      u.contains('.flac') ||
      u.contains('.wav') ||
      u.contains('.mp4') ||
      u.contains('.m3u8') ||
      u.contains('.webm') ||
      u.contains('.mov');
}

/// Join CSS/XPath hits without keeping nested copies of the same intro.
/// Parent `@text` already includes children; child hits must not be appended.
String collapseJoinedStrings(List<String> parts) {
  final cleaned = [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim(),
  ];
  if (cleaned.isEmpty) return '';
  if (cleaned.length == 1) return collapseRepeatedText(cleaned.first);
  final longest = cleaned.reduce((a, b) => a.length >= b.length ? a : b);
  if (cleaned.every((s) => s == longest || longest.contains(s))) {
    return collapseRepeatedText(longest);
  }
  final unique = <String>[];
  for (final s in cleaned) {
    if (unique.any((e) => e == s || e.contains(s))) continue;
    final i = unique.indexWhere((e) => s.contains(e));
    if (i >= 0) {
      unique[i] = s;
    } else {
      unique.add(s);
    }
  }
  return collapseRepeatedText(unique.join('\n'));
}

/// Drop 2–3 copies of the same intro, including multi-paragraph cycles.
String collapseRepeatedText(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  s = s.replaceAll(RegExp(r'\r\n?'), '\n');
  s = s.replaceAll(RegExp(r'[ \t\u00a0\u3000]+'), ' ');
  s = s.replaceAll(RegExp(r'\n{2,}'), '\n');
  s = s.replaceAll(RegExp(r'^(简介|內容簡介|内容简介|作品简介|介绍)\s*[:：]\s*'), '');
  final paras = s
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (paras.isEmpty) return '';
  if (paras.length >= 2 && paras.every((p) => p == paras.first)) {
    return paras.first;
  }
  for (var unit = 1; unit <= paras.length ~/ 2; unit++) {
    if (paras.length < unit * 2) continue;
    if (paras.length % unit != 0) continue;
    final copies = paras.length ~/ unit;
    if (copies < 2) continue;
    var ok = true;
    for (var c = 1; c < copies; c++) {
      for (var i = 0; i < unit; i++) {
        if (paras[c * unit + i] != paras[i]) {
          ok = false;
          break;
        }
      }
      if (!ok) break;
    }
    if (ok) return paras.take(unit).join('\n');
  }
  final compact = paras.join();
  final period = _repeatPeriod(compact);
  if (period > 0 && compact.length >= period * 2) {
    final unit = compact.substring(0, period);
    if (paras.first.replaceAll(RegExp(r'\s+'), '') == unit) {
      return paras.first;
    }
    return unit;
  }
  return paras.join('\n');
}

int _repeatPeriod(String s) {
  final n = s.length;
  if (n < 6) return 0;
  final pi = List<int>.filled(n, 0);
  for (var i = 1; i < n; i++) {
    var j = pi[i - 1];
    while (j > 0 && s[i] != s[j]) {
      j = pi[j - 1];
    }
    if (s[i] == s[j]) j++;
    pi[i] = j;
  }
  final period = n - pi[n - 1];
  if (period > 0 && period < n && n % period == 0 && n ~/ period >= 2) {
    return period;
  }
  for (var copies = 3; copies >= 2; copies--) {
    if (n % copies != 0) continue;
    final unitLen = n ~/ copies;
    if (unitLen < 4) continue;
    final unit = s.substring(0, unitLen);
    var ok = true;
    for (var i = 1; i < copies; i++) {
      if (s.substring(i * unitLen, (i + 1) * unitLen) != unit) {
        ok = false;
        break;
      }
    }
    if (ok) return unitLen;
  }
  return 0;
}

String htmlFormat(String html, {String? baseUrl}) {
  var s = html.replaceAll(
    RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  final imgs = <String>[];
  s = s.replaceAllMapped(_imgTag, (m) {
    final src = extractImgSrc(m.group(0)!);
    if (src == null || src.isEmpty) return '';
    final abs = (baseUrl == null || baseUrl.isEmpty)
        ? src
        : getAbsoluteUrl(baseUrl, src);
    imgs.add(abs);
    return '\n＠IMG${imgs.length - 1}＠\n';
  });
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  for (var i = 0; i < imgs.length; i++) {
    s = s.replaceAll('＠IMG$i＠', '<img src="${imgs[i]}">');
  }
  s = htmlUnescape(s);
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String oneLineName(String name) {
  var n = name.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  n = n.split(RegExp(r'[\n\r]')).first.trim();
  final cut = n.indexOf(RegExp(r'\s*(签约|征文|推荐票|新书|完结|连载中)\s*$'));
  if (cut > 4) n = n.substring(0, cut).trim();
  if (n.length > 40) n = n.substring(0, 40).trim();
  return n;
}

/// Site chrome mistaken for a book: sort tabs, rank pills, pager.
bool isChromeBookName(String name) {
  final compact = name.trim().replaceAll(RegExp(r'[\s\u3000_\-·•]+'), '');
  if (compact.isEmpty) return true;
  const exact = {
    '最多收藏',
    '最多推荐',
    '最多点击',
    '最多阅读',
    '最多更新',
    '最多评论',
    '最多援力',
    '最多人气',
    '最多追书',
    '最多月票',
    '最多打赏',
    '综合排序',
    '默认排序',
    '最新排序',
    '热度排序',
    '好评排序',
    '人气排序',
    '全部显示',
    '显示全部',
    '查看更多',
    '换一批',
    '上一页',
    '下一页',
    '尾页',
    '首页',
    '加入书架',
    '立即阅读',
    '开始阅读',
    '免费阅读',
    '排行榜',
    '小说分类',
    '手机版',
    '电脑版',
    '搜索结果',
    '详情页',
    '归档',
    '分类',
    '标签',
    '专题',
    '频道',
    '书库',
    '书城',
    '书架',
    '书签',
    '排行',
    '推荐',
    '完本',
    '连载',
    '男生',
    '女生',
    '出版',
    '公告',
    '帮助',
    '反馈',
    '设置',
    '投稿',
    '作者',
    '作者专区',
    '最新入库',
    '最近更新',
    '本周推荐',
    '本月推荐',
    '总推荐',
    '总收藏',
    '总点击',
  };
  if (exact.contains(compact)) return true;
  if (RegExp(r'^(综合|默认|最新|热度|好评|人气)?排序$').hasMatch(compact)) {
    return true;
  }
  if (RegExp(r'^最多(收藏|推荐|点击|阅读|更新|评论|援力|人气|追书|月票|打赏|鲜花)$').hasMatch(compact)) {
    return true;
  }
  if (RegExp(r'^全部(显示|小说|作品|书|章节)$').hasMatch(compact)) {
    return true;
  }
  if (RegExp(r'^(查看)?更多(小说|作品|书籍)?$').hasMatch(compact)) {
    return true;
  }
  return false;
}

bool isChromeBookUrl(String url) {
  final u = url.toLowerCase();
  if (u.isEmpty) return false;
  if (RegExp(r'[?&](sort|rank|order|orderby|order_by)=').hasMatch(u)) {
    return true;
  }
  if (RegExp(r'[?&](tag|cat|cate|category|label|archive)=').hasMatch(u)) {
    return true;
  }
  return u.contains('/sort/') ||
      u.contains('/rank/') ||
      u.contains('/order/') ||
      u.contains('/tag/') ||
      u.contains('/tags/') ||
      u.contains('/category/') ||
      u.contains('/categories/') ||
      u.contains('/archive/') ||
      u.contains('/label/') ||
      u.contains('/labels/') ||
      u.endsWith('/sort') ||
      u.endsWith('/rank') ||
      u.endsWith('/tag') ||
      u.endsWith('/category') ||
      u.endsWith('/archive');
}

/// Site navigation accidentally extracted as a chapter from a book detail
/// page. These labels are common in Chinese novel sites and are only applied
/// by the TOC sanitizer when a source returns a sufficiently large list.
bool isChromeChapterName(String name) {
  final compact = name.trim().replaceAll(RegExp(r'[\s\u3000_\-·•]+'), '');
  if (compact.isEmpty) return true;
  const exact = {
    '登录账号',
    '登录',
    '注册',
    '桌面快捷',
    '看过的书',
    '我的书架',
    '在线阅读',
    '出版图书',
    '古典作品',
    '世界名著',
    '小说作品',
    '社会科学',
    '文学艺术',
    '生活少儿',
    '科学技术',
    '名家文集',
    '玄幻',
    '奇幻',
    '穿越',
    '修真',
    '都市',
    '言情',
    '科幻',
    '校园',
    '历史',
    '分类',
    '标签',
    '排行',
    '首页',
    '目录',
    '上一章',
    '下一章',
    '返回目录',
    '返回书页',
  };
  return exact.contains(compact) ||
      RegExp(r'^(登录|注册|我的|看过的|桌面).{0,8}(账号|书|书架|快捷)?$').hasMatch(compact);
}

String formatBookName(String name) {
  var n = name
      .replaceAll(RegExp(r'\s+作\s*者.*'), '')
      .replaceAll(RegExp(r'\s+\S+\s+著'), '')
      .trim();
  n = n
      .split(RegExp(r'[\n\r]'))
      .map((e) => e.trim())
      .firstWhere((e) => e.isNotEmpty, orElse: () => n);
  n = n.replaceAll(RegExp(r'(签约|征文|主题征文|推荐票)$'), '').trim();
  return oneLineName(collapseRepeatedText(n));
}

bool looksLikeInfoBlob(String s) {
  final t = s.trim();
  if (t.isEmpty) return false;
  if (t.contains('综合信息') || t.contains(r'$1') || t.contains('＄1')) return true;
  if (RegExp(r'[\$＄]\s*\d+').hasMatch(t)) return true;
  if (t.contains('\n') &&
      t.split('\n').where((e) => e.trim().isNotEmpty).length >= 3) {
    return true;
  }
  return t.length > 80;
}

/// Strip title/metadata leftovers and 2–3 pasted copies from a book intro.
String sanitizeBookIntro(String input, {String? name, String? author}) {
  var s = input.replaceAll(RegExp(r'[\$＄]\s*\d+'), '\n');
  s = collapseRepeatedText(s);
  final nameN = oneLineName(name ?? '');
  final authorN = formatBookAuthor(author ?? '');
  final kept = <String>[];
  for (var line in s.split('\n')) {
    var t = line.trim();
    if (t.isEmpty) continue;
    if (RegExp(r'^[\$＄]\s*\d+$').hasMatch(t)) continue;
    if (RegExp(
      r'^(综合信息|最新|最后更新|更新时间|更新|状态|类别|分类|字数|章节|目录|签约)\s*[:：]?',
    ).hasMatch(t)) {
      continue;
    }
    if (nameN.isNotEmpty) {
      final compactT = t.replaceAll(RegExp(r'\s+'), '');
      final compactN = nameN.replaceAll(RegExp(r'\s+'), '');
      if (t == nameN || compactT == compactN) continue;
      if (t.startsWith(nameN)) t = t.substring(nameN.length).trim();
      if (t.endsWith(nameN)) t = t.substring(0, t.length - nameN.length).trim();
      t = t.replaceAll(nameN, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (authorN.isNotEmpty &&
        !looksLikeInfoBlob(authorN) &&
        (t == authorN || t.contains('作者') && t.contains(authorN))) {
      continue;
    }
    if (t.isEmpty || t == '简介' || t == '介绍') continue;
    kept.add(t);
  }
  return collapseRepeatedText(kept.join('\n'));
}

String formatBookAuthor(String author) {
  var a = author.replaceAll(RegExp(r'^\s*作\s*者[:：\s]+'), '').trim();
  a = a.split(RegExp(r'[\n\r]')).first.trim();
  if (looksLikeInfoBlob(a) || a.length > 32) return '';
  return a;
}

String wordCountFormat(String raw) {
  return raw.trim();
}
