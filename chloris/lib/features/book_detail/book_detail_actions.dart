part of 'book_detail_screen.dart';

extension _BookDetailActions on _BookDetailScreenState {
  void _openChapter(
    BuildContext context,
    BookSource source,
    Book book,
    BookChapter ch,
    List<BookChapter> all,
  ) {
    final idx = all.indexWhere((c) => c.url == ch.url).clamp(0, all.length - 1);
    book.durChapterIndex = idx;
    book.durChapterTitle = ch.title;
    ref
        .read(readingProgressProvider.notifier)
        .save(bookUrl: book.bookUrl, chapterIndex: idx, chapterTitle: ch.title);
    ref
        .read(readRecordProvider.notifier)
        .add(
          bookName: book.name,
          chapterTitle: ch.title,
          bookUrl: book.bookUrl,
        );
    try {
      context.push(
        '/reader',
        extra: ChapterRouteArgs(
          source: source,
          book: book,
          chapter: ch,
          chapters: all,
        ),
      );
    } catch (_) {
      Navigator.of(context, rootNavigator: true).push(
        FollowPageRoute(
          builder: (_) => ChapterContentScreen(
            source: source,
            book: book,
            chapter: ch,
            chapters: all,
          ),
        ),
      );
    }
  }

  Future<void> _changeSource(BuildContext context, Book book) async {
    final picked = await showModalBottomSheet<(BookSource, SearchBook)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => ChangeSourceSheet(
        bookName: book.name,
        bookAuthor: book.author,
        currentSourceUrl: _source.bookSourceUrl,
        currentBookUrl: _searchBook.bookUrl,
        seedBook: _searchBook,
      ),
    );
    if (picked == null || !mounted) return;
    final (src, sb) = picked;
    await _applySourceSwitch(src, sb, oldBookUrl: book.bookUrl);
  }

  /// 应用一次换源：失效目录缓存、更新书架条目、刷新详情。
  Future<void> _applySourceSwitch(
    BookSource src,
    SearchBook sb, {
    String? oldBookUrl,
  }) async {
    sb.origin = src.bookSourceUrl;
    sb.originName = src.bookSourceName;
    for (final e in _searchBook.originUrls.entries) {
      sb.addOrigin(e.key, e.value);
    }
    sb.addOrigin(_source.bookSourceUrl, _searchBook.bookUrl);
    final catalog = ref.read(loadOnlineCatalogUseCaseProvider);
    final stale = <String>{
      sb.bookUrl,
      if (oldBookUrl != null) oldBookUrl,
      _searchBook.bookUrl,
    };
    await Future.wait([for (final url in stale) catalog.invalidate(url)]);
    ref
        .read(onlineShelfProvider.notifier)
        .replaceBook(_searchBook.bookUrl, src, sb);
    if (!mounted) return;
    setState(() {
      _source = src;
      _searchBook = sb;
    });
    _invalidateDetail();
  }

  /// 自动换源：当前源目录为空（点开发现源空）时，搜其它源并实取目录验证，
  /// 通过后自动切换。每个详情页实例最多触发一次。
  Future<void> _autoChangeSource() async {
    if (_autoSwitching || _autoSwitched) return;
    _autoSwitching = true;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${_source.bookSourceName}」没有目录，正在寻找其它源…'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      final hit = await findVerifiedAlternativeSource(
        ref,
        bookName: _searchBook.name,
        bookAuthor: _searchBook.author,
        currentSourceUrl: _source.bookSourceUrl,
        currentBookUrl: _searchBook.bookUrl,
        seedBook: _searchBook,
        catalog: ref.read(loadOnlineCatalogUseCaseProvider),
        content: ref.read(loadOnlineChapterContentUseCaseProvider),
        isCancelled: () => !mounted,
      );
      if (!mounted) return;
      if (hit == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有找到可用的其它源，可稍后手动换源')));
        return;
      }
      await _applySourceSwitch(hit.source, hit.searchBook);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已自动换源 → ${hit.source.bookSourceName}')),
        );
      }
    } catch (_) {
      // 自动换源失败不打扰用户：详情页保留「换源」手动入口。
    } finally {
      _autoSwitching = false;
      _autoSwitched = true;
    }
  }

  Future<void> _editBook(Book book) async {
    final name = TextEditingController(text: book.name);
    final author = TextEditingController(text: book.author);
    final intro = TextEditingController(text: book.intro ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑书籍'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '书名'),
              ),
              TextField(
                controller: author,
                decoration: const InputDecoration(labelText: '作者'),
              ),
              TextField(
                controller: intro,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '简介'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      book.name = name.text.trim();
      book.author = author.text.trim();
      book.intro = intro.text.trim();
    });
  }

  Future<void> _download(
    BuildContext context,
    Book book,
    List<BookChapter> chapters,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('下载'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'current'),
            child: const Text('本章及之后'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('全部章节'),
          ),
          const Divider(height: 8),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'local'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppIcon(AppIcons.open),
              title: Text(bookExportLabel),
              subtitle: Text(
                bookExportUsesOtherApps
                    ? '生成完整 TXT，选择其他阅读应用'
                    : '并行获取章节，导出完整 TXT 文件',
              ),
            ),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'local') {
      await _exportBook(context, book, chapters);
      return;
    }
    final from = action == 'current' ? book.durChapterIndex : 0;
    Future<void> fetchChapter(int i) async {
      await fetchChapterTextFor(
        ref,
        _source,
        book,
        chapters[i],
        nextChapterUrl: i + 1 < chapters.length ? chapters[i + 1].url : null,
      );
    }

    String hostOf(int i) =>
        Uri.tryParse(chapters[i].url)?.host ?? _source.bookSourceUrl;

    await ref.read(batchDownloadUseCaseProvider)(
      bookName: book.name,
      fromIndex: from,
      total: chapters.length,
      hostOf: hostOf,
      fetchChapter: fetchChapter,
      metadata: BatchDownloadMetadata(
        sourceId: _source.bookSourceUrl,
        bookUrl: book.bookUrl,
        tocUrl: book.tocUrl,
        chapters: [
          for (var i = 0; i < chapters.length; i++)
            BatchDownloadChapterRef(
              index: i,
              title: chapters[i].title,
              url: chapters[i].url,
              baseUrl: chapters[i].baseUrl,
            ),
        ],
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已加入缓存队列')));
    }
  }

  Future<void> _exportBook(
    BuildContext context,
    Book book,
    List<BookChapter> chapters,
  ) async {
    if (chapters.isEmpty) return;
    final progress = ValueNotifier<int>(0);
    var cancelled = false;
    final session = 'download.export-${DateTime.now().microsecondsSinceEpoch}';
    final engine = ref.read(engineFacadeProvider);
    final scheduler = ChapterDownloadScheduler.instance;
    final anchor = context.findRenderObject();
    final shareRect = anchor is RenderBox
        ? anchor.localToGlobal(Offset.zero) & anchor.size
        : null;
    var dialogClosed = false;
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(bookExportLabel),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: done / chapters.length),
                const SizedBox(height: 12),
                Text('并行获取章节 $done / ${chapters.length}'),
                const SizedBox(height: 8),
                const Text('优先复用已有缓存，保持目录顺序'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                scheduler.cancelPending();
                engine.cancelSession(session);
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    ).whenComplete(() => dialogClosed = true);
    try {
      final contents = List<String>.filled(chapters.length, '');
      var cursor = 0;
      Future<void> worker() async {
        while (!cancelled && cursor < chapters.length) {
          final index = cursor++, chapter = chapters[index];
          final text = await scheduler.run(
            host: Uri.tryParse(chapter.url)?.host ?? _source.bookSourceUrl,
            cancelled: () => cancelled,
            action: () => HttpSession.bind(
              session,
              () => fetchChapterTextFor(
                ref,
                _source,
                book,
                chapter,
                nextChapterUrl: index + 1 < chapters.length
                    ? chapters[index + 1].url
                    : null,
              ),
            ),
          );
          if (cancelled) return;
          if (text.trim().isEmpty)
            throw FormatException('「${chapter.title}」正文为空，请更换书源后导出');
          contents[index] = text;
          progress.value++;
        }
      }

      await Future.wait(
        List.generate(
          chapters.length.clamp(1, EngineLimits.downloadPool.clamp(1, 16)),
          (_) => worker(),
        ),
        eagerError: true,
      );
      if (cancelled) return;
      final bytes = await compute(buildDownloadedBook, <String, Object>{
        'name': book.name,
        'author': book.author,
        'titles': chapters.map((c) => c.title).toList(),
        'contents': contents,
      });
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogClosed = true;
      await dialog;
      await exportDownloadedBook(
        bytes,
        book.name,
        book.author,
        sharePositionOrigin: shareRect,
      );
    } catch (e) {
      if (!cancelled && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：${e.toString().split('\n').first}')),
        );
      }
    } finally {
      cancelled = true;
      scheduler.cancelPending();
      engine.cancelSession(session);
      // Only close our progress dialog; a platform share sheet may have opened.
      if (context.mounted && !dialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialog;
      progress.dispose();
    }
  }
}
