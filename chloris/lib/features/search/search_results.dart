part of 'search_screen.dart';

class _MergedList extends StatefulWidget {
  const _MergedList({
    required this.rows,
    required this.query,
    this.precise = false,
  });

  final List<SourceSearchResult> rows;
  final String query;
  final bool precise;

  @override
  State<_MergedList> createState() => _MergedListState();
}

class _MergedListState extends State<_MergedList> {
  List<(BookSource, SearchBook)> _items = const [];
  List<SourceSearchResult>? _rows;
  String _query = '';
  bool _precise = false;
  IncrementalSearchMerge? _inc;
  var _seen = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _MergedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (identical(_rows, widget.rows) &&
        _query == widget.query &&
        _precise == widget.precise) {
      return;
    }
    final reset =
        _inc == null || _query != widget.query || widget.rows.length < _seen;
    _rows = widget.rows;
    _query = widget.query;
    _precise = widget.precise;
    if (reset) {
      _inc = IncrementalSearchMerge(widget.query);
      _seen = 0;
    }
    for (var i = _seen; i < widget.rows.length; i++) {
      _inc!.add(widget.rows[i]);
    }
    _seen = widget.rows.length;
    _items = _inc!.snapshot(precise: widget.precise);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final rows = widget.rows;
    if (items.isEmpty) {
      final errors = rows
          .where((r) => r.error != null && r.error!.isNotEmpty)
          .map((r) => r.error!)
          .toSet();
      final proxyDown = errors.any((e) => e.contains('代理') || e.contains('跨域'));
      return MeowEmpty(
        title: proxyDown ? '搜索代理未启动' : '暂无命中',
        body: proxyDown
            ? '当前页面没有 /proxy/http，书源请求被浏览器拦住。请用带代理的地址打开。'
            : (errors.isEmpty
                  ? '仍在搜索、换关键词，或关掉「精确」。'
                  : '失败示例：${errors.take(3).join(' · ')}'),
      );
    }
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final (source, b) = items[i];
        return _BookTile(source: source, book: b);
      },
    );
  }
}

class _BySourceList extends StatelessWidget {
  const _BySourceList({required this.rows, required this.query});

  final List<SourceSearchResult> rows;
  final String query;

  int _best(SourceSearchResult r) {
    var best = 0;
    final k = normalizeSearchText(query);
    for (final b in r.books) {
      final n = normalizeSearchText(b.name);
      var s = 0;
      if (n == k) {
        s = 1000;
      } else if (n.contains(k) || k.contains(n)) {
        s = 600;
      }
      if (s > best) best = s;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final ok =
        rows
            .where(
              (r) => r.books.any((b) => isUsableSearchBook(b, query: query)),
            )
            .toList()
          ..sort((a, b) => _best(b).compareTo(_best(a)));
    if (ok.isEmpty) {
      return const MeowEmpty(title: '暂无命中', body: '仍在搜索或换个关键词。');
    }
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      itemCount: ok.length,
      itemBuilder: (context, i) {
        final r = ok[i];
        return ExpansionTile(
          title: Text(r.source.bookSourceName),
          subtitle: Text('${r.books.length} 条'),
          initiallyExpanded: i < 3,
          children: [
            for (final b in r.books)
              if (isUsableSearchBook(b, query: query))
                _BookTile(source: r.source, book: b),
          ],
        );
      },
    );
  }
}

class _BookTile extends ConsumerWidget {
  const _BookTile({required this.source, required this.book});

  final BookSource source;
  final SearchBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 40,
          child: MeowCover(
            title: book.name,
            imageUrl: book.coverUrl,
            height: 56,
            source: source,
          ),
        ),
        title: Text(book.name),
        isThreeLine: (book.intro ?? '').trim().isNotEmpty,
        subtitle: Text(
          [
            [
              book.author,
              book.origins.length > 1
                  ? '${book.origins.length} 源'
                  : source.bookSourceName,
              book.kind,
              book.wordCount,
            ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' · '),
            if ((book.latestChapterTitle ?? '').isNotEmpty)
              '最新 ${book.latestChapterTitle!}',
            if ((book.intro ?? '').trim().isNotEmpty)
              book.intro!.replaceAll(RegExp(r'\s+'), ' ').trim(),
          ].where((e) => e.isNotEmpty).join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
        ),
        onTap: () {
          // Opening a result is an explicit hand-off from search to detail;
          // stop the full-source fan-out so late results cannot keep the page
          // busy or overwrite the detail flow.
          ref.read(searchControllerProvider.notifier).cancel();
          openOnlineBook(context, ref, source: source, searchBook: book);
        },
        onLongPress: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('加入书架'),
                  onTap: () {
                    ref.read(onlineShelfProvider.notifier).add(source, book);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已加入书架')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('调试此源'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => SourceDebugScreen(source: source),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('禁用此源'),
                  onTap: () {
                    ref
                        .read(sourceEnabledOverrideProvider.notifier)
                        .setEnabled(source.bookSourceUrl, false);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('复制书籍 JSON'),
                  onTap: () async {
                    final json = const JsonEncoder.withIndent('  ').convert({
                      'source': source.bookSourceName,
                      'sourceUrl': source.bookSourceUrl,
                      'book': book.toJson(),
                    });
                    await Clipboard.setData(ClipboardData(text: json));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制书籍 JSON')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestRow extends ConsumerWidget {
  const _SuggestRow({required this.draft, required this.onPick});
  final String draft;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(searchHistoryProvider);
    final k = draft.toLowerCase();
    final hits = hist
        .where((e) => e.toLowerCase().contains(k) && e != draft)
        .take(6)
        .toList();
    if (hits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final q in hits)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    q,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onPressed: () => onPick(q),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist = ref.watch(searchHistoryProvider);
    if (hist.isEmpty) {
      return const MeowEmpty(
        title: '从多个书源并发搜索',
        body: '输入书名或作者，回车即搜。结果边搜边出；点结果直接续读，长按加入书架。',
      );
    }
    return ListView(
      children: [
        ListTile(
          title: const Text('搜索历史'),
          trailing: TextButton(
            onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
            child: const Text('清空'),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in hist)
              GestureDetector(
                onLongPress: () =>
                    ref.read(searchHistoryProvider.notifier).remove(q),
                child: ActionChip(
                  label: Text(
                    q,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onPressed: () => onPick(q),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
