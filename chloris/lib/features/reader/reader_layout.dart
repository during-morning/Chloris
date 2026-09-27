part of 'reader_screen.dart';

extension _ReaderLayout on _ReaderScreenState {
  String _ensurePlain(ReaderSettings settings) {
    final rules = settings.enableReplace
        ? ref.read(replaceRulesProvider)
        : const <ReplaceRule>[];
    final key = (
      widget.content,
      widget.chapterTitle,
      widget.bookTitle,
      widget.bookAuthor,
      settings.enableReplace,
      settings.chineseConvert,
      rules.length,
    );
    if (_pipeKey == key && _plain.isNotEmpty) return _plain;
    _pipeKey = key;
    final preview = widget.content.length > ChapterPipeline.offMainChars;
    _plain = ChapterPipeline.run(
      content: preview
          ? widget.content.substring(0, ChapterPipeline.offMainChars)
          : widget.content,
      bookTitle: widget.bookTitle ?? '',
      bookAuthor: widget.bookAuthor,
      chapterTitle: widget.chapterTitle,
      enableReplace: settings.enableReplace,
      replaceRules: rules,
      chineseConvert: settings.chineseConvert,
    );
    if (preview) _kickFullPipeline(key, settings, rules);
    return _plain;
  }

  void _kickFullPipeline(
    Object key,
    ReaderSettings settings,
    List<ReplaceRule> rules,
  ) {
    final token = ++_pipeToken;
    ChapterPipeline.runOffMain(
      content: widget.content,
      bookTitle: widget.bookTitle ?? '',
      bookAuthor: widget.bookAuthor,
      chapterTitle: widget.chapterTitle,
      enableReplace: settings.enableReplace,
      replaceRules: rules,
      chineseConvert: settings.chineseConvert,
      paragraphIndent: settings.paragraphIndent,
    ).then((text) {
      if (!mounted || token != _pipeToken || _pipeKey != key) return;
      if (text == _plain) return;
      setState(() {
        _plain = text;
        _paginatedContent = '';
        _layoutFull = false;
        _previewConsumed = 0;
        _appended = false;
      });
    });
  }

  String _chapterHeading() {
    final t = widget.chapterTitle.trim();
    if (t.isEmpty) return '';
    return t;
  }

