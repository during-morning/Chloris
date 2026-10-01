import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../analyze/analyze_rule.dart';
import '../analyze/analyze_url.dart';
import '../analyze/rule_data.dart';
import '../constants/constants.dart';
import '../debug/debug_log.dart';
import '../js/java_host.dart';
import '../js/js_runtime.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/domain_protocol.dart';
import '../models/rules.dart';
import '../net/cookie_store.dart';
import '../net/engine_limits.dart';
import '../net/file_port.dart';
import '../net/host_environment.dart';
import '../net/http_port.dart';
import '../net/network_utils.dart';
import '../net/str_response.dart';
import '../net/web_view_port.dart';
import 'chapter_list_hygiene.dart';
import 'content_hop_policy.dart';

/// Raised when a chapter rule matched no readable content.  Callers can use
/// this category to distinguish rule failures from transport errors.
class ContentEmptyException extends DomainError {
  ContentEmptyException(
    this.chapterTitle, {
    this.url,
    String? sourceId,
    String? bookId,
    String? chapterId,
  }) : super(
         code: 'content_empty',
         stage: DomainErrorStage.content,
         message: '章节规则未提取到可读正文',
         sourceId: sourceId,
         bookId: bookId,
         chapterId: chapterId ?? url ?? chapterTitle,
         recoverable: true,
         retryable: false,
         suggestedAction: '检查正文规则或更换书源',
       );
  final String chapterTitle;
  final String? url;

  @override
  String toString() => 'ContentEmpty: $chapterTitle (${url ?? ''})';
}

class WebBook {
  WebBook({
    required this.http,
    required this.jsRuntime,
    this.cookieStore,
    this.webViewPort,
    this.filePort = const UnsupportedFilePort(),
    this.hostEnvironment = const DefaultHostEnvironment(),
  }) {
    _javaHost = JavaHost(
      http: http,
      cookieStore: cookieStore ?? CookieStore(),
      jsRuntime: jsRuntime,
      webViewPort: webViewPort,
      filePort: filePort,
      hostEnvironment: hostEnvironment,
    );
  }

  final HttpPort http;
  final JsRuntime jsRuntime;
  final CookieStore? cookieStore;
  final WebViewPort? webViewPort;

  /// File access handed to rule scripts. Defaults to "not available".
  final FilePort filePort;

  /// Platform interactions and settings handed to rule scripts.
  final HostEnvironment hostEnvironment;
  late final JavaHost _javaHost;

  JavaHost get javaHost => _javaHost;

  final Map<String, (DateTime, StrResponse)> _recentPages = {};

  Future<List<SearchBook>> searchBook(
    BookSource source,
    String key, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async {
    final searchUrl = source.searchUrl;
    if (searchUrl == null || searchUrl.isEmpty) {
      throw StateError('搜索url不能为空');
    }
    DebugLog.log(source.bookSourceUrl, '搜索「$key」 p$page', phase: 'search');
    final ruleData = RuleData();
    final analyzeUrl = AnalyzeUrl(
      mUrl: searchUrl,
      http: http,
      jsRuntime: jsRuntime,
      key: key,
      page: page,
      baseUrl: source.bookSourceUrl,
      source: source,
      ruleData: ruleData,
      cookieStore: cookieStore,
      javaHost: _javaHost,
      webViewPort: webViewPort,
    );
    final res = await analyzeUrl.getStrResponse();
    final list = await analyzeBookList(
      source: source,
      ruleData: ruleData,
      analyzeUrl: analyzeUrl,
      baseUrl: res.url,
      body: res.body,
      isSearch: true,
      decodeCover: false,
    );
    if (filter == null) return list;
    return [
      for (final book in list)
        if (filter(book.name, book.author, book.kind)) book,
    ];
  }

  Future<List<SearchBook>> exploreBook(
    BookSource source,
    String url, {
    int page = 1,
  }) async {
    final ruleData = RuleData();
    final analyzeUrl = AnalyzeUrl(
      mUrl: url,
      http: http,
      jsRuntime: jsRuntime,
      page: page,
      baseUrl: source.bookSourceUrl,
      source: source,
      ruleData: ruleData,
      cookieStore: cookieStore,
      javaHost: _javaHost,
      webViewPort: webViewPort,
    );
    final res = await analyzeUrl.getStrResponse();
    return analyzeBookList(
      source: source,
      ruleData: ruleData,
      analyzeUrl: analyzeUrl,
      baseUrl: res.url,
      body: res.body,
      isSearch: false,
    );
  }

  Future<Book> getBookInfo(BookSource source, Book book) async {
    book.type = BookType.fromSourceType(source.bookSourceType);
    final identity = book.bookUrl;
    DebugLog.log(source.bookSourceUrl, '详情 ${book.bookUrl}', phase: 'info');
    final res = await _get(
      source,
      book.bookUrl,
      book: book,
      timeout: EngineLimits.tocTimeout,
    );
    await _analyzeInfo(source, book, res.url, res.body ?? '');
    book.bookUrl = identity;
    if (book.tocUrl.isEmpty) book.tocUrl = res.url;
    return book;
  }

  Future<List<BookChapter>> getChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) async {
    await _runPreUpdateJs(source, book);
    final tocUrl = (book.tocUrl.isEmpty) ? book.bookUrl : book.tocUrl;
    String body = book.tocHtml ?? book.infoHtml ?? '';
    String base = tocUrl;
    try {
      if (book.tocHtml != null &&
          book.tocHtml!.length > 800 &&
          tocUrl == book.bookUrl) {
        body = book.tocHtml!;
        base = book.bookUrl;
      } else {
        final res = await _get(
          source,
          tocUrl,
          book: book,
          timeout: EngineLimits.tocTimeout,
        );
        body = res.body ?? '';
        base = res.url;
      }
    } catch (e) {
      DebugLog.error(source.bookSourceUrl, '目录 $tocUrl', e);
      if (tocUrl != book.bookUrl) {
        try {
          final res = await _get(
            source,
            book.bookUrl,
            book: book,
            timeout: EngineLimits.tocTimeout,
          );
          body = res.body ?? '';
          base = res.url;
        } catch (e2) {
          DebugLog.error(source.bookSourceUrl, '目录回退 ${book.bookUrl}', e2);
        }
      }
    }
    List<BookChapter> chapters = [];
    try {
      chapters = await _analyzeChapters(
        source,
        book,
        base,
        body,
        maxPages: maxPages,
        onPartial: onPartial,
      );
    } catch (e) {
      DebugLog.error(source.bookSourceUrl, '解析目录', e);
      chapters = [];
    }
    if (ChapterListHygiene.isUnusable(chapters, base) &&
        tocUrl != book.bookUrl) {
      try {
        final res = await _get(
          source,
          book.bookUrl,
          book: book,
          timeout: EngineLimits.tocTimeout,
        );
        final again = await _analyzeChapters(
          source,
          book,
          res.url,
          res.body ?? '',
          maxPages: maxPages,
          onPartial: onPartial,
        );
        if (again.length > chapters.length) chapters = again;
        body = res.body ?? body;
        base = res.url;
      } catch (e) {
        DebugLog.error(source.bookSourceUrl, '目录二次解析', e);
      }
    }
    // 规则已经给出完整目录时，不要再扫整页 HTML。
    if (chapters.length < 8 || ChapterListHygiene.isUnusable(chapters, base)) {
      final fallback = _fallbackChapters(book, base, body);
      if (fallback.length > chapters.length) {
        chapters = fallback;
      } else if (ChapterListHygiene.isUnusable(chapters, base)) {
        chapters = fallback.isNotEmpty ? fallback : chapters;
      } else if (chapters.length < 8 && fallback.length >= chapters.length) {
        chapters = ChapterListHygiene.merge(chapters, fallback);
      }
    }
    chapters = ChapterListHygiene.sanitize(chapters);
    return _indexChapters(book, chapters);
  }

