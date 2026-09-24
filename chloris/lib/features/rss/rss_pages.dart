part of 'rss_screen.dart';

class _Articles extends ConsumerStatefulWidget {
  const _Articles({required this.source});

  final RssSource source;

  @override
  ConsumerState<_Articles> createState() => _ArticlesState();
}

class _ArticlesState extends ConsumerState<_Articles> {
  String _q = '';
  late String _selectedUrl;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.source.sourceUrl;
  }

  @override
  Widget build(BuildContext context) {
    final sorts = widget.source.sortUrls();
    final articles = _selectedUrl == widget.source.sourceUrl
        ? ref.watch(rssArticlesProvider(widget.source))
        : ref.watch(
            rssCategoryArticlesProvider(
              RssCategoryKey(widget.source, _selectedUrl),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sorts.isNotEmpty) _buildCategoryChips(sorts),
        articles.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              Padding(padding: const EdgeInsets.all(12), child: Text('拉取失败：$e')),
          data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('暂无文章'),
          );
        }
        final starred = ref.watch(starredRssProvider);
        final q = _q.toLowerCase();
        final shown =
            (q.isEmpty
                  ? List.of(list)
                  : list
                        .where(
                          (a) =>
                              a.title.toLowerCase().contains(q) ||
                              a.author.toLowerCase().contains(q),
                        )
                        .toList())
              ..sort((a, b) {
                final da = DateTime.tryParse(a.pubDate);
                final db = DateTime.tryParse(b.pubDate);
                if (da != null && db != null) return db.compareTo(da);
                return b.pubDate.compareTo(a.pubDate);
              });
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: MeowQueryField(
                hint: '筛选文章',
                leading: Icons.filter_list,
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            ...shown.map(
              (a) => ListTile(
                dense: true,
                title: Text(a.title),
                subtitle: Text(
                  [a.pubDate, a.author].where((e) => e.isNotEmpty).join(' · '),
                ),
                trailing: IconButton(
                  icon: Icon(
                    starred.contains(a.link) ? Icons.star : Icons.star_border,
                  ),
                  onPressed: a.link.isEmpty
                      ? null
                      : () => ref
                            .read(starredRssProvider.notifier)
                            .toggle(a.link),
                ),
                onTap: () => _showArticle(context, a),

                onLongPress: () async {
                  await ref.read(rssArticleSnapshotsProvider.notifier).save(a);
                  final text = a.link.isNotEmpty ? a.link : a.title;
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制链接')));
                  }
                },
              ),
            ),
          ],
        );
      },
        ),
      ],
    );
  }

  Widget _buildCategoryChips(List<RssSortUrl> sorts) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _categoryChip('全部', widget.source.sourceUrl, theme),
          for (final s in sorts)
            _categoryChip(
              s.name.isEmpty ? s.url : s.name,
              s.url,
              theme,
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String url, ThemeData theme) {
    final selected = _selectedUrl == url;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedUrl = url),
      ),
    );
  }
}

void _showArticle(BuildContext context, RssArticle article) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute(builder: (_) => RssReadPage(article: article)));
}

class RssReadPage extends StatelessWidget {
  const RssReadPage({super.key, required this.article});
  final RssArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (article.link.isNotEmpty)
            IconButton(
              tooltip: '复制链接',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: article.link));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制链接')));
                }
              },
            ),
          if (article.link.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => launchUrl(Uri.parse(article.link)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            [
              article.pubDate,
              article.author,
              article.sourceName,
            ].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 640,
            child: HtmlContentView(
              htmlContent: article.content.isNotEmpty
                  ? article.content
                  : article.description,
              css: '''
                .chloris-reader-article { font-size: 16px; line-height: 1.8; overflow-wrap: anywhere; }
                .chloris-reader-article img { max-width: 100%; height: auto; }
                .chloris-reader-article a { color: inherit; }
              ''',
            ),
          ),
        ],
      ),
    );
  }
}

class RssFavoritesPage extends ConsumerStatefulWidget {
  const RssFavoritesPage();
  @override
  ConsumerState<RssFavoritesPage> createState() => _RssFavoritesPageState();
}

class _RssFavoritesPageState extends ConsumerState<RssFavoritesPage> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(starredRssProvider);
    final snapshots = ref.watch(rssArticleSnapshotsProvider);
    final keys = {...links, ...snapshots.keys}.toList()..sort();
    final selecting = _selected.isNotEmpty;
    Future<void> removeKeys(Iterable<String> targets) async {
      final list = targets.toList();
      for (final key in list) {
        if (links.contains(key))
          ref.read(starredRssProvider.notifier).toggle(key);
      }
      await ref.read(rssArticleSnapshotsProvider.notifier).removeMany(list);
      if (mounted) setState(_selected.clear);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selecting ? '已选 ${_selected.length} 项' : 'RSS 收藏'),
        actions: [
          if (keys.isNotEmpty)
            IconButton(
              tooltip: _selected.length == keys.length ? '取消全选' : '全选',
              icon: Icon(
                _selected.length == keys.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () => setState(() {
                if (_selected.length == keys.length)
                  _selected.clear();
                else
                  _selected.addAll(keys);
              }),
            ),
          if (selecting)
            IconButton(
              tooltip: '删除所选',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => removeKeys(_selected),
            ),
          IconButton(
            tooltip: '清理孤立快照',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () async {
              await ref
                  .read(rssArticleSnapshotsProvider.notifier)
                  .clearOrphans(links);
              if (mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已清理孤立快照')));
            },
          ),
        ],
      ),
      body: keys.isEmpty
          ? const Center(child: Text('暂无收藏'))
          : ListView(
              children: [
                for (final key in keys)
                  Builder(
                    builder: (context) {
                      final article = snapshots[key];
                      final chosen = _selected.contains(key);
                      return ListTile(
                        selected: chosen,
                        title: Text(article?.title ?? key, maxLines: 2),
                        subtitle: article == null
                            ? const Text('仅保存链接')
                            : Text(
                                [
                                  article.pubDate,
                                  article.sourceName,
                                ].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                              ),
                        leading: selecting
                            ? Checkbox(
                                value: chosen,
                                onChanged: (_) => setState(
                                  () => chosen
                                      ? _selected.remove(key)
                                      : _selected.add(key),
                                ),
                              )
                            : Icon(
                                article == null
                                    ? Icons.link_outlined
                                    : Icons.article_outlined,
                              ),
                        onLongPress: () => setState(() => _selected.add(key)),
                        onTap: selecting
                            ? () => setState(
                                () => chosen
                                    ? _selected.remove(key)
                                    : _selected.add(key),
                              )
                            : (article != null
                                  ? () => _showArticle(context, article)
                                  : () => launchUrl(Uri.parse(key))),
                        trailing: selecting
                            ? null
                            : IconButton(
                                tooltip: '移除收藏',
                                icon: const Icon(Icons.star),
                                onPressed: () => removeKeys([key]),
                              ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
