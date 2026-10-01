part of 'book_detail_screen.dart';

extension _BookDetailBody on _BookDetailScreenState {
  Widget _detailBody({
    required BuildContext context,
    required BookSource source,
    required SearchBook searchBook,
    required Book book,
    required BookDetailArgs args,
    required ColorScheme cs,
    required AsyncValue<Book> infoAsync,
    required AsyncValue<List<BookChapter>> tocAsync,
    required List<BookChapter> allChapters,
    required List<BookChapter> openChapters,
    required List<BookChapter> chapters,
    required List<CacheJob> jobs,
    required bool canStart,
  }) {
    return CustomScrollView(
      controller: _scroll,
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (jobs.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                for (final job in jobs)
                  LinearProgressIndicator(
                    value: job.total <= 0
                        ? null
                        : (job.done / job.total).clamp(0, 1),
                  ),
                if (jobs.first.running)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      6,
                      AppTokens.space16,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '缓存 ' +
                            jobs.first.done.toString() +
                            '/' +
                            jobs.first.total.toString() +
                            (jobs.first.failed > 0
                                ? ' · 失败 ' + jobs.first.failed.toString()
                                : ''),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: BookDetailHeader(
            source: source,
            book: book,
            progress: (book.durChapterTitle ?? '').isNotEmpty
                ? '读到 · ' + book.durChapterTitle!
                : null,
            onAuthorTap: book.author.isEmpty
                ? null
                : () {
                    ref.read(searchQueryProvider.notifier).state = book.author;
                    ref
                        .read(searchControllerProvider.notifier)
                        .run(book.author);
                    context.go('/search');
                  },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              0,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              children: [
                FilledButton.icon(
                  onPressed: canStart
                      ? () {
                          final i = book.durChapterIndex.clamp(
                            0,
                            openChapters.length - 1,
                          );
                          _openChapter(
                            context,
                            source,
                            book,
                            openChapters[i],
                            openChapters,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.menu_book),
                  label: Text(book.durChapterIndex > 0 ? '继续阅读' : '开始阅读'),
                ),
                if (allChapters.length > 1)
                  OutlinedButton.icon(
                    onPressed: () {
                      final last = allChapters.length - 1;
                      _openChapter(
                        context,
                        source,
                        book,
                        allChapters[last],
                        allChapters,
                      );
                    },
                    icon: const Icon(Icons.fast_forward),
                    label: const Text('读最新'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _changeSource(context, book),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('换源'),
                ),
                OutlinedButton.icon(
                  onPressed: allChapters.isEmpty || _addingToShelf
                      ? null
                      : () => _addVerifiedBookToShelf(
                          context,
                          source,
                          searchBook,
                          book,
                          allChapters,
                        ),
                  icon: _addingToShelf
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_border),
                  label: Text(_addingToShelf ? '验证中' : '验证后加入书架'),
                ),
                OutlinedButton.icon(
                  onPressed: allChapters.isEmpty
                      ? null
                      : () {
                          try {
                            context.push(
                              '/reader/toc',
                              extra: TocRouteArgs(
                                book: book,
                                chapters: allChapters,
                                onOpenChapter: (i) => _openChapter(
                                  context,
                                  source,
                                  book,
                                  allChapters[i],
                                  allChapters,
                                ),
                              ),
                            );
                          } catch (_) {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => TocPage(
                                  book: book,
                                  chapters: allChapters,
                                  onOpenChapter: (i) => _openChapter(
                                    context,
                                    source,
                                    book,
                                    allChapters[i],
                                    allChapters,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.list_alt),
                  label: Text(
                    '目录 · ' +
                        (tocAsync.isLoading && allChapters.isEmpty
                            ? '…'
                            : allChapters.length.toString()),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: allChapters.isEmpty
                      ? null
                      : () => _download(context, book, allChapters),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('下载'),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (k) async {
                    if (k == 'refresh') {
                      await ref
                          .read(loadOnlineCatalogUseCaseProvider)
                          .invalidate(book.bookUrl);
                      _invalidateDetail();
                    } else if (k == 'edit') {
                      await _editBook(book);
                    } else if (k == 'canUpdate') {
                      setState(() => book.canUpdate = !book.canUpdate);
                    } else if (k == 'split') {
                      setState(() {
                        book.readConfig ??= ReadConfig();
                        book.readConfig!.splitLongChapter =
                            !(book.readConfig!.splitLongChapter);
                      });
                    } else if (k == 'copyBook') {
                      await Clipboard.setData(
                        ClipboardData(text: book.bookUrl),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制书 URL')),
                        );
                      }
                    } else if (k == 'copyToc') {
                      await Clipboard.setData(ClipboardData(text: book.tocUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制目录 URL')),
                        );
                      }
                    } else if (k == 'copyTocList') {
                      final text = allChapters
                          .map((c) => c.title)
                          .join(String.fromCharCode(10));
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '已复制 ' + allChapters.length.toString() + ' 章标题',
                            ),
                          ),
                        );
                      }
                    } else if (k == 'copyJson') {
                      final json = const JsonEncoder.withIndent('  ').convert({
                        'book': book.toJson(),
                        'sourceUrl': source.bookSourceUrl,
                        'sourceName': source.bookSourceName,
                        'chapters': allChapters
                            .map((c) => {'title': c.title, 'url': c.url})
                            .toList(),
                      });
                      await Clipboard.setData(ClipboardData(text: json));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制本书 JSON')),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'refresh', child: Text('刷新目录')),
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(
                      value: 'canUpdate',
                      child: Text(book.canUpdate ? '禁止更新' : '允许更新'),
                    ),
                    PopupMenuItem(
                      value: 'split',
                      child: Text(
                        (book.readConfig?.splitLongChapter ?? true)
                            ? '关闭拆分长章节'
                            : '开启拆分长章节',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copyBook',
                      child: Text('复制书 URL'),
                    ),
                    const PopupMenuItem(
                      value: 'copyToc',
                      child: Text('复制目录 URL'),
                    ),
                    const PopupMenuItem(
                      value: 'copyTocList',
                      child: Text('复制目录标题'),
                    ),
                    const PopupMenuItem(
                      value: 'copyJson',
                      child: Text('复制本书 JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ..._tocSlivers(
          context: context,
          source: source,
          book: book,
          args: args,
          cs: cs,
          tocAsync: tocAsync,
          allChapters: allChapters,
          chapters: chapters,
        ),
      ],
    );
  }
}
