import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/theme_provider.dart';
import '../../core/read/chapter_pipeline.dart';
import '../book_detail/chapter_toc_panel.dart';
import '../rules/dict_rules_controller.dart';
import '../rules/replace_rules_controller.dart';
import 'bookmark_provider.dart';
import 'measured_paginator.dart';
import 'read_pager.dart';
import 'reader_controller.dart';
import 'reader_layout_cache.dart';
import 'reader_keys.dart';
import 'reader_settings_provider.dart';
import '../../app/theme/app_icons.dart';
import '../../app/route_args.dart';
import '../../features/library/online_shelf_provider.dart';
import 'package:go_router/go_router.dart';
import '../book_detail/book_detail_provider.dart';
import 'reading_settings_sheet.dart';
import 'tts_service.dart';

part 'reader_stack.dart';
part 'reader_chrome_layer.dart';
part 'reader_actions.dart';
part 'reader_layout.dart';

/// Meow/legado 阅读操作：全屏、点中央显隐菜单、左右翻页、目录、主题、进度。
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.content,
    required this.chapterTitle,
    this.bookTitle,
    this.bookAuthor = '',
    this.pageAnimOverride,
    this.onNextChapter,
    this.onPrevChapter,
    this.hasNext = false,
    this.hasPrev = false,
    this.chapters = const [],
    this.chapterIndex = 0,
    this.initialPage = 0,
    this.openAtEnd = false,
    this.bookUrl,
    this.onOpenChapter,
    this.onPageChanged,
    this.onReloadChapter,
  });

  final String content;
  final String chapterTitle;
  final String? bookTitle;
  final String bookAuthor;
  final int? pageAnimOverride;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPrevChapter;
  final bool hasNext;
  final bool hasPrev;
  final List<BookChapter> chapters;
  final int chapterIndex;
  final int initialPage;
  final bool openAtEnd;
  final String? bookUrl;
  final ValueChanged<int>? onOpenChapter;
  final ValueChanged<int>? onPageChanged;
  final Future<void> Function()? onReloadChapter;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  final ReadPagerController _pager = ReadPagerController();
  late int _page = widget.initialPage;
  bool _pendingEnd = false;
  bool _menu = true;
  bool _toc = false;
  bool _switchingChapter = false;
  Timer? _auto;
  Timer? _hideMenu;
  Timer? _chapterSwitchReset;
  double _edgePull = 0;
  String _paginatedContent = '';
  PaginatedChapter? _measured;
  final ReaderLayoutCache<PaginatedChapter> _layoutCache =
      ReaderLayoutCache<PaginatedChapter>();
  Size? _lastSize;
  TextStyle? _lastStyle;
  double _lastPad = 0;
  TextScaler? _lastTextScaler;
  bool? _lastDoublePage;
  String _plain = '';
  Object? _pipeKey;
  int _pipeToken = 0;
  int _screenPrefsToken = 0;
  DateTime _lastScrollUi = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<double> _scrollProgressUi = ValueNotifier(0);
  bool _layoutFull = false;
  // 增量分页：预览段已消费到的字符位置（0 = 无待续排）；_appended 防重复续排。
  int _previewConsumed = 0;
  bool _appended = false;
  final FocusNode _keys = FocusNode(debugLabel: 'readerKeys');
  // 阅读中正文为空时自动换源：每会话只触发一次，防循环。
  bool _autoSourceSwitching = false;
  bool _autoSourceSwitched = false;

  @override
  void initState() {
    super.initState();
    // 常亮/方向锁定在首帧后应用（SystemChrome 与插件调用不宜在 build 期）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyScreenPrefs(ref.read(readerSettingsProvider));
    });
  }

  /// 屏幕常亮 + 方向锁定（对齐 legado keepScreenOn / screenOrientation）。
  void _applyScreenPrefs(ReaderSettings s) {
    final token = ++_screenPrefsToken;
    final orientations = switch (s.orientation) {
      'portrait' => const [DeviceOrientation.portraitUp],
      'landscape' => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      _ => const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    };
    // All calls are serialized through one async task. This prevents a fast
    // settings change (or a route pop during rotation) from letting a stale
    // platform-channel reply restore the old reader state.
    unawaited(_applyScreenPrefsAsync(token, orientations, s.keepScreenOn));
  }

  Future<void> _applyScreenPrefsAsync(
    int token,
    List<DeviceOrientation> orientations,
    bool keepScreenOn,
  ) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await WakelockPlus.toggle(enable: keepScreenOn);
    } catch (_) {
      // Desktop, web and test hosts may not implement every system channel.
      // Reader content remains usable when a platform preference is ignored.
    }
    if (!mounted || token != _screenPrefsToken) return;
  }

  @override
  void dispose() {
    ++_screenPrefsToken;
    _auto?.cancel();
    _hideMenu?.cancel();
    _chapterSwitchReset?.cancel();
    _keys.dispose();
    _scroll.dispose();
    _scrollProgressUi.dispose();
    // 离开阅读器恢复全局默认：不常亮、跟随系统方向。
    unawaited(() async {
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await WakelockPlus.toggle(enable: false);
      } catch (_) {
        // Ignore unsupported platform channels while leaving the reader.
      }
    }());
    super.dispose();
  }

  void _toggleAuto() {
    if (_auto != null) {
      _auto!.cancel();
      _auto = null;
      setState(() {});
      return;
    }
    final sec = ref.read(readerSettingsProvider).autoSeconds.clamp(3, 30);
    _auto = Timer.periodic(Duration(seconds: sec), (_) {
      if (!mounted) return;
      _next(9999);
    });
    setState(() {});
  }

  int get _pageAnim {
    if (ref.read(reduceMotionProvider)) return PageAnim.noAnim;
    return PageAnim.normalize(
      widget.pageAnimOverride ?? ref.read(readerSettingsProvider).pageAnim,
    );
  }

  ReadPagerStyle get _pagerStyle {
    final a = _pageAnim;
    if (a == PageAnim.noAnim) return ReadPagerStyle.none;
    if (a == PageAnim.cover) return ReadPagerStyle.cover;
    return ReadPagerStyle.slide;
  }

  void _toggleMenu() {
    if (_pageAnim == PageAnim.scroll) {
      _scrollProgressUi.value = _progress;
    }
    setState(() {
      _menu = !_menu;
      if (!_menu) _toc = false;
      _measured = null;
    });
    _hideMenu?.cancel();
    if (_menu && ref.read(readerSettingsProvider).autoHideMenu) {
      _hideMenu = Timer(const Duration(seconds: 4), () {
        if (!mounted || _toc) return;
        setState(() => _menu = false);
      });
    }
  }

  void _openToc() {
    _hideMenu?.cancel();
    setState(() {
      _toc = !_toc;
      if (_toc) _menu = true;
    });
  }

  void _prev(int total) {
    if (_pageAnim == PageAnim.scroll) {
      if (_scroll.hasClients && _scroll.offset > 8) {
        final h = MediaQuery.sizeOf(context).height * 0.9;
        _scroll.animateTo(
          (_scroll.offset - h).clamp(0, _scroll.position.maxScrollExtent),
          duration: AppTokens.durationMed,
          curve: Curves.easeOut,
        );
      } else if (widget.hasPrev) {
        widget.onPrevChapter?.call();
      }
      return;
    }
    _pager.prev();
  }

  void _next(int total) {
    if (_switchingChapter) return;
    if (_pageAnim == PageAnim.scroll) {
      if (_scroll.hasClients &&
          _scroll.offset < _scroll.position.maxScrollExtent - 8) {
        final h = MediaQuery.sizeOf(context).height * 0.9;
        _scroll.animateTo(
          (_scroll.offset + h).clamp(0, _scroll.position.maxScrollExtent),
          duration: AppTokens.durationMed,
          curve: Curves.easeOut,
        );
      } else if (widget.hasNext) {
        _requestChapter(widget.onNextChapter);
      }
      return;
    }
    _pager.next();
  }

  void _onTapAt(Offset local, Size size, int total) {
    if (!_keys.hasFocus) _keys.requestFocus();
    final x = local.dx;
    final y = local.dy;
    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    if (!_menu && (y < h * 0.14 || y > h * 0.86)) {
      _toggleMenu();
      return;
    }
    final settings = ref.read(readerSettingsProvider);
    final ratio = settings.clickLeftRatio.clamp(0.25, 0.4);
    final left = w * ratio;
    final right = w * (1 - ratio);
    final rev = settings.clickReverse;
    if (x < left) {
      rev ? _next(total) : _prev(total);
    } else if (x > right) {
      rev ? _prev(total) : _next(total);
    } else {
      _toggleMenu();
    }
  }

  bool _doublePageActive(Size size, ReaderSettings settings) {
    return doublePageModeById(
      settings.doublePage,
    ).activeFor(size.width, scroll: _pageAnim == PageAnim.scroll);
  }

  void _goChapter(int dir) {
    if (dir < 0 && widget.hasPrev) {
      _requestChapter(widget.onPrevChapter);
    } else if (dir > 0 && widget.hasNext) {
      _requestChapter(widget.onNextChapter);
    }
  }

  /// Guard every chapter callback, including auto page and edge pull. A
  /// network backed route can take longer than one animation; a short fixed
  /// delay used to allow duplicate callbacks before didUpdateWidget arrived.
  void _requestChapter(VoidCallback? callback) {
    if (callback == null || _switchingChapter) return;
    _switchingChapter = true;
    _chapterSwitchReset?.cancel();
    callback();
    _chapterSwitchReset = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _switchingChapter = false;
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final action = readerKeyAction(event.logicalKey);
    if (action == null) return KeyEventResult.ignored;
    final total = 1;
    switch (action) {
      case ReaderKeyAction.prevPage:
        _prev(total);
      case ReaderKeyAction.nextPage:
        _next(total);
      case ReaderKeyAction.prevChapter:
        _goChapter(-1);
      case ReaderKeyAction.nextChapter:
        _goChapter(1);
      case ReaderKeyAction.toggleMenu:
        _toggleMenu();
    }
    return KeyEventResult.handled;
  }

  /// 正文为空：经书架反查当前源/搜索书，调用自动换源编排；每会话仅一次。
  void _maybeAutoSwitchForEmptyChapter() {
    if (_autoSourceSwitching || _autoSourceSwitched) return;
    if (widget.bookUrl == null) return;
    _autoSourceSwitching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoSourceSwitch());
  }

  Future<void> _runAutoSourceSwitch() async {
    if (!mounted) {
      _resetAutoSwitchFlags();
      return;
    }
    final bookUrl = widget.bookUrl!;
    // 本地书 / 未入架：不参与自动换源（换源函数本身也需要在线源）。
    final item = ref
        .read(onlineShelfProvider)
        .cast<OnlineShelfItem?>()
        .firstWhere(
          (e) => e?.searchBook.bookUrl == bookUrl,
          orElse: () => null,
        );
    if (item == null) {
      _autoSourceSwitched = true;
      return;
    }
    if (!mounted) {
      _resetAutoSwitchFlags();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('本章内容为空，正在寻找其它源…')));
    final emptyChapter =
        (widget.chapterIndex >= 0 &&
            widget.chapterIndex < widget.chapters.length)
        ? widget.chapters[widget.chapterIndex]
        : BookChapter(url: '', title: widget.chapterTitle);
    AutoSwitchResult? result;
    try {
      result = await autoSwitchSourceForEmptyChapter(
        ref,
        bookName: widget.bookTitle ?? '',
        bookAuthor: widget.bookAuthor,
        currentSource: item.source,
        currentBook: item.searchBook.toBook(),
        seedBook: item.searchBook,
        currentChapters: widget.chapters,
        emptyChapter: emptyChapter,
        isCancelled: () => !mounted,
      );
    } catch (_) {
      result = null;
    }
    if (!mounted) {
      _resetAutoSwitchFlags();
      return;
    }
    if (result == null || result.chapters.isEmpty) {
      // 无可用候选 / 换源后仍取不到目录：明确提示，不静默。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有找到可用的其它源')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已自动换源 → ${result.source.bookSourceName}')),
      );
      if (mounted) {
        // 用新源 + 对齐章节重载阅读路由（最小侵入：重载路由参数）。
        context.pushReplacement(
          '/reader',
          extra: ChapterRouteArgs(
            source: result.source,
            book: result.book,
            chapter: result.chapters[result.alignedChapterIndex],
            chapters: result.chapters,
            searchBook: result.searchBook,
          ),
        );
      }
    }
    _resetAutoSwitchFlags();
  }

  void _resetAutoSwitchFlags() {
    _autoSourceSwitching = false;
    _autoSourceSwitched = true;
  }

  double get _progress {
    if (_pageAnim == PageAnim.scroll) {
      if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) {
        return 0;
      }
      return (_scroll.offset / _scroll.position.maxScrollExtent).clamp(
        0.0,
        1.0,
      );
    }
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.read(replaceRulesProvider.notifier).load();
    ref.read(dictRulesController.notifier).load();
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content ||
        old.chapterIndex != widget.chapterIndex) {
      _page = widget.initialPage;
      _measured = null;
      _paginatedContent = '';
      _layoutFull = false;
      _lastDoublePage = null;
      _switchingChapter = false;
      _chapterSwitchReset?.cancel();
      _pendingEnd = widget.openAtEnd;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        if (_pendingEnd) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          _pendingEnd = false;
        } else {
          _scroll.jumpTo(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    // 常亮/方向设置变更即时生效。
    ref.listen<ReaderSettings>(readerSettingsProvider, (prev, next) {
      if (prev?.keepScreenOn != next.keepScreenOn ||
          prev?.orientation != next.orientation) {
        _applyScreenPrefs(next);
      }
    });
    ref.watch(replaceRulesProvider);
    final cs = Theme.of(context).colorScheme;
    final pal = settings.palette;
    final family = AppThemeFamily.byId(ref.watch(themeFamilyIdProvider));
    final uiStyle = ref.watch(uiStyleProvider);
    final eink = uiStyle == AppUiStyle.classic && ref.watch(einkThemeProvider);
    var bg = pal.bgColor(
      cs,
      overrideBg: settings.background,
      family: family,
      eink: eink,
    );
    var fg = pal.fgColor(
      cs,
      overrideFg: settings.foreground,
      family: family,
      eink: eink,
    );
    if (MediaQuery.highContrastOf(context)) {
      final lightPaper = bg.computeLuminance() > 0.45;
      bg = lightPaper ? const Color(0xFFFFFFF2) : const Color(0xFF000000);
      fg = lightPaper ? const Color(0xFF000000) : const Color(0xFFFFFFF2);
    }
    final isScroll = _pageAnim == PageAnim.scroll;
    final body = _ensurePlain(settings);
    // 正文为空（trim 后无内容）：触发一次自动换源。'加载中…' 是占位，不触发。
    if (body.trim().isEmpty && widget.content != '加载中…') {
      _maybeAutoSwitchForEmptyChapter();
    }
    final heading = _chapterHeading();
    // An explicit reader font always wins. Otherwise Absolutely reads as a book
    // (serif) and terminal reads as a console (monospace), which is the whole
    // point of those styles.
    final pickedFont = settings.fontFamily.isNotEmpty;
    final readerFamily = pickedFont
        ? settings.fontFamily
        : Theme.of(context).extension<AppStyleExtension>()?.readerFamily;
    final fallback = pickedFont
        ? const <String>[AppTheme.cjkSansFallback]
        : AppTheme.readerFallbackFor(uiStyle);
    final style = TextStyle(
      color: fg,
      fontFamily: readerFamily,
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      fontSize: settings.fontSize.toDouble(),
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
    );

    return Scaffold(
      backgroundColor: bg,
      body: ColoredBox(
        // Keep an explicit opaque paper layer behind scroll/platform views.
        // Scaffold background alone can be skipped by macOS compositor
        // snapshots after a modal route is dismissed.
        color: bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final paginated = isScroll
                ? PaginatedChapter(
                    content: body,
                    pages: const [],
                    totalChars: body.length,
                  )
                : _measure(
                    body,
                    size,
                    settings,
                    style,
                    MediaQuery.textScalerOf(context),
                    doublePage: _doublePageActive(size, settings),
                  );
            final total = (isScroll ? 1 : paginated.total).clamp(1, 99999);
            if (!isScroll && _page >= total) _page = total - 1;
            final bookPct = widget.chapters.isEmpty
                ? 0
                : (((widget.chapterIndex +
                                  (isScroll
                                      ? _progress
                                      : ((_page + 1) / total))) /
                              widget.chapters.length) *
                          100)
                      .clamp(0, 100)
                      .round();
            final pct = isScroll
                ? (_progress * 100).round()
                : (((_page + 1) / total) * 100).round();

            return Focus(
              focusNode: _keys,
              autofocus: true,
              onKeyEvent: _onKeyEvent,
              child: _readerStack(
                isScroll: isScroll,
                settings: settings,
                heading: heading,
                body: body,
                style: style,
                bg: bg,
                fg: fg,
                paginated: paginated,
                total: total,
                pct: pct,
                bookPct: bookPct,
                textScaler: MediaQuery.textScalerOf(context),
                viewport: size,
                scrollProgress: _scrollProgressUi,
              ),
            );
          },
        ),
      ),
    );
  }
}