  Future<String> getContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    // Legado follows continuation links until they end or repeat. Keep a
    // generous safety ceiling for malformed cyclic sources.
    int maxHops = 32,
  }) async {
    DebugLog.log(
      source.bookSourceUrl,
      '正文 ${chapter.title} ${chapter.url}',
      phase: 'content',
    );
    if (chapter.isVolume) return chapter.title;
    final chapterUrl = getAbsoluteUrl(
      chapter.baseUrl.isEmpty ? book.tocUrl : chapter.baseUrl,
      chapter.url.isEmpty ? book.tocUrl : chapter.url,
    );
    final res = await _get(
      source,
      chapterUrl,
      book: book,
      chapter: chapter,
      jsStr: source.getContentRule().webJs,
      sourceRegex: source.getContentRule().sourceRegex,
      timeout: EngineLimits.contentTimeout,
    );
    return _analyzeContent(
      source,
      book,
      chapter,
      res.url,
      res.body ?? '',
      nextChapterUrl,
      maxHops: maxHops,
    );
  }

  Future<StrResponse> _get(
    BookSource source,
    String url, {
    Book? book,
    BookChapter? chapter,
    String? jsStr,
    String? sourceRegex,
    Duration? timeout,
  }) async {
    final memoKey =
        (jsStr == null || jsStr.isEmpty) &&
            (sourceRegex == null || sourceRegex.isEmpty)
        ? url
        : null;
    if (memoKey != null) {
      final hit = _recentPages[memoKey];
      if (hit != null &&
          DateTime.now().difference(hit.$1) < const Duration(seconds: 12)) {
        return hit.$2;
      }
    }
    final analyzeUrl = AnalyzeUrl(
      mUrl: url,
      http: http,
      jsRuntime: jsRuntime,
      baseUrl: source.bookSourceUrl,
      source: source,
      book: book,
      chapter: chapter,
      cookieStore: cookieStore,
      javaHost: _javaHost,
      webViewPort: webViewPort,
      allowInteractiveLogin: true,
      timeout: timeout,
    );
    final res = await analyzeUrl.getStrResponse(
      jsStr: jsStr,
      sourceRegex: sourceRegex,
    );
    if (memoKey != null && (res.body ?? '').isNotEmpty) {
      _recentPages[memoKey] = (DateTime.now(), res);
      if (_recentPages.length > 16) {
        final oldest = _recentPages.entries.reduce(
          (a, b) => a.value.$1.isBefore(b.value.$1) ? a : b,
        );
        _recentPages.remove(oldest.key);
      }
    }
    return res;
  }

  Future<List<SearchBook>> analyzeBookList({
    required BookSource source,
    required RuleData ruleData,
    required AnalyzeUrl analyzeUrl,
    required String baseUrl,
    required String? body,
    required bool isSearch,
    bool decodeCover = true,
  }) async {
    if (body == null) throw StateError('内容为空 $baseUrl');
    final rule =
        AnalyzeRule(
            ruleData: ruleData,
            source: source,
            jsRuntime: jsRuntime,
            javaHost: _javaHost,
          )
          ..page = analyzeUrl.page ?? 1
          ..setContent(body, baseUrl)
          ..setRedirectUrl(baseUrl);
    final pattern = source.bookUrlPattern;
    if (isSearch && pattern != null && pattern.isNotEmpty) {
      if (RegExp(pattern).hasMatch(baseUrl)) {
        final book = await _infoAsSearch(
          source,
          rule,
          analyzeUrl,
          body,
          baseUrl,
        );
        return book == null ? [] : [book];
      }
    }
    final searchRule = source.getSearchRule();
    final exploreRule = source.getExploreRule();
    // Legado selects one rule set for a request.  Cross-falling each field to
    // the other set creates hybrid selectors that can silently yield blanks.
    final dynamic selected = isSearch
        ? searchRule
        : ((exploreRule.bookList ?? '').trim().isNotEmpty
              ? exploreRule
              : searchRule);
    var bookListRule = (selected.bookList ?? '').trim();
    var reverseBooks = false;
    if (bookListRule.startsWith('-')) {
      reverseBooks = true;
      bookListRule = bookListRule.substring(1).trim();
    } else if (bookListRule.startsWith('+')) {
      bookListRule = bookListRule.substring(1).trim();
    }
    final nameRule = (selected.name ?? '').trim();
    final authorRule = (selected.author ?? '').trim();
    final kindRule = (selected.kind ?? '').trim();
    final coverRule = (selected.coverUrl ?? '').trim();
    final introRule = (selected.intro ?? '').trim();
    final wordRule = (selected.wordCount ?? '').trim();
    final lastRule = (selected.lastChapter ?? '').trim();
    final urlRule = (selected.bookUrl ?? '').trim();
    var items = bookListRule.isEmpty
        ? <Object>[body]
        : await rule.getElements(bookListRule);
    if (items.isEmpty || items.length == 1 && identical(items.first, body)) {
      for (final fb in const [
        'class.item',
        'class.bookbox',
        'class.book',
        'class.result',
        'class.novel_list@tag.li',
        'id.main@tag.li',
        'tag.li',
      ]) {
        final found = await rule.getElements(fb);
        if (found.length >= 3) {
          items = found;
          break;
        }
      }
    }
    final out = <SearchBook>[];
    Future<T> safeField<T>(Future<T> value, T fallback, String field) async {
      try {
        return await value;
      } catch (e) {
        // A malformed optional selector must not discard an otherwise valid
        // search row.  This mirrors BookList's per-field try/catch behavior
        // while retaining a diagnostic for source debugging.
        DebugLog.error(source.bookSourceUrl, '列表项$field', e);
        return fallback;
      }
    }

    for (final item in items) {
      // Legado seeds each SearchBook's variable map with the request-level
      // RuleData, then evaluates fields against that per-item map.  Copying
      // here preserves @put/@get inheritance without leaking one item's
      // values into the next item (or racing another source request).
      final itemData = RuleData()..values.addAll(ruleData.values);
      final itemRule =
          AnalyzeRule(
              ruleData: itemData,
              source: source,
              jsRuntime: jsRuntime,
              javaHost: _javaHost,
            )
            ..page = analyzeUrl.page ?? 1
            ..setContent(item, baseUrl)
            ..setRedirectUrl(baseUrl);
      final name = formatBookName(
        await safeField(itemRule.getString(nameRule), '', '书名'),
      );
      if (name.isEmpty || isChromeBookName(name)) continue;
      var href = await safeField(
        itemRule.getString(urlRule, isUrl: true),
        '',
        '详情链接',
      );
      if (href.isEmpty || href == baseUrl) {
        href = await safeField(
          itemRule.getString('tag.a@href', isUrl: true),
          '',
          '详情链接回退',
        );
      }
      if (href.isEmpty) continue;
      final author = formatBookAuthor(
        await safeField(itemRule.getString(authorRule), '', '作者'),
      );
      final kindValues = await safeField<List<String>>(
        itemRule.getStringList(kindRule),
        const <String>[],
        '分类',
      );
      final coverRaw = await safeField(
        itemRule.getString(coverRule, isUrl: true),
        '',
        '封面',
      );
      final cover = decodeCover
          ? await _decodeCover(source, coverRaw, book: null)
          : coverRaw;
      final introRaw = await safeField(itemRule.getString(introRule), '', '简介');
      final wordRaw = await safeField(itemRule.getString(wordRule), '', '字数');
      final last = await safeField(itemRule.getString(lastRule), '', '最新章节');
      out.add(
        SearchBook(
          bookUrl: href,
          origin: source.bookSourceUrl,
          originName: source.bookSourceName,
          type: BookType.fromSourceType(source.bookSourceType),
          name: name,
          author: author,
          kind: kindValues.join(','),
          coverUrl: cover,
          intro: sanitizeBookIntro(
            htmlFormat(introRaw),
            name: name,
            author: author,
          ),
          wordCount: wordCountFormat(wordRaw),
          latestChapterTitle: last,
          tocUrl: '',
          originOrder: source.customOrder,
          variable: itemData.values.isEmpty
              ? null
              : jsonEncode(itemData.values),
        ),
      );
    }
    if (out.isEmpty) {
      out.addAll(_fallbackBooks(source, baseUrl, body));
    }
    if (reverseBooks) {
      final reversed = out.reversed.toList();
      out
        ..clear()
        ..addAll(reversed);
    }
    DebugLog.log(
      source.bookSourceUrl,
      isSearch ? '搜索命中 ${out.length}' : '发现命中 ${out.length}',
      state: out.isEmpty ? -1 : 1,
      phase: isSearch ? 'search' : 'explore',
    );
    return out;
  }

  List<SearchBook> _fallbackBooks(
    BookSource source,
    String baseUrl,
    String body,
  ) {
    final doc = html_parser.parse(body);
    var anchors = doc.querySelectorAll(
      '.book a, .item a, .result a, .novel_list a, .novelslist2 a, li a, dd a',
    );
    if (anchors.length < 3) {
      anchors = doc.querySelectorAll('a[href]');
    }
    final out = <SearchBook>[];
    final seen = <String>{};
    for (final a in anchors) {
      final name = formatBookName(a.text.trim());
      var href = a.attributes['href'] ?? '';
      if (name.length < 2 || name.length > 48) continue;
      if (isChromeBookName(name)) continue;
      if (RegExp(r'首页|登录|注册|排行榜|最新|完本|联系|关于').hasMatch(name) &&
          name.length < 6) {
        continue;
      }
      href = getAbsoluteUrl(baseUrl, href);
      if (!href.startsWith('http') || href == baseUrl) continue;
      if (isChromeBookUrl(href) && name.length <= 8) continue;
      if (!seen.add('$name|$href')) continue;
      out.add(
        SearchBook(
          bookUrl: href,
          origin: source.bookSourceUrl,
          originName: source.bookSourceName,
          type: BookType.fromSourceType(source.bookSourceType),
          name: name,
          originOrder: source.customOrder,
        ),
      );
      if (out.length >= 30) break;
    }
    return out;
  }

  List<BookChapter> _indexChapters(
    Book book,
    List<BookChapter> chapters, {
    bool reverse = false,
  }) {
    final seenUrl = <String>{};
    final seenTitle = <String>{};
    final out = <BookChapter>[];
    for (final ch in chapters) {
      final url = _canonChapterUrl(ch.url);
      if (url.isEmpty) continue;
      ch.url = url;
      if (!seenUrl.add(url)) continue;
      final titleKey = ch.title.replaceAll(RegExp(r'\s+'), '');
      if (titleKey.isNotEmpty && !seenTitle.add(titleKey)) continue;
      out.add(ch);
    }
    final list = reverse ? out.reversed.toList() : out;
    for (var i = 0; i < list.length; i++) {
      list[i].index = i;
    }
    book.totalChapterNum = list.length;
    if (list.isNotEmpty) {
      book.latestChapterTitle = list.last.title;
    }
    return list;
  }

  String _canonChapterUrl(String url) {
    var u = url.trim();
    final hash = u.indexOf('#');
    if (hash >= 0) u = u.substring(0, hash);
    try {
      final uri = Uri.parse(u);
      final q = Map<String, String>.from(uri.queryParameters);
      for (final k in const [
        'page',
        'from',
        'style',
        't',
        'ts',
        '_',
        'frompage',
      ]) {
        q.remove(k);
      }
      final cleaned = uri.replace(
        queryParameters: q.isEmpty ? <String, String>{} : q,
        fragment: '',
      );
      var out = cleaned.toString();
      if (q.isEmpty) {
        out = out.replaceAll(RegExp(r'\?$'), '');
      }
      if (out.endsWith('/')) out = out.substring(0, out.length - 1);
      return out;
    } catch (_) {
      return u;
    }
  }

  List<BookChapter> _fallbackChapters(Book book, String baseUrl, String body) {
    final doc = html_parser.parse(body);
    var anchors = doc.querySelectorAll(
      '#list dd a, #list a, .listmain a, .box_con #list a, '
      '.chapterlist a, #chapterlist a, .mulu a, .dirlist a, '
      '.chapter a, .list a, dd a, dt a',
    );
    if (anchors.length < 3) {
      anchors = doc.querySelectorAll('a[href]');
    }
    final out = <BookChapter>[];
    final seen = <String>{};
    final chapterLike = RegExp(r'第.+(章|回|节|卷)|Chapter|\d+\s*[\.、]');
    for (final a in anchors) {
      final title = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      var href = a.attributes['href'] ?? '';
      if (title.length < 1 || title.length > 80) continue;
      href = getAbsoluteUrl(baseUrl, href);
      if (!href.startsWith('http')) continue;
      final looksChapter =
          chapterLike.hasMatch(title) ||
          href.contains('chapter') ||
          href.contains('chap') ||
          href.contains('/read') ||
          href.contains('xiaoshuo') ||
          href.contains('book') ||
          href.contains('.html');
      // 链接很多时才强过滤，否则尽量保留以免目录只剩 1 条。
      if (!looksChapter && anchors.length > 80) continue;
      if (RegExp(r'首页|书架|排行|登录|注册|完本|最新|手机版').hasMatch(title)) {
        continue;
      }
      if (!seen.add(href)) continue;
      out.add(
        BookChapter(
          url: href,
          title: title,
          bookUrl: book.bookUrl,
          baseUrl: baseUrl,
        ),
      );
    }
    return _indexChapters(book, out);
  }

  Future<SearchBook?> _infoAsSearch(
    BookSource source,
    AnalyzeRule rule,
    AnalyzeUrl analyzeUrl,
    String body,
    String baseUrl,
  ) async {
    final book = Book(
      bookUrl: baseUrl,
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      type: BookType.fromSourceType(source.bookSourceType),
      infoHtml: body,
    );
    await _analyzeInfo(source, book, baseUrl, body);
    return SearchBook(
      bookUrl: book.bookUrl,
      origin: book.origin,
      originName: book.originName,
      type: book.type,
      name: book.name,
      author: book.author,
      kind: book.kind,
      coverUrl: book.coverUrl,
      intro: book.intro,
      wordCount: book.wordCount,
      latestChapterTitle: book.latestChapterTitle,
      tocUrl: book.tocUrl,
    )..infoHtml = body;
  }

  Future<void> _analyzeInfo(
    BookSource source,
    Book book,
    String baseUrl,
    String body,
  ) async {
    final rule =
        AnalyzeRule(source: source, jsRuntime: jsRuntime, javaHost: _javaHost)
          ..setBook(book)
          ..setContent(body, baseUrl)
          ..setRedirectUrl(baseUrl);
    final info = source.getBookInfoRule();
    if ((info.init ?? '').isNotEmpty) {
      final el = await rule.getElement(info.init!);
      if (el != null) rule.setContent(el, baseUrl);
    }
    final name = formatBookName(await rule.getString(info.name));
    if (name.isNotEmpty) book.name = name;
    final author = formatBookAuthor(await rule.getString(info.author));
    if (author.isNotEmpty)
      book.author = author;
    else
      book.author = '';
    final kindRaw = (await rule.getStringList(info.kind)).join(',');
    book.kind = looksLikeInfoBlob(kindRaw) ? '' : kindRaw;
    final word = wordCountFormat(await rule.getString(info.wordCount));
    if (word.isNotEmpty) book.wordCount = word;
    final intro = sanitizeBookIntro(
      htmlFormat(await rule.getString(info.intro)),
      name: book.name,
      author: book.author,
    );
    if (intro.isNotEmpty) book.intro = intro;
    final cover = await rule.getString(info.coverUrl, isUrl: true);
    if (cover.isNotEmpty) {
      book.coverUrl = await _decodeCover(source, cover, book: book);
    }
    final last = await rule.getString(info.lastChapter);
    if (last.isNotEmpty) book.latestChapterTitle = last;
    final toc = await rule.getString(info.tocUrl, isUrl: true);
    book.tocUrl = toc.isEmpty ? book.bookUrl : toc;
    if (BookType.has(book.type, BookType.webFile) &&
        (info.downloadUrls ?? '').trim().isNotEmpty) {
      final urls = await rule.getStringList(info.downloadUrls, isUrl: true);
      if (urls.isEmpty) {
        throw StateError('下载地址为空');
      }
      book.downloadUrls = urls;
    }
    if (toc.isEmpty || toc == book.bookUrl) {
      book.tocHtml = body;
      book.infoHtml = body;
    }
  }

  Future<List<BookChapter>> _analyzeChapters(
    BookSource source,
    Book book,
    String baseUrl,
    String body, {
    int maxPages = 6,
    void Function(List<BookChapter> chapters)? onPartial,
  }) async {
    final toc = source.getTocRule();
    var listRule = toc.chapterList ?? '';
    var reverse = false;
    if (listRule.startsWith('-')) {
      reverse = true;
      listRule = listRule.substring(1);
    }
    if (listRule.startsWith('+')) listRule = listRule.substring(1);
    final chapters = <BookChapter>[];
    void emitPartial() {
      onPartial?.call(
        List<BookChapter>.from(ChapterListHygiene.sanitize(chapters)),
      );
    }

    final first = await _analyzeOneTocPage(
      source: source,
      book: book,
      toc: toc,
      listRule: listRule,
      currentUrl: baseUrl,
      currentBody: body,
      discoverNext: true,
      chapterOffset: 0,
      onProgress: (part) => onPartial?.call(
        List<BookChapter>.from(ChapterListHygiene.sanitize(part)),
      ),
    );
    chapters.addAll(first.chapters);
    emitPartial();
    final seenPages = <String>{
      ContentHopPolicy.canonicalPageUrl(baseUrl),
      for (final url in first.nextUrls) ContentHopPolicy.canonicalPageUrl(url),
    };
    final nexts = [
      for (final url in first.nextUrls)
        if (url.isNotEmpty &&
            ContentHopPolicy.canonicalPageUrl(url) !=
                ContentHopPolicy.canonicalPageUrl(baseUrl))
          url,
    ];
    if (nexts.isNotEmpty && maxPages > 1) {
      if (nexts.length > 1) {
        final urls = nexts.take(maxPages - 1).toList();
        final pages = await _fetchTocPagesConcurrent(
          source: source,
          book: book,
          toc: toc,
          listRule: listRule,
          urls: urls,
          chapterOffset: chapters.length,
        );
        for (final page in pages) {
          chapters.addAll(page);
          emitPartial();
        }
      } else {
        var currentUrl = nexts.first;
        var hops = 1;
        final pending = <String>[];
        while (hops < maxPages) {
          hops++;
          final res = await _get(
            source,
            currentUrl,
            book: book,
            timeout: EngineLimits.tocTimeout,
          );
          final page = await _analyzeOneTocPage(
            source: source,
            book: book,
            toc: toc,
            listRule: listRule,
            currentUrl: res.url,
            currentBody: res.body ?? '',
            discoverNext: pending.isEmpty,
            chapterOffset: chapters.length,
          );
          chapters.addAll(page.chapters);
          emitPartial();
          if (pending.isEmpty && page.nextUrls.length > 1) {
            pending.addAll(
              page.nextUrls
                  .skip(1)
                  .where((url) => ContentHopPolicy.markSeen(seenPages, url)),
            );
          }
          String? next;
          final candidates = pending.isNotEmpty
              ? <String>[pending.removeAt(0)]
              : page.nextUrls;
          for (final candidate in candidates) {
            if (candidate.isEmpty ||
                !ContentHopPolicy.markSeen(seenPages, candidate)) {
              continue;
            }
            next = candidate;
            break;
          }
          if (next == null) break;
          currentUrl = next;
        }
      }
    }
    await _formatChapterTitles(source, book, chapters);
    return _indexChapters(
      book,
      ChapterListHygiene.sanitize(chapters),
      reverse: reverse,
    );
  }

  Future<List<List<BookChapter>>> _fetchTocPagesConcurrent({
    required BookSource source,
    required Book book,
    required TocRule toc,
    required String listRule,
    required List<String> urls,
    required int chapterOffset,
  }) async {
    final out = List<List<BookChapter>>.filled(urls.length, const []);
    var cursor = 0;
    final workers = EngineLimits.downloadPool.clamp(1, urls.length);
    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= urls.length) return;
        final res = await _get(
          source,
          urls[i],
          book: book,
          timeout: EngineLimits.tocTimeout,
        );
        final page = await _analyzeOneTocPage(
          source: source,
          book: book,
          toc: toc,
          listRule: listRule,
          currentUrl: res.url,
          currentBody: res.body ?? '',
          discoverNext: false,
          chapterOffset: chapterOffset,
        );
        out[i] = page.chapters;
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return out;
  }

  Future<({List<BookChapter> chapters, List<String> nextUrls})>
  _analyzeOneTocPage({
    required BookSource source,
    required Book book,
    required TocRule toc,
    required String listRule,
    required String currentUrl,
    required String currentBody,
    required bool discoverNext,
    required int chapterOffset,
    void Function(List<BookChapter> soFar)? onProgress,
  }) async {
    final rule =
        AnalyzeRule(source: source, jsRuntime: jsRuntime, javaHost: _javaHost)
          ..setBook(book)
          ..setContent(currentBody, currentUrl)
          ..setRedirectUrl(currentUrl);
    var items = listRule.isEmpty
        ? <Object>[]
        : await rule.getElements(listRule);
    if (items.isEmpty) {
      for (final fb in const [
        r'@css:#list dd a, #list a, .listmain a, .chapterlist a',
        'id.list@tag.dd@tag.a',
        'id.list@tag.dd',
        'id.list@tag.a',
        'class.listmain@tag.a',
        'class.list@tag.dd',
        'class.chapter@tag.a',
        'tag.dd@tag.a',
        'tag.dt@tag.a',
      ]) {
        final found = await rule.getElements(fb);
        if (found.length >= 3) {
          items = found;
          break;
        }
      }
    }
    final nextUrls = discoverNext && (toc.nextTocUrl ?? '').trim().isNotEmpty
        ? await rule.getStringList(toc.nextTocUrl, isUrl: true)
        : const <String>[];
    final hasName = (toc.chapterName ?? '').trim().isNotEmpty;
    final hasUrl = (toc.chapterUrl ?? '').trim().isNotEmpty;
    final hasVolume = (toc.isVolume ?? '').trim().isNotEmpty;
    final hasVip = (toc.isVip ?? '').trim().isNotEmpty;
    final hasPay = (toc.isPay ?? '').trim().isNotEmpty;
    final hasUpdate = (toc.updateTime ?? '').trim().isNotEmpty;
    final chapters = <BookChapter>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && i % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
        onProgress?.call(chapters);
      }
      try {
        rule
          ..setContent(items[i], currentUrl)
          ..setRedirectUrl(currentUrl);
        var title = hasName ? await rule.getString(toc.chapterName) : '';
        if (title.isEmpty) title = await rule.getString('tag.a@text');
        if (title.isEmpty) title = await rule.getString('text');
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title.isEmpty) continue;
        var url = hasUrl
            ? await rule.getString(toc.chapterUrl, isUrl: true)
            : '';
        if (url.isEmpty || url == currentUrl) {
          url = await rule.getString('tag.a@href', isUrl: true);
        }
        if (url.isEmpty || url == currentUrl) {
          url = await rule.getString('href', isUrl: true);
        }
        final volumeRaw = hasVolume ? await rule.getString(toc.isVolume) : '';
        final isVolume = _tocFlag(volumeRaw);
        // Legado keeps volume headings even without a link and falls back
        // to the current page for ordinary chapters with a missing href.
        if (url.isEmpty || url == currentUrl) {
          url = isVolume
              ? '$currentUrl#volume-${chapterOffset + chapters.length}'
              : currentUrl;
        }
        chapters.add(
          BookChapter(
            url: url,
            title: title,
            bookUrl: book.bookUrl,
            baseUrl: currentUrl,
            isVolume: isVolume,
            isVip: hasVip ? _tocFlag(await rule.getString(toc.isVip)) : false,
            isPay: hasPay ? _tocFlag(await rule.getString(toc.isPay)) : false,
            tag: hasUpdate ? await rule.getString(toc.updateTime) : '',
          ),
        );
      } catch (_) {}
    }
    return (chapters: chapters, nextUrls: nextUrls);
  }

  bool _tocFlag(String value) =>
      value.isNotEmpty && value != 'false' && value != '0';

  Future<List<String>> _fetchContentPagesConcurrent({
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    required List<String> urls,
    required String? nextChapterUrl,
    required ContentRule contentRule,
  }) async {
    final out = List<String?>.filled(urls.length, null);
    var cursor = 0;
    final workers = EngineLimits.downloadPool.clamp(1, urls.length);
    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= urls.length) return;
        final res = await _get(
          source,
          urls[i],
          book: book,
          chapter: chapter,
          jsStr: contentRule.webJs,
          sourceRegex: contentRule.sourceRegex,
          timeout: EngineLimits.contentTimeout,
        );
        final itemRule =
            AnalyzeRule(
                source: source,
                jsRuntime: jsRuntime,
                javaHost: _javaHost,
              )
              ..setBook(book)
              ..setChapter(chapter)
              ..setNextChapterUrl(nextChapterUrl)
              ..setContent(res.body ?? '', res.url)
              ..setRedirectUrl(res.url);
        var html = (contentRule.content ?? '').trim().isEmpty
            ? await _ruleFallbackContent(itemRule)
            : await itemRule.getString(contentRule.content);
        if (html.trim().isEmpty) html = await _ruleFallbackContent(itemRule);
        if (ContentHopPolicy.isNavigationOnly(html)) html = '';
        out[i] = html;
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return [
      for (final page in out)
        if (page != null && page.trim().isNotEmpty) page,
    ];
  }

  Future<String> _analyzeContent(
    BookSource source,
    Book book,
    BookChapter chapter,
    String baseUrl,
    String body,
    String? nextChapterUrl, {
    int maxHops = 32,
  }) async {
    final contentRule = source.getContentRule();
    final rule =
        AnalyzeRule(source: source, jsRuntime: jsRuntime, javaHost: _javaHost)
          ..setBook(book)
          ..setChapter(chapter)
          ..setNextChapterUrl(nextChapterUrl)
          ..setContent(body, baseUrl)
          ..setRedirectUrl(baseUrl);
    final contents = <String>[];
    final seen = <String>{ContentHopPolicy.canonicalPageUrl(baseUrl)};
    final pendingNext = <String>[];
    var currentUrl = baseUrl;
    var currentBody = body;
    var hops = 0;
    String? lastFingerprint;
    while (true) {
      hops++;
      final itemRule =
          AnalyzeRule(source: source, jsRuntime: jsRuntime, javaHost: _javaHost)
            ..setBook(book)
            ..setChapter(chapter)
            ..setNextChapterUrl(nextChapterUrl)
            ..setContent(currentBody, currentUrl)
            ..setRedirectUrl(currentUrl);
      var html = (contentRule.content ?? '').trim().isEmpty
          ? await _ruleFallbackContent(itemRule)
          : await itemRule.getString(contentRule.content);
      // A short chapter is still valid content (poems, notes, and final
      // chapters are often only a few characters). Only use a structural
      // fallback when the selector produced no text at all.
      if (html.trim().isEmpty) {
        html = await _ruleFallbackContent(itemRule);
      }
      if (ContentHopPolicy.isNavigationOnly(html)) {
        html = '';
      }
      if (ContentHopPolicy.isRepeatContent(html, lastFingerprint)) {
        break;
      }
      if (html.trim().isNotEmpty) {
        contents.add(html);
        lastFingerprint = ContentHopPolicy.contentFingerprint(html);
      }
      if ((contentRule.nextContentUrl ?? '').trim().isEmpty) break;
      if (maxHops > 0 && hops >= maxHops) {
        if (contents.isNotEmpty) break;
        throw DomainError(
          code: 'content_pagination_limit',
          stage: DomainErrorStage.content,
          message: '正文续页超过安全上限（$maxHops）',
          sourceId: source.bookSourceUrl,
          bookId: book.bookUrl,
          chapterId: chapter.url,
          recoverable: true,
          retryable: true,
          suggestedAction: '检查正文下一页规则或提高 maxHops',
        );
      }
      final nexts = pendingNext.isNotEmpty
          ? <String>[pendingNext.removeAt(0)]
          : await itemRule.getStringList(
              contentRule.nextContentUrl,
              isUrl: true,
            );
      if (nexts.isEmpty) break;
      if (hops == 1 && pendingNext.isEmpty && nexts.length > 1) {
        final budget = maxHops > 0
            ? (maxHops - 1).clamp(0, nexts.length)
            : nexts.length;
        final urls = ContentHopPolicy.acceptNextUrls(
          currentUrl: currentUrl,
          candidates: nexts,
          seen: seen,
          nextChapterUrl: nextChapterUrl,
          limit: budget,
        );
        if (urls.isNotEmpty) {
          contents.addAll(
            await _fetchContentPagesConcurrent(
              source: source,
              book: book,
              chapter: chapter,
              urls: urls,
              nextChapterUrl: nextChapterUrl,
              contentRule: contentRule,
            ),
          );
        }
        break;
      }
      final accepted = ContentHopPolicy.acceptNextUrls(
        currentUrl: currentUrl,
        candidates: nexts,
        seen: seen,
        nextChapterUrl: nextChapterUrl,
        limit: 1,
      );
      if (accepted.isEmpty) break;
      final next = accepted.first;
      if (pendingNext.isEmpty && nexts.length > 1) {
        pendingNext.addAll(nexts.skip(1));
      }
      try {
        final res = await _get(
          source,
          next,
          book: book,
          chapter: chapter,
          jsStr: contentRule.webJs,
          sourceRegex: contentRule.sourceRegex,
          timeout: EngineLimits.contentTimeout,
        );
        currentUrl = res.url;
        currentBody = res.body ?? '';
        ContentHopPolicy.markSeen(seen, res.url);
      } catch (e) {
        DebugLog.error(source.bookSourceUrl, '正文续页 $next', e);
        // A failed continuation request is still a content error. The hop
        // limit below is different: pages already extracted stay readable.
        throw DomainError.from(
          e,
          stage: DomainErrorStage.content,
          sourceId: source.bookSourceUrl,
          bookId: book.bookUrl,
          chapterId: chapter.url,
        );
      }
    }
    if ((contentRule.subContent ?? '').isNotEmpty) {
      var sub = await rule.getString(contentRule.subContent);
      if (sub.trim().startsWith('http')) {
        try {
          final subRes = await _get(
            source,
            sub,
            book: book,
            chapter: chapter,
            timeout: EngineLimits.contentTimeout,
          );
          sub = subRes.body ?? sub;
        } catch (_) {}
      }
      if (book.isAudio) {
        chapter.putVariable('lyric', sub);
      } else if (book.isVideo) {
        chapter.variable = '{"danmaku":${jsonEncodeSafe(sub)}}';
      } else if (sub.isNotEmpty) {
        contents.add(sub);
      }
    }
    var joined = contents.join('\n');
    if ((contentRule.replaceRegex ?? '').trim().isNotEmpty) {
      final replaceRule = AnalyzeRule(
        source: source,
        jsRuntime: jsRuntime,
        javaHost: _javaHost,
      )..setContent(joined, baseUrl);
      final raw = contentRule.replaceRegex!.trim();
      joined = await replaceRule.getString(
        raw.startsWith('##') ? raw : '##$raw',
        mContent: joined,
      );
    }
    if ((contentRule.title ?? '').trim().isNotEmpty) {
      final titleRule = AnalyzeRule(
        source: source,
        jsRuntime: jsRuntime,
        javaHost: _javaHost,
      )..setContent(currentBody, currentUrl);
      final title = await titleRule.getString(contentRule.title);
      if (title.trim().isNotEmpty) {
        final img = RegExp(
          r'''<img[^>]*src=["']([^"']+)["'][^>]*>''',
          caseSensitive: false,
        ).firstMatch(title);
        if (img != null) {
          chapter.imgUrl = getAbsoluteUrl(currentUrl, img.group(1)!);
          final textTitle = RegExp(r'>([^<]*)<').firstMatch(title)?.group(1);
          if (textTitle != null && textTitle.trim().isNotEmpty)
            chapter.title = textTitle.trim();
        } else {
          chapter.title = title.trim();
        }
      }
    }
    if (source.bookSourceType == BookSourceType.image ||
        source.bookSourceType == BookSourceType.audio ||
        source.bookSourceType == BookSourceType.video) {
      return joined;
    }
    var text = htmlFormat(joined, baseUrl: baseUrl);
    // A selector can match a site's title/menu shell instead of the chapter
    // body. Treat a navigation-only match as empty so it cannot be persisted
    // as a successful chapter. Mixed pages with real sentence punctuation are
    // kept, because legitimate chapters may include a short site header.
    if (ContentHopPolicy.isNavigationOnly(text)) text = '';
    if (text.trim().isEmpty) {
      final fb = _fallbackContent(body);
      if (fb.trim().isNotEmpty && !ContentHopPolicy.isNavigationOnly(fb)) {
        text = fb;
      }
    }
    if (text.trim().isEmpty) {
      // For file-like sources Legado returns the URL when no extraction rule
      // exists; ordinary text chapters are classified as empty instead.
      if ((contentRule.content ?? '').trim().isEmpty) return chapter.url;
      throw ContentEmptyException(
        chapter.title,
        url: baseUrl,
        sourceId: source.bookSourceUrl,
        bookId: book.bookUrl,
        chapterId: chapter.url,
      );
    }
    return text;
  }

  Future<String> _ruleFallbackContent(AnalyzeRule rule) async {
    for (final fb in const [
      'id.content@text',
      'id.chaptercontent@text',
      'id.booktxt@text',
      'id.BookText@text',
      'id.TextContent@text',
      'class.content@text',
      'class.showtxt@text',
      'class.read-content@text',
    ]) {
      final t = await rule.getString(fb);
      if (t.trim().isNotEmpty && !ContentHopPolicy.isNavigationOnly(t)) {
        return t;
      }
    }
    return '';
  }

  String _fallbackContent(String body) {
    final doc = html_parser.parse(body);
    for (final sel in const [
      '#content',
      '#chaptercontent',
      '#booktxt',
      '#BookText',
      '#TextContent',
      '.content',
      '.showtxt',
      '.read-content',
      'article',
    ]) {
      final el = doc.querySelector(sel);
      if (el == null) continue;
      el.querySelectorAll('script,style,ins,iframe').forEach((n) => n.remove());
      final t = htmlFormat(el.innerHtml);
      if (t.trim().isNotEmpty && !ContentHopPolicy.isNavigationOnly(t)) {
        return t;
      }
    }
    return '';
  }

  Future<void> _runPreUpdateJs(BookSource source, Book book) async {
    final js = source.getTocRule().preUpdateJs?.trim();
    if (js == null || js.isEmpty) return;
    try {
      final rule =
          AnalyzeRule(source: source, jsRuntime: jsRuntime, javaHost: _javaHost)
            ..setBook(book)
            ..setContent(book.infoHtml ?? book.tocHtml ?? '', book.bookUrl);
      _javaHost.analyzeRule = rule;
      await rule.evalJs(js, book.bookUrl);
    } catch (e) {
      DebugLog.error(source.bookSourceUrl, 'preUpdateJs', e);
    }
  }

  Future<void> _formatChapterTitles(
    BookSource source,
    Book book,
    List<BookChapter> chapters,
  ) async {
    final js = source.getTocRule().formatJs?.trim();
    if (js == null || js.isEmpty) return;
    final rule = AnalyzeRule(
      source: source,
      jsRuntime: jsRuntime,
      javaHost: _javaHost,
    )..setBook(book);
    for (var i = 0; i < chapters.length; i++) {
      if (i > 0 && i % 24 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final ch = chapters[i];
      try {
        final out = await rule.evalJs(
          js,
          ch.title,
          extra: {'index': i + 1, 'title': ch.title, 'chapter': ch},
        );
        final titled = out?.toString().trim() ?? '';
        if (titled.isNotEmpty) ch.title = titled;
      } catch (e) {
        DebugLog.error(source.bookSourceUrl, 'formatJs', e);
      }
    }
  }

  Future<String> _decodeCover(
    BookSource source,
    String cover, {
    Book? book,
  }) async {
    final js = source.coverDecodeJs?.trim();
    if (js == null || js.isEmpty || cover.isEmpty) return cover;
    try {
      final rule = AnalyzeRule(
        source: source,
        jsRuntime: jsRuntime,
        javaHost: _javaHost,
      )..setBook(book);
      final out = await rule.evalJs(js, cover, extra: {'src': cover});
      final next = out?.toString().trim() ?? '';
      if (next.startsWith('http://') || next.startsWith('https://')) {
        return next;
      }
    } catch (e) {
      DebugLog.error(source.bookSourceUrl, 'coverDecodeJs', e);
    }
    return cover;
  }
}