  PaginatedChapter _measure(
    String body,
    Size size,
    ReaderSettings settings,
    TextStyle style,
    TextScaler textScaler, {
    bool doublePage = false,
  }) {
    final pad = settings.pagePadding.toDouble();
    final mq = MediaQuery.of(context);
    final topInset = readerVerticalInset(
      menuVisible: _menu,
      pagePadding: pad,
      safePadding: mq.viewPadding.top,
      top: true,
    );
    final bottomInset = readerVerticalInset(
      menuVisible: _menu,
      pagePadding: pad,
      safePadding: mq.viewPadding.bottom,
      top: false,
    );
    final readW = readerColumnWidth(
      viewportWidth: size.width,
      pagePadding: pad,
      doublePage: doublePage,
      maxSingle: AppTokens.maxReadWidth,
    );
    final headingH = _chapterHeading().isEmpty
        ? 0.0
        : (settings.fontSize * 1.28 * 1.3 + 28);
    final restH = (size.height - topInset - bottomInset).clamp(120.0, 4000.0);
    final firstH = headingH <= 0
        ? restH
        : (restH - headingH).clamp(80.0, restH);
    final readH = restH;
    final layoutKey = ReaderLayoutKey(
      contentHash: Object.hashAll([body]),
      chapterTitle: widget.chapterTitle,
      bookTitle: widget.bookTitle ?? '',
      bookAuthor: widget.bookAuthor,
      replaceFingerprint: Object.hashAll(
        ref
            .read(replaceRulesProvider)
            .map(
              (rule) => Object.hashAll(
                rule.toJson().entries.map((e) => Object.hash(e.key, e.value)),
              ),
            ),
      ),
      enableReplace: settings.enableReplace,
      chineseConvert: settings.chineseConvert,
      paragraphIndent: settings.paragraphIndent,
      viewportWidth: readW.round(),
      viewportHeight: readH.round(),
      pagePadding: pad.round(),
      fontSize: (style.fontSize ?? 0).round(),
      lineHeight: ((style.height ?? 0) * 1000).round(),
      letterSpacing: ((style.letterSpacing ?? 0) * 1000).round(),
      fontFamily: style.fontFamily,
      textScaler: textScaler.hashCode,
      paragraphSpacing: settings.paragraphSpacing.round(),
      doublePage: doublePage,
    );
    if (_layoutFull && _previewConsumed == 0 && _paginatedContent == body) {
      final cached = _layoutCache.get(layoutKey);
      if (cached != null) {
        _measured = cached;
        _lastSize = Size(readW, readH);
        _lastStyle = style;
        _lastPad = pad;
        _lastTextScaler = textScaler;
        _lastDoublePage = doublePage;
        return cached;
      }
    }
    final keepPos = () {
      final pages = _measured?.pages ?? const <TextPage>[];
      if (pages.isEmpty || _page >= pages.length) return 0;
      return pages[_page.clamp(0, pages.length - 1)].startPos;
    }();
    // 增量续排：预览段（maxChars 截断）已排好的页保留，postFrame 只排剩余
    // 部分（startOffset 之后），不再从头全量重排——长章节的分页工作量减半。
    final preview = body.length > 3500 && !_layoutFull;
    final appending =
        _layoutFull &&
        !_appended &&
        _previewConsumed > 0 &&
        _paginatedContent == body &&
        _measured != null;
    if (preview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _layoutFull = true);
      });
    } else if (!preview) {
      _layoutFull = true;
    }
    final next = _appendingOrFull(
      preview,
      appending,
      body,
      () {
        return MeasuredPaginator.layout(
          content: body,
          width: readW,
          height: readH,
          firstPageHeight: firstH == restH ? null : firstH,
          style: style,
          textScaler: textScaler,
          paragraphSpacing: settings.paragraphSpacing,
          maxChars: preview ? 2800 : null,
        );
      },
      () {
        // 增量续排：从预览消费位置继续，段间无首页标题高度（首页已在预览段）。
        return MeasuredPaginator.layout(
          content: body,
          width: readW,
          height: readH,
          style: style,
          textScaler: textScaler,
          paragraphSpacing: settings.paragraphSpacing,
          startOffset: _previewConsumed,
        );
      },
    );
    _measured = next;
    _paginatedContent = body;
    if (!preview && !appending) {
      _layoutCache.put(
        layoutKey,
        next,
        weight: body.length + next.pages.length * 64,
      );
    }
    _lastSize = Size(readW, readH);
    _lastStyle = style;
    _lastPad = pad;
    _lastTextScaler = textScaler;
    _lastDoublePage = doublePage;
    if (preview) _previewConsumed = next.consumedChars;
    if (!preview && !appending) _previewConsumed = 0;
    if (next.pages.isNotEmpty) {
      if (_pendingEnd) {
        _page = next.pages.length - 1;
        _pendingEnd = false;
      } else {
        var i = 0;
        for (var p = 0; p < next.pages.length; p++) {
          if (next.pages[p].startPos <= keepPos) i = p;
        }
        _page = i;
      }
    }
    return next;
  }

  /// 预览 / 增量续排 / 全量三分支的分页执行：
  /// - preview：只排前 2800 字（首帧快速出页）；
  /// - appending：复用预览段已排好的页，只从 `_previewConsumed` 续排剩余；
  /// - 其它：全量单次分页。
  PaginatedChapter _appendingOrFull(
    bool preview,
    bool appending,
    String body,
    PaginatedChapter Function() full,
    PaginatedChapter Function() append,
  ) {
    if (appending) {
      final previewChapter = _measured!;
      final rest = append();
      _appended = true;
      _previewConsumed = 0;
      return PaginatedChapter(
        content: body,
        pages: [...previewChapter.pages, ...rest.pages],
        totalChars: body.length,
        consumedChars: body.length,
      );
    }
    if (preview) {
      _appended = false;
      return full();
    }
    _appended = false;
    _previewConsumed = 0;
    return full();
  }
}
