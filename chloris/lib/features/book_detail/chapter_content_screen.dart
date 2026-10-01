import '../media/music_chapter_view.dart';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../library/reading_progress_provider.dart';
import '../media/media_player_screen.dart';
import '../media/media_resource.dart';
import '../reader/comic_reader.dart';
import '../reader/reader_screen.dart';
import 'book_detail_provider.dart';

final _chapterMediaProvider = FutureProvider.autoDispose
    .family<MediaResource?, (BookSource, Book, BookChapter, String)>((
      ref,
      args,
    ) async {
      final (source, book, chapter, content) = args;
      // A refreshed TOC can replace the chapter instance while the content
      // provider retains its URL identity. Hydrate media metadata onto this
      // exact chapter instance as well as onto a prefetched instance.
      await ref.read(loadOnlineChapterContentUseCaseProvider)(
        source: source,
        book: book,
        chapter: chapter,
      );
      final base = chapter.baseUrl.isEmpty ? chapter.url : chapter.baseUrl;
      var headers = const <String, String>{};
      try {
        final saved = jsonDecode(chapter.getVariable('_mediaHeaders'));
        if (saved is Map)
          headers = saved.map<String, String>(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
      } catch (_) {}
      final media = parseMediaResource(
        headers.isEmpty ? content : (chapter.resourceUrl ?? content),
        baseUrl: base,
        resourceUrl: chapter.resourceUrl,
        headers: headers,
      );
      if (media == null) return null;
      final prepared = await ref.read(sourceMediaRequestProvider)(
        media.ruleUrl ?? media.url,
        source: source,
        book: book,
        chapter: chapter,
        headers: media.headers,
      );
      final resolver = MediaResourceResolver(http: ref.read(httpPortProvider));
      final resource = await resolver.resolveResource(
        media.copyWith(url: prepared.url, headers: prepared.headers),
      );
      final playbackRequest = resource.url == prepared.url
          ? prepared
          : await ref.read(sourceMediaRequestProvider)(
              resource.ruleUrl ?? resource.url,
              source: source,
              book: book,
              chapter: chapter,
              headers: resource.headers,
            );
      final resolved = MediaResource(
        url: playbackRequest.url,
        headers: playbackRequest.headers,
        title: chapter.title,
        artist: book.author,
        coverUrl: book.coverUrl,
        lyric: chapter.getVariable('lyric').isEmpty
            ? resource.lyric
            : chapter.getVariable('lyric'),
        lyricUrl: resource.lyricUrl,
      );
      return resolved;
    });

String _contentLoadError(Object e) {
  if (e is DomainError) {
    final action = e.suggestedAction;
    return action == null || action.isEmpty
        ? e.message
        : '${e.message}。$action。';
  }
  final raw = e.toString();
  if (raw.contains('TimeoutException') ||
      raw.toLowerCase().contains('timeout')) {
    return '站点响应较慢，已超时。可点重试，或换一个书源。';
  }
  return raw.split('\n').first;
}

class ChapterContentScreen extends ConsumerStatefulWidget {
  const ChapterContentScreen({
    super.key,
    required this.source,
    required this.book,
    required this.chapter,
    this.chapters = const [],
    this.searchBook,
  });

  final BookSource source;
  final Book book;
  final BookChapter chapter;
  final List<BookChapter> chapters;
  final SearchBook? searchBook;

  @override
  ConsumerState<ChapterContentScreen> createState() =>
      _ChapterContentScreenState();
}

class _ChapterContentScreenState extends ConsumerState<ChapterContentScreen> {
  late BookChapter chapter = widget.chapter;
  late Book book = widget.book;
  late List<BookChapter> chapters = List<BookChapter>.from(widget.chapters);
  bool openAtEnd = false;
  late bool _tocLoading = chapters.isEmpty;
  String? _shownText;
  late BookSource source = widget.source;
  bool _autoSwitching = false;
  bool _autoSwitched = false;

  @override
  void initState() {
    super.initState();
    if (chapters.isEmpty) {
      Future<void>.microtask(_refreshToc);
    }
  }

  Future<void> _refreshToc() async {
    try {
      final (info, list) = await refreshOnlineToc(
        ref,
        source: source,
        book: book,
      );
      if (!mounted || list.isEmpty) return;
      final prevUrl = chapter.url;
      var idx = list.indexWhere((c) => c.url == prevUrl);
      if (idx < 0) idx = 0;
      setState(() {
        book = info;
        chapters = list;
        chapter = list[idx];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _tocLoading = false);
    }
  }

  void go(int j) {
    if (j < 0 || j >= chapters.length) return;
    final from = chapters.indexWhere((c) => c.url == chapter.url);
    ref
        .read(readingProgressProvider.notifier)
        .save(
          bookUrl: book.bookUrl,
          chapterIndex: j,
          chapterTitle: chapters[j].title,
        );
    setState(() {
      openAtEnd = from >= 0 && j < from;
      _shownText = null;
      chapter = chapters[j];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tocLoading && chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(chapter.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final idx = chapters.indexWhere((c) => c.url == chapter.url);
    final nextChapterUrl = idx >= 0 && idx + 1 < chapters.length
        ? chapters[idx + 1].url
        : null;
    final contentArgs = ChapterContentArgs(
      source,
      book,
      chapter,
      nextChapterUrl: nextChapterUrl,
    );
    final future = ref.watch(chapterContentProvider(contentArgs));
    final pending = future.asData?.value;
    if (pending != null) _shownText = pending;

    if (future.isLoading && _shownText == null) {
      return Scaffold(
        appBar: AppBar(title: Text(chapter.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return future.when(
      loading: () => _readerFor(_shownText ?? '加载中…', idx, contentArgs),
      error: (e, _) {
        // 正文为空（源失效的典型表现）→ 自动换源一次；其它错误不触发。
        if (e is DomainError &&
            e.code == 'content_empty' &&
            !_autoSwitching &&
            !_autoSwitched) {
          _autoSwitching = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoChangeSourceForEmpty();
          });
        }
        return Scaffold(
          appBar: AppBar(title: Text(chapter.title)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text(
                  '正文加载失败：${_contentLoadError(e)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(chapterContentProvider(contentArgs)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        );
      },
      data: (text) => _readerFor(text, idx, contentArgs),
    );
  }

  SearchBook _seedForSwitch() {
    final s = widget.searchBook;
    if (s != null) return s;
    return SearchBook(
      bookUrl: book.bookUrl,
      origin: book.origin.isEmpty ? source.bookSourceUrl : book.origin,
      originName: book.originName.isEmpty
          ? source.bookSourceName
          : book.originName,
      name: book.name,
      author: book.author,
      coverUrl: book.coverUrl,
      intro: book.intro,
      latestChapterTitle: book.latestChapterTitle,
    );
  }

  /// 阅读中正文为空 → 自动换源：标题精确匹配对齐进度，失败明确提示。
  Future<void> _autoChangeSourceForEmpty() async {
    final emptyChapter = chapter;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('本章内容为空，正在寻找其它源…'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      final r = await autoSwitchSourceForEmptyChapter(
        ref,
        bookName: book.name,
        bookAuthor: book.author,
        currentSource: source,
        currentBook: book,
        seedBook: _seedForSwitch(),
        currentChapters: chapters,
        emptyChapter: emptyChapter,
        isCancelled: () => !mounted,
      );
      if (!mounted) return;
      if (r == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有找到可用的其它源，可稍后手动换源')));
        return;
      }
      final nextIdx = r.alignedChapterIndex.clamp(0, r.chapters.length - 1);
      final next = r.chapters.isEmpty ? emptyChapter : r.chapters[nextIdx];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已自动换源 → ${r.source.bookSourceName}')),
      );
      setState(() {
        source = r.source;
        book = r.book;
        chapters = r.chapters;
        chapter = next;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('自动换源失败，可稍后手动换源')));
      }
    } finally {
      _autoSwitching = false;
      _autoSwitched = true;
    }
  }

  Widget _readerFor(String text, int idx, ChapterContentArgs contentArgs) {
    if (idx >= 0 && idx < chapters.length - 1) {
      prefetchChapterContentFor(
        ref,
        source,
        book,
        chapters[idx + 1],
        nextChapterUrl: idx + 2 < chapters.length
            ? chapters[idx + 2].url
            : null,
      );
    }
    if(book.isAudio) return Scaffold(appBar:AppBar(title:Text(chapter.title)),
      body:MusicChapterView(source:source,book:book,chapter:chapter,chapters:chapters,content:text));
    if (book.isVideo) {
      final media = ref.watch(
        _chapterMediaProvider((source, book, chapter, text)),
      );
      return Scaffold(
        appBar: AppBar(title: Text(chapter.title)),
        body: media.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('音频解析失败：${_contentLoadError(error)}')),
          data: (resource) => resource == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('没有解析到可播放的媒体地址'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(chapterContentProvider(contentArgs)),
                        child: const Text('重新解析'),
                      ),
                    ],
                  ),
                )
              : MediaPlayerView(
                  url: resource.url,
                  headers: resource.headers,
                  lyric: resource.lyric ?? '',
                  artist: resource.artist ?? '',
                  coverUrl: resource.coverUrl,
                  title: chapter.title,
                  isVideo: book.isVideo,
                  hasPrev: idx > 0,
                  hasNext: idx >= 0 && idx < chapters.length - 1,
                  onPrev: () {
                    if (mounted) go(idx - 1);
                  },
                  onNext: () {
                    if (mounted) go(idx + 1);
                  },
                ),
        ),
      );
    }
    if (isMangaContent(text)) {
      return ComicReader(
        content: text,
        chapterTitle: chapter.title,
        source: source,
        book: book,
        hasPrev: idx > 0,
        hasNext: idx >= 0 && idx < chapters.length - 1,
        onPrev: () => go(idx - 1),
        onNext: () => go(idx + 1),
      );
    }
    final prog = ref.read(readingProgressProvider)[book.bookUrl];
    final sameChapter =
        prog != null && prog.chapterIndex == (idx < 0 ? 0 : idx);
    return ReaderScreen(
      key: ValueKey(book.bookUrl),
      content: text,
      chapterTitle: chapter.title,
      bookTitle: book.name,
      bookAuthor: book.author,
      bookUrl: book.bookUrl,
      initialPage: sameChapter ? prog.chapterPos : 0,
      openAtEnd: openAtEnd,
      hasNext: idx >= 0 && idx < chapters.length - 1,
      hasPrev: idx > 0,
      onNextChapter: () => go(idx + 1),
      onPrevChapter: () => go(idx - 1),
      chapters: chapters,
      chapterIndex: idx < 0 ? 0 : idx,
      onOpenChapter: go,
      onReloadChapter: () async {
        await ref
            .read(loadOnlineChapterContentUseCaseProvider)
            .invalidate(source, chapter);
        ref.invalidate(chapterContentProvider(contentArgs));
      },
      onPageChanged: (p) => ref
          .read(readingProgressProvider.notifier)
          .save(
            bookUrl: book.bookUrl,
            chapterIndex: idx < 0 ? 0 : idx,
            chapterTitle: chapter.title,
            chapterPos: p,
          ),
    );
  }
}