class SearchMerge {
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\u3000\s\-_:：，,。.!！?？]+'), '')
      // Keep identity folding in lockstep with the Flutter search layer.
      .replaceAll('臺', '台')
      .replaceAll('台灣', '台湾')
      .replaceAll('萬', '万')
      .replaceAll('繁體', '繁体')
      .replaceAll('後', '后')
      .replaceAll('與', '与')
      .replaceAll('國', '国')
      .replaceAll('學', '学')
      .replaceAll('說', '说')
      .replaceAll('傳', '传');

  static String identity(SearchBook b) =>
      '${_fold(b.name)}\u0000${_fold(b.author)}';

  static List<SearchBook> merge({
    required List<SearchBook> existing,
    required List<SearchBook> incoming,
    required String key,
  }) {
    final equal = <SearchBook>[];
    final contains = <SearchBook>[];
    final tags = <SearchBook>[];
    final other = <SearchBook>[];
    final index = <String, SearchBook>{};

    void mergeFields(SearchBook target, SearchBook incoming) {
      if (incoming.origin.trim().isNotEmpty) {
        target.addOrigin(incoming.origin, incoming.bookUrl);
      }
      if ((target.coverUrl ?? '').isEmpty &&
          (incoming.coverUrl ?? '').isNotEmpty) {
        target.coverUrl = incoming.coverUrl;
      }
      if ((target.intro ?? '').isEmpty && (incoming.intro ?? '').isNotEmpty) {
        target.intro = incoming.intro;
      }
      if ((target.kind ?? '').isEmpty && (incoming.kind ?? '').isNotEmpty) {
        target.kind = incoming.kind;
      }
      if ((target.latestChapterTitle ?? '').isEmpty &&
          (incoming.latestChapterTitle ?? '').isNotEmpty) {
        target.latestChapterTitle = incoming.latestChapterTitle;
      }
      if (target.tocUrl.isEmpty && incoming.tocUrl.isNotEmpty) {
        target.tocUrl = incoming.tocUrl;
      }
      if ((target.wordCount ?? '').isEmpty &&
          (incoming.wordCount ?? '').isNotEmpty) {
        target.wordCount = incoming.wordCount;
      }
      if ((target.variable ?? '').isEmpty &&
          (incoming.variable ?? '').isNotEmpty) {
        target.variable = incoming.variable;
      }
      if ((target.infoHtml ?? '').isEmpty &&
          (incoming.infoHtml ?? '').isNotEmpty) {
        target.infoHtml = incoming.infoHtml;
      }
      if ((target.tocHtml ?? '').isEmpty &&
          (incoming.tocHtml ?? '').isNotEmpty) {
        target.tocHtml = incoming.tocHtml;
      }
    }

    void bucket(SearchBook b) {
      final id = identity(b);
      final prior = index[id];
      // Existing input may already contain duplicate rows (for example when
      // a source emits the same JSON object twice).  BookList uses a linked
      // set, so collapse those rows before assigning a result bucket.
      if (prior != null) {
        mergeFields(prior, b);
        return;
      }
      index[id] = b;
      final nk = _fold(key);
      final nn = _fold(b.name);
      final na = _fold(b.author);
      if (nn == nk || na == nk) {
        equal.add(b);
      } else if (_fold(b.kind ?? '').contains(nk) && nk.isNotEmpty) {
        tags.add(b);
      } else if ((nk.isNotEmpty && (nn.contains(nk) || na.contains(nk))) ||
          b.name.contains(key) ||
          b.author.contains(key)) {
        contains.add(b);
      } else {
        other.add(b);
      }
    }

    for (final e in existing) {
      bucket(e);
    }
    for (final n in incoming) {
      final same = index[identity(n)];
      if (same != null) {
        mergeFields(same, n);
      } else {
        bucket(n);
      }
    }
    int rich(SearchBook b) {
      var s = b.origins.length * 2;
      if ((b.coverUrl ?? '').startsWith('http')) s += 8;
      if ((b.intro ?? '').trim().length > 8) s += 4;
      if ((b.kind ?? '').isNotEmpty) s += 1;
      if ((b.latestChapterTitle ?? '').isNotEmpty) s += 1;
      return s;
    }

    int byRich(SearchBook a, SearchBook b) => rich(b).compareTo(rich(a));
    equal.sort(byRich);
    tags.sort(byRich);
    contains.sort(byRich);
    other.sort(byRich);
    return [...equal, ...tags, ...contains, ...other];
  }
}

String jsonEncodeSafe(String s) {
  return '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
}
