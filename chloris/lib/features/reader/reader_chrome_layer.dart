part of 'reader_screen.dart';

extension _ReaderChromeLayer on _ReaderScreenState {
  List<Widget> _readerChromeLayer({
    required bool isScroll,
    required ReaderSettings settings,
    required Color bg,
    required Color fg,
    required int total,
    required int pct,
    required int bookPct,
    required String speechText,
    required ValueNotifier<double> scrollProgress,
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppStyleExtension>();
    final mono = ext?.mono ?? false;
    // Bars sit on the reading paper itself and are closed by a hairline
    // instead of a drop shadow, so the page never looks like it has a
    // floating toolbar pasted on top of it.
    final barColor = bg.withValues(alpha: 0.97);
    final hairline = BorderSide(color: fg.withValues(alpha: 0.14));
    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle())
        .copyWith(color: fg, fontWeight: FontWeight.w600);
    final metaStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: fg.withValues(alpha: 0.55),
    );

    return [
      if (settings.brightness < 0.999)
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Color.fromRGBO(
                0,
                0,
                0,
                (1 - settings.brightness).clamp(0, 0.7),
              ),
            ),
          ),
        ),
      AnimatedPositioned(
        duration: AppTokens.durationMed,
        curve: Curves.easeOut,
        top: _menu ? 0 : -140,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !_menu,
          child: Material(
            color: barColor,
            elevation: 0,
            shape: Border(bottom: hairline),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      icon: AppIcon(AppIcons.back, color: fg, size: 18),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mono
                                ? '[ ${widget.chapterTitle} ]'
                                : widget.chapterTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          if (!mono)
                            Text(
                              _readerMetaLine(pct, bookPct),
                              maxLines: 1,
                              style: metaStyle,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '目录',
                      icon: AppIcon(AppIcons.list, color: fg, size: 18),
                      onPressed: _openToc,
                    ),
                    IconButton(
                      tooltip: '阅读设置',
                      icon: AppIcon(AppIcons.tune, color: fg, size: 18),
                      onPressed: () => showReadingSettingsSheet(context),
                    ),
                    // 朗读入口：根据状态在三态间切换（朗读 / 暂停 / 继续），
                    // 单独一个停止按钮在朗读进行中显示。用 Consumer 包裹，使 TTS
                    // 状态变化只重建这两个按钮，而不触发整个阅读页重排。
                    Consumer(
                      builder: (context, ref, _) {
                        final tts = ref.watch(ttsControllerProvider);
                        return Row(
                          children: [
                            IconButton(
                              tooltip: tts.status == TtsStatus.playing
                                  ? '暂停朗读'
                                  : tts.status == TtsStatus.paused
                                  ? '继续朗读'
                                  : '朗读',
                              icon: AppIcon(
                                tts.status == TtsStatus.playing
                                    ? AppIcons.pause
                                    : AppIcons.play,
                                color: fg,
                                size: 18,
                              ),
                              onPressed: () {
                                if (!ttsPlatformSupported()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('当前平台暂不支持朗读')),
                                  );
                                  return;
                                }
                                final ctrl = ref.read(
                                  ttsControllerProvider.notifier,
                                );
                                if (tts.status == TtsStatus.playing) {
                                  ctrl.pause();
                                } else if (tts.status == TtsStatus.paused) {
                                  ctrl.resume();
                                } else {
                                  ctrl.start(
                                    speechText,
                                    onNextChapter: widget.onNextChapter,
                                  );
                                }
                              },
                            ),
                            if (tts.status != TtsStatus.stopped)
                              IconButton(
                                tooltip: '停止朗读',
                                icon: AppIcon(
                                  AppIcons.close,
                                  color: fg,
                                  size: 18,
                                ),
                                onPressed: () => ref
                                    .read(ttsControllerProvider.notifier)
                                    .stop(),
                              ),
                          ],
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      icon: AppIcon(AppIcons.more, color: fg, size: 18),
                      onSelected: (v) {
                        switch (v) {
                          case 'search':
                            _searchInChapter(total);
                          case 'bookmark':
                            _addBookmark();
                          case 'reload':
                            widget.onReloadChapter?.call();
                          case 'copy':
                            Clipboard.setData(
                              ClipboardData(text: widget.content),
                            ).then((_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已复制本章')),
                                );
                              }
                            });
                          case 'auto':
                            _toggleAuto();
                          case 'theme':
                            _toggleDayNight();
                          case 'keys':
                            _showKeys();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'search',
                          child: Text('本章搜索'),
                        ),
                        const PopupMenuItem(
                          value: 'bookmark',
                          child: Text('添加书签'),
                        ),
                        if (widget.onReloadChapter != null)
                          const PopupMenuItem(
                            value: 'reload',
                            child: Text('重载本章'),
                          ),
                        const PopupMenuItem(value: 'copy', child: Text('复制本章')),
                        PopupMenuItem(
                          value: 'auto',
                          child: Text(_auto == null ? '自动翻页' : '停止自动'),
                        ),
                        const PopupMenuItem(
                          value: 'theme',
                          child: Text('日间 / 夜间'),
                        ),
                        const PopupMenuItem(value: 'keys', child: Text('快捷键')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      AnimatedPositioned(
        duration: AppTokens.durationMed,
        curve: Curves.easeOut,
        bottom: _menu ? 0 : -140,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !_menu,
          child: Material(
            color: barColor,
            elevation: 0,
            shape: Border(top: hairline),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '上一章',
                      onPressed: widget.hasPrev ? widget.onPrevChapter : null,
                      icon: AppIcon(AppIcons.skipPrevious, color: fg, size: 18),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: scrollProgress,
                        builder: (context, currentScrollProgress, _) {
                          final currentPct = isScroll
                              ? (currentScrollProgress * 100).round()
                              : pct;
                          final currentBookPct =
                              isScroll && widget.chapters.isNotEmpty
                              ? (((widget.chapterIndex +
                                                currentScrollProgress) /
                                            widget.chapters.length) *
                                        100)
                                    .clamp(0, 100)
                                    .round()
                              : bookPct;
                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  activeTrackColor: fg,
                                  inactiveTrackColor: fg.withValues(
                                    alpha: 0.22,
                                  ),
                                  thumbColor: fg,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                ),
                                child: Slider(
                                  value: isScroll
                                      ? currentScrollProgress
                                      : (total <= 1 ? 0 : _page / (total - 1)),
                                  onChanged: (v) {
                                    if (isScroll && _scroll.hasClients) {
                                      _scroll.jumpTo(
                                        v * _scroll.position.maxScrollExtent,
                                      );
                                      scrollProgress.value = v;
                                    } else {
                                      final p = (v * (total - 1)).round();
                                      setState(() => _page = p);
                                    }
                                  },
                                ),
                              ),
                              Text(
                                isScroll
                                    ? '滚动 · $currentPct% · 全书 $currentBookPct%'
                                    : '${_page + 1} / $total · $currentPct% · 全书 $currentBookPct%',
                                style: (theme.textTheme.labelSmall ?? metaStyle)
                                    .copyWith(
                                      color: fg.withValues(alpha: 0.55),
                                      letterSpacing: mono ? 0.8 : 0.4,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: '下一章',
                      onPressed: widget.hasNext ? widget.onNextChapter : null,
                      icon: AppIcon(AppIcons.skipNext, color: fg, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      AnimatedPositioned(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppTokens.durationMed,
        curve: Curves.easeOutCubic,
        top: 0,
        bottom: 0,
        left: _toc
            ? 0.0
            : -(MediaQuery.sizeOf(context).width < 420
                  ? MediaQuery.sizeOf(context).width * 0.86
                  : 360.0),
        width: MediaQuery.sizeOf(context).width < 420
            ? MediaQuery.sizeOf(context).width * 0.86
            : 360,
        child: IgnorePointer(
          ignoring: !_toc,
          child: Material(
            color: bg,
            elevation: 0,
            shape: Border(right: hairline),
            child: ChapterTocPanel(
              embedded: true,
              chapters: widget.chapters,
              currentIndex: widget.chapterIndex,
              bookName: widget.bookTitle ?? '',
              bookAuthor: widget.bookAuthor,
              foreground: fg,
              background: bg,
              onClose: () => setState(() => _toc = false),
              onOpenChapter: (i) {
                setState(() => _toc = false);
                widget.onOpenChapter?.call(i);
              },
            ),
          ),
        ),
      ),
    ];
  }

  String _readerMetaLine(int pct, int bookPct) {
    final book = widget.bookTitle ?? '';
    if (book.isEmpty) return '$pct% · 全书 $bookPct%';
    return '$book  ·  $pct%  ·  全书 $bookPct%';
  }
}
