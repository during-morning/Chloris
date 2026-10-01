import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/book_export.dart';
import '../../core/download/chapter_download_scheduler.dart';
import '../../core/http/http_session.dart';
import '../../app/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_icons.dart';
import '../../app/route_args.dart';
import '../../app/widgets/meow.dart';
import '../../app/widgets/follow_route.dart';
import '../../application/download/download_use_cases.dart';
import '../../services/share_service.dart';

import 'book_detail_provider.dart';
import '../library/online_shelf_provider.dart';
import '../library/reading_progress_provider.dart';
import 'package:go_router/go_router.dart';
import '../search/search_provider.dart';
import 'auto_source_switch.dart';
import 'cache_provider.dart';
import 'toc_page.dart';
import 'book_detail_header.dart';
import 'change_source_sheet.dart';
import 'chapter_content_screen.dart';
import '../settings/read_record_provider.dart';

export 'chapter_content_screen.dart';

part 'book_detail_actions.dart';
part 'book_detail_body.dart';
part 'book_detail_toc.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.source,
    required this.searchBook,
  });

  final BookSource source;
  final SearchBook searchBook;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _reversed = false;
  String _tocQuery = '';
  final _tocCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _tocAnchor = GlobalKey();
  late BookSource _source = widget.source;
  late SearchBook _searchBook = widget.searchBook;
  Timer? _prefetch;
  bool _autoSwitching = false;
  bool _autoSwitched = false;

  @override
  void didUpdateWidget(covariant BookDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.bookSourceUrl != widget.source.bookSourceUrl ||
        oldWidget.searchBook.bookUrl != widget.searchBook.bookUrl) {
      _source = widget.source;
      _searchBook = widget.searchBook;
    }
  }

  @override
  void dispose() {
    _prefetch?.cancel();
    _tocCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _invalidateDetail() {
    final args = BookDetailArgs(_source, _searchBook);
    ref.invalidate(bookInfoProvider(args));
    ref.invalidate(bookTocProvider(args));
    ref.invalidate(bookDetailProvider(args));
    ref.read(tocPartialProvider(args).notifier).state = const [];
  }

  void _jumpToChapterRow(int index, int total) {
    if (!_scroll.hasClients || total <= 0) return;
    var base = 0.0;
    final box = _tocAnchor.currentContext?.findRenderObject() as RenderBox?;
    final scrollBox =
        _scroll.position.context.notificationContext?.findRenderObject()
            as RenderBox?;
    if (box != null && scrollBox != null) {
      final origin = box.localToGlobal(Offset.zero);
      final scrollOrigin = scrollBox.localToGlobal(Offset.zero);
      base = origin.dy - scrollOrigin.dy + _scroll.offset;
    }
    final target = (base + index * AppTokens.tocItemExtent).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: AppTokens.durationMed,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final searchBook = _searchBook;
    final args = BookDetailArgs(source, searchBook);
    final cs = Theme.of(context).colorScheme;
    ref.listen<AsyncValue<List<BookChapter>>>(bookTocProvider(args), (
      prev,
      next,
    ) {
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      final info =
          ref.read(bookInfoProvider(args)).valueOrNull ?? searchBook.toBook();
      final prog = ref.read(readingProgressProvider)[info.bookUrl];
      var idx = prog?.chapterIndex ?? info.durChapterIndex;
      if (idx < 0 || idx >= list.length) idx = 0;
      _prefetch?.cancel();
      _prefetch = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        prefetchChapterContentFor(
          ref,
          source,
          info,
          list[idx],
          nextChapterUrl: idx + 1 < list.length ? list[idx + 1].url : null,
        );
      });
    });
    final infoAsync = ref.watch(bookInfoProvider(args));
    final tocAsync = ref.watch(bookTocProvider(args));
    final tocExtra = ref.watch(tocPartialProvider(args));
    // 自动换源：目录加载完成且为空（点开发现源空）时触发一次。
    // 用 microtask 避免在 build 期间发副作用。
    if (!_autoSwitching &&
        !_autoSwitched &&
        tocAsync.hasValue &&
        (tocAsync.valueOrNull ?? const <BookChapter>[]).isEmpty &&
        tocExtra.isEmpty) {
      _autoSwitching = true; // 先占位，真正的重置在 microtask 里
      Future<void>.microtask(() async {
        _autoSwitching = false;
        if (mounted) await _autoChangeSource();
      });
    }
    final book = infoAsync.valueOrNull ?? searchBook.toBook();
    final prog = ref.watch(readingProgressProvider)[book.bookUrl];
    if (prog != null && prog.chapterIndex >= 0) {
      book.durChapterIndex = prog.chapterIndex;
      if (prog.chapterTitle.isNotEmpty) {
        book.durChapterTitle = prog.chapterTitle;
      }
    }
    final loaded = tocAsync.valueOrNull ?? const <BookChapter>[];
    final allChapters = tocExtra.length > loaded.length ? tocExtra : loaded;
    final catalog = ref.read(loadOnlineCatalogUseCaseProvider);
    final cachedToc =
        catalog.peek(book.bookUrl) ?? catalog.peek(searchBook.bookUrl);
    final openChapters = allChapters.length >= 2
        ? allChapters
        : (cachedToc ?? const <BookChapter>[]);
    final canStart = openChapters.isNotEmpty;
    var chapters = List<BookChapter>.from(allChapters);
    if (_tocQuery.trim().isNotEmpty) {
      final q = _tocQuery.trim();
      chapters = chapters.where((c) => c.title.contains(q)).toList();
    }
    if (_reversed) chapters = chapters.reversed.toList();
    final jobs = ref
        .watch(cacheJobsProvider)
        .where((j) => j.bookName == book.name)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(searchBook.name),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.upload),
            onPressed: () async {
              await const ShareService().shareText(
                searchBook.name + '\n' + searchBook.bookUrl,
              );
            },
          ),
        ],
      ),
      body: _detailBody(
        context: context,
        source: source,
        searchBook: searchBook,
        book: book,
        args: args,
        cs: cs,
        infoAsync: infoAsync,
        tocAsync: tocAsync,
        allChapters: allChapters,
        openChapters: openChapters,
        chapters: chapters,
        jobs: jobs,
        canStart: canStart,
      ),
    );
  }
}
