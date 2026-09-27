part of 'reader_screen.dart';

TextSpan _readerSpeechSpan(String text, TtsState speech, Color foreground) {
  final active = speech.status == TtsStatus.stopped
      ? ''
      : speech.currentSentence;
  final start = active.isEmpty ? -1 : text.indexOf(active);
  if (start < 0) return TextSpan(text: text);
  final end = start + active.length;
  return TextSpan(
    children: [
      if (start > 0) TextSpan(text: text.substring(0, start)),
      TextSpan(
        text: text.substring(start, end),
        style: TextStyle(
          backgroundColor: foreground.withValues(alpha: 0.16),
          fontWeight: FontWeight.w700,
        ),
      ),
      if (end < text.length) TextSpan(text: text.substring(end)),
    ],
  );
}

extension _ReaderStack on _ReaderScreenState {
  Widget _readerStack({
    required bool isScroll,
    required ReaderSettings settings,
    required String heading,
    required String body,
    required TextStyle style,
    required Color bg,
    required Color fg,
    required PaginatedChapter paginated,
    required int total,
    required int pct,
    required int bookPct,
    required TextScaler textScaler,
    required Size viewport,
    required ValueNotifier<double> scrollProgress,
  }) {
    final doublePage = _doublePageActive(viewport, settings);
    final texts = paginated.pages.map((p) => p.text).toList();
    final spreadCount = doublePage
        ? ((texts.length + 1) ~/ 2).clamp(1, 99999)
        : texts.length.clamp(1, 99999);
    // Scroll mode does not paginate, so `paginated.pages` is intentionally
    // empty. Do not build the pager's page list for that branch: indexing the
    // empty list throws during layout and leaves the whole reader surface gray.
    final pagerPages = isScroll
        ? const <String>[]
        : List<String>.generate(
            spreadCount,
            (i) => doublePage ? texts[i * 2] : texts[i],
          );
    final spreadIndex = doublePage
        ? (_page ~/ 2).clamp(0, spreadCount - 1)
        : _page.clamp(0, spreadCount - 1);
    final pagePad = settings.pagePadding.toDouble();
    final safe = MediaQuery.viewPaddingOf(context);
    final speech = ref.watch(ttsControllerProvider);
    final visibleTop = readerVerticalInset(
      menuVisible: _menu,
      pagePadding: pagePad,
      safePadding: safe.top,
      top: true,
    );
    final hiddenTop = readerVerticalInset(
      menuVisible: false,
      pagePadding: pagePad,
      safePadding: safe.top,
      top: true,
    );
    final visibleBottom = readerVerticalInset(
      menuVisible: _menu,
      pagePadding: pagePad,
      safePadding: safe.bottom,
      top: false,
    );
    final hiddenBottom = readerVerticalInset(
      menuVisible: false,
      pagePadding: pagePad,
      safePadding: safe.bottom,
      top: false,
    );
    final contentInsets = EdgeInsets.only(
      top: _menu ? visibleTop - hiddenTop : 0,
      bottom: _menu ? visibleBottom - hiddenBottom : 0,
    );
    final columnMax = doublePage
        ? (readerColumnWidth(
                viewportWidth: viewport.width,
                pagePadding: pagePad,
                doublePage: true,
              ) +
              pagePad +
              readerDoublePageInnerPad)
        : (AppTokens.maxReadWidth + pagePad * 2);
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPadding(
          duration: AppTokens.durationMed,
          curve: Curves.easeOut,
          padding: contentInsets,
          child: isScroll
              ? GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) => _onTapAt(d.localPosition, viewport, total),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (_menu) {
                        final now = DateTime.now();
                        if (notification is ScrollEndNotification ||
                            now.difference(_lastScrollUi).inMilliseconds >=
                                250) {
                          _lastScrollUi = now;
                          _scrollProgressUi.value = _progress;
                        }
                      }
                      if (_switchingChapter) return false;
                      final m = notification.metrics;
                      // 距边界的越界量：>0 表示已经滚出了内容范围。
                      // BouncingScrollPhysics（本阅读器的设定，也是 iOS/Web
                      // 的默认手感）**不会**发 OverscrollNotification，越界
                      // 只体现为 pixels 越过 0 / maxScrollExtent。旧实现只监听
                      // OverscrollNotification，于是「滚到底继续滚就切章」在
                      // 回弹物理下是死代码。
                      final pastEnd = m.pixels - m.maxScrollExtent;
                      final pastStart = -m.pixels;

                      if (notification is ScrollUpdateNotification &&
                          pastEnd <= 0 &&
                          pastStart <= 0) {
                        // 还在内容范围内正常滚动：清掉累计的边缘拉力。
                        _edgePull = 0;
                      }

                      if (notification is OverscrollNotification) {
                        // 钳制式物理（Android 默认）走这里。
                        final atEnd =
                            m.extentAfter <= 1 && notification.overscroll > 0;
                        final atStart =
                            m.pixels <= 0 && notification.overscroll < 0;
                        if (atEnd || atStart) {
                          _edgePull += notification.overscroll.abs();
                        }
                        if (atEnd && _edgePull > 140 && widget.hasNext) {
                          _edgePull = 0;
                          _requestChapter(widget.onNextChapter);
                        } else if (atStart &&
                            _edgePull > 140 &&
                            widget.hasPrev) {
                          _edgePull = 0;
                          _requestChapter(widget.onPrevChapter);
                        }
                      } else if (notification is ScrollUpdateNotification) {
                        // 回弹式物理走这里：用力越过边界、累计超过阈值就切章。
                        if (pastEnd > 0 && widget.hasNext) {
                          _edgePull += pastEnd;
                          if (_edgePull > 140) {
                            _edgePull = 0;
                            _requestChapter(widget.onNextChapter);
                          }
                        } else if (pastStart > 0 && widget.hasPrev) {
                          _edgePull += pastStart;
                          if (_edgePull > 140) {
                            _edgePull = 0;
                            _requestChapter(widget.onPrevChapter);
                          }
                        }
                      }
                      return false;
                    },
                    child: ColoredBox(
                      color: bg,
                      child: ListView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          readerVerticalInset(
                            // The chrome is an overlay. Keeping this inset
                            // stable prevents a menu toggle from reflowing
                            // the scroll position and causing a visible jump.
                            menuVisible: false,
                            pagePadding: settings.pagePadding.toDouble(),
                            safePadding: safe.top,
                            top: true,
                          ),
                          0,
                          readerVerticalInset(
                            menuVisible: false,
                            pagePadding: settings.pagePadding.toDouble(),
                            safePadding: safe.bottom,
                            top: false,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: columnMax),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: pagePad,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (heading.isNotEmpty) ...[
                                      Text(
                                        heading,
                                        textAlign: TextAlign.left,
                                        textScaler: textScaler,
                                        style: style.copyWith(
                                          fontSize: settings.fontSize * 1.28,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: fg.withValues(alpha: 0.22),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    Text.rich(
                                      _readerSpeechSpan(
                                        collapseReaderBlankLines(body),
                                        speech,
                                        fg,
                                      ),
                                      textScaler: textScaler,
                                      style: style.copyWith(
                                        leadingDistribution:
                                            TextLeadingDistribution.even,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ReadPager(
                  controller: _pager,
                  pages: pagerPages,
                  index: spreadIndex,
                  contentKey: Object.hash(
                    widget.chapterIndex,
                    body.length,
                    body.isEmpty ? 0 : body.codeUnitAt(0),
                    body.isEmpty ? 0 : body.codeUnitAt(body.length - 1),
                    settings.fontSize,
                    settings.lineHeight,
                    settings.letterSpacing,
                    settings.pagePadding,
                    settings.doublePage,
                    doublePage,
                    textScaler,
                  ),
                  background: bg,
                  style: _pagerStyle,
                  placeholder: Center(
                    child: Text('正在打开相邻章…', style: TextStyle(color: fg)),
                  ),
                  onIndex: (i) {
                    final page = doublePage ? i * 2 : i;
                    setState(() => _page = page);
                    widget.onPageChanged?.call(page);
                  },
                  onPrevChapter: widget.hasPrev
                      ? () => _requestChapter(widget.onPrevChapter)
                      : null,
                  onNextChapter: widget.hasNext
                      ? () => _requestChapter(widget.onNextChapter)
                      : null,
                  onTap: (local, size) => _onTapAt(local, size, total),
                  pageBuilder: (ctx, text, pageIndex) {
                    final pad = settings.pagePadding.toDouble();
                    final media = MediaQuery.viewPaddingOf(ctx);
                    final topInset = readerVerticalInset(
                      menuVisible: false,
                      pagePadding: pad,
                      safePadding: media.top,
                      top: true,
                    );
                    final bottomInset = readerVerticalInset(
                      menuVisible: false,
                      pagePadding: pad,
                      safePadding: media.bottom,
                      top: false,
                    );
                    final strut = StrutStyle(
                      fontSize: style.fontSize,
                      height: style.height,
                      leadingDistribution: TextLeadingDistribution.even,
                      forceStrutHeight: true,
                    );
                    Widget leaf(int textIndex, {required bool leftPage}) {
                      final lines = textIndex < paginated.pages.length
                          ? paginated.pages[textIndex].lines
                          : const <String>[];
                      final outer = pad;
                      final inner = doublePage ? readerDoublePageInnerPad : pad;
                      return Container(
                        color: bg,
                        // Pages should start at the top reading inset. Centering
                        // a long page vertically causes its first lines to be
                        // clipped when the content is taller than the viewport.
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: columnMax),
                            child: ClipRect(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  leftPage ? outer : inner,
                                  topInset,
                                  leftPage ? inner : outer,
                                  bottomInset,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (textIndex == 0 &&
                                        heading.isNotEmpty) ...[
                                      Text(
                                        heading,
                                        textAlign: TextAlign.left,
                                        textScaler: textScaler,
                                        strutStyle: StrutStyle(
                                          fontSize: settings.fontSize * 1.28,
                                          height: 1.3,
                                          forceStrutHeight: true,
                                          leadingDistribution:
                                              TextLeadingDistribution.even,
                                        ),
                                        style: style.copyWith(
                                          fontSize: settings.fontSize * 1.28,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                          leadingDistribution:
                                              TextLeadingDistribution.even,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: fg.withValues(alpha: 0.22),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    for (final line in lines)
                                      line.trim().isEmpty
                                          ? SizedBox(
                                              height: settings.paragraphSpacing,
                                            )
                                          : Text(
                                              line,
                                              maxLines: 1,
                                              overflow: TextOverflow.visible,
                                              softWrap: false,
                                              style: style.copyWith(
                                                leadingDistribution:
                                                    TextLeadingDistribution
                                                        .even,
                                              ),
                                              strutStyle: strut,
                                              textScaler: textScaler,
                                            ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (!doublePage) {
                      return SizedBox.expand(
                        child: leaf(pageIndex, leftPage: true),
                      );
                    }
                    final leftIndex = pageIndex * 2;
                    final rightIndex = leftIndex + 1;
                    return SizedBox.expand(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: leaf(leftIndex, leftPage: true)),
                          VerticalDivider(
                            width: readerDoublePageRule,
                            thickness: readerDoublePageRule,
                            color: fg.withValues(alpha: 0.12),
                          ),
                          Expanded(
                            child: rightIndex < paginated.pages.length
                                ? leaf(rightIndex, leftPage: false)
                                : const SizedBox.expand(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        ..._readerChromeLayer(
          isScroll: isScroll,
          settings: settings,
          bg: bg,
          fg: fg,
          total: total,
          pct: pct,
          bookPct: bookPct,
          speechText: body,
          scrollProgress: scrollProgress,
        ),
      ],
    );
  }
}
