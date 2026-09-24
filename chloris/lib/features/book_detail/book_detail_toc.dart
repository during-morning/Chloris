part of 'book_detail_screen.dart';

extension _BookDetailToc on _BookDetailScreenState {
  List<Widget> _tocSlivers({
    required BuildContext context,
    required BookSource source,
    required Book book,
    required BookDetailArgs args,
    required ColorScheme cs,
    required AsyncValue<List<BookChapter>> tocAsync,
    required List<BookChapter> allChapters,
    required List<BookChapter> chapters,
  }) {
    return [
      if (tocAsync.hasValue && allChapters.length < 5)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              0,
              AppTokens.space16,
              AppTokens.space8,
            ),
            child: Material(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppTokens.radius8),
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('目录章节过少，可能解析失败'),
                subtitle: Text('点「刷新」重拉，或用「换源」换一个书源'),
              ),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space16,
            AppTokens.space8,
            AppTokens.space16,
            AppTokens.space8,
          ),
          child: Row(
            children: [
              Text(
                tocAsync.isLoading && allChapters.isEmpty
                    ? '目录'
                    : '目录（' + allChapters.length.toString() + ' 章）',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (allChapters.isNotEmpty)
                IconButton(
                  tooltip: '定位当前进度',
                  onPressed: () {
                    final i = book.durChapterIndex.clamp(
                      0,
                      allChapters.length - 1,
                    );
                    final visible = chapters;
                    final cur = allChapters[i];
                    final vi = visible.indexWhere((c) => c.url == cur.url);
                    _jumpToChapterRow(vi >= 0 ? vi : i, visible.length);
                  },
                  icon: const Icon(Icons.my_location_outlined),
                ),
              IconButton(
                tooltip: _reversed ? '正序' : '倒序',
                onPressed: () => setState(() => _reversed = !_reversed),
                icon: Icon(
                  _reversed ? Icons.arrow_upward : Icons.arrow_downward,
                ),
              ),
            ],
          ),
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
          child: MeowQueryField(
            controller: _tocCtrl,
            hint: '筛选章节名',
            onChanged: (v) => setState(() => _tocQuery = v),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(key: _tocAnchor, height: 0)),
      if (tocAsync.isLoading && allChapters.isEmpty)
        const SliverToBoxAdapter(child: BookDetailTocSkeleton())
      else if (tocAsync.isLoading && allChapters.isNotEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          ),
        )
      else if (allChapters.isEmpty && (tocAsync.hasError || tocAsync.hasValue))
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              children: [
                Text(
                  '目录加载失败：站点超时或无响应。可重试，或换源。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTokens.space12),
                FilledButton(
                  onPressed: _invalidateDetail,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        )
      else
        SliverFixedExtentList(
          itemExtent: AppTokens.tocItemExtent,
          delegate: SliverChildBuilderDelegate((context, i) {
            final ch = chapters[i];
            final current =
                book.durChapterIndex >= 0 &&
                book.durChapterIndex < allChapters.length &&
                allChapters[book.durChapterIndex].url == ch.url;
            final cached =
                ref
                    .read(chapterContentStoreProvider)
                    .get(source.bookSourceUrl, ch.url) !=
                null;
            return ListTile(
              dense: true,
              selected: current,
              selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.6),
              leading: current
                  ? const Icon(Icons.menu_book, size: 18)
                  : Icon(
                      cached
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      size: 14,
                      color: cached ? cs.primary : cs.outlineVariant,
                    ),
              title: Text(
                ch.title,
                style: TextStyle(
                  fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  color: cached || current ? null : cs.onSurfaceVariant,
                ),
              ),
              onTap: () => _openChapter(context, source, book, ch, allChapters),
            );
          }, childCount: chapters.length),
        ),
    ];
  }
}
