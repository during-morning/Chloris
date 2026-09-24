part of 'reader_screen.dart';

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
  }) {
    final doublePage = _doublePageActive(viewport, settings);
    final texts = paginated.pages.map((p) => p.text).toList();
    final spreadCount = doublePage ? ((texts.length + 1) ~/ 2).clamp(1, 99999) : texts.length.clamp(1, 99999);
    final pagerPages = List<String>.generate(
      spreadCount,
      (i) => doublePage ? texts[i * 2] : texts[i],
    );
    final spreadIndex = doublePage ? (_page ~/ 2).clamp(0, spreadCount - 1) : _page.clamp(0, spreadCount - 1);
    return Stack(
      children: [
        isScroll
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.maxReadWidth,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) => _onTapAt(d.localPosition, viewport, total),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (_menu) {
                          final now = DateTime.now();
                          if (now.difference(_lastScrollUi).inMilliseconds >=
                              100) {
                            _lastScrollUi = now;
                            setState(() {});
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
                            _switchingChapter = true;
                            widget.onNextChapter?.call();
                          } else if (atStart &&
                              _edgePull > 140 &&
                              widget.hasPrev) {
                            _edgePull = 0;
                            _switchingChapter = true;
                            widget.onPrevChapter?.call();
                          }
                        } else if (notification is ScrollUpdateNotification) {
                          // 回弹式物理走这里：用力越过边界、累计超过阈值就切章。
                          if (pastEnd > 0 && widget.hasNext) {
                            _edgePull += pastEnd;
                            if (_edgePull > 140) {
                              _edgePull = 0;
                              _switchingChapter = true;
                              widget.onNextChapter?.call();
                            }
                          } else if (pastStart > 0 && widget.hasPrev) {
                            _edgePull += pastStart;
                            if (_edgePull > 140) {
                              _edgePull = 0;
                              _switchingChapter = true;
                              widget.onPrevChapter?.call();
                            }
                          }
                        }
                        if (_switchingChapter) {
                          Future<void>.delayed(
                            const Duration(milliseconds: 400),
                            () {
                              if (mounted) {
                                _switchingChapter = false;
                              }
                            },
                          );
                        }
                        return false;
                      },
                      child: ListView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          settings.pagePadding.toDouble(),
                          readerVerticalInset(
                            menuVisible: _menu,
                            pagePadding: settings.pagePadding.toDouble(),
                            safePadding: MediaQuery.paddingOf(context).top,
                            top: true,
                          ),
                          settings.pagePadding.toDouble(),
                          readerVerticalInset(
                            menuVisible: _menu,
                            pagePadding: settings.pagePadding.toDouble(),
                            safePadding: MediaQuery.paddingOf(context).bottom,
                            top: false,
                          ),
                        ),
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
                          Text(
                            collapseReaderBlankLines(body),
                            textScaler: textScaler,
                            style: style.copyWith(
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                          ),
                        ],
                      ),
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
                  _menu,
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
                onPrevChapter: widget.hasPrev ? widget.onPrevChapter : null,
                onNextChapter: widget.hasNext ? widget.onNextChapter : null,
                onTap: (local, size) => _onTapAt(local, size, total),
                pageBuilder: (ctx, text, pageIndex) {
                  final pad = settings.pagePadding.toDouble();
                  final media = MediaQuery.paddingOf(ctx);
                  final topInset = readerVerticalInset(
                    menuVisible: _menu,
                    pagePadding: pad,
                    safePadding: media.top,
                    top: true,
                  );
                  final bottomInset = readerVerticalInset(
                    menuVisible: _menu,
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
                    return ClipRect(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          leftPage ? outer : inner,
                          topInset,
                          leftPage ? inner : outer,
                          bottomInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (textIndex == 0 && heading.isNotEmpty) ...[
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
                                  ? SizedBox(height: settings.paragraphSpacing)
                                  : Text(
                                      line,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      softWrap: false,
                                      style: style.copyWith(
                                        leadingDistribution:
                                            TextLeadingDistribution.even,
                                      ),
                                      strutStyle: strut,
                                      textScaler: textScaler,
                                    ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!doublePage) {
                    return SizedBox.expand(child: leaf(pageIndex, leftPage: true));
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
        ..._readerChromeLayer(
          isScroll: isScroll,
          settings: settings,
          bg: bg,
          fg: fg,
          total: total,
          pct: pct,
          bookPct: bookPct,
        ),
      ],
    );
  }
}
