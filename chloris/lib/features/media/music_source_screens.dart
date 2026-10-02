import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../app/providers.dart';
import '../../app/theme/app_icons.dart';
import '../../core/http/http_session.dart';
import '../../core/read/book_validation.dart';
import '../sources/source_library_provider.dart';
import 'audio_types.dart';
import 'music_controller.dart';
import 'music_services.dart';
import 'music_workspace.dart';

class MusicDiscovery extends ConsumerWidget {
  const MusicDiscovery({super.key, this.sliver = false});
  final bool sliver;
  Widget _empty(Widget child) =>
      sliver ? SliverFillRemaining(hasScrollBody: false, child: child) : child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(enabledSourcesProvider);
    return sources.when(
      loading: () => _empty(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _empty(Center(child: Text('$e'))),
      data: (all) {
        final audio = all
            .where((s) => s.bookSourceType == BookSourceType.audio)
            .toList();
        if (audio.isEmpty) {
          return _empty(
            const Center(child: Text('暂无启用的音频书源，请在“我的 → 书源”导入音频书源')),
          );
        }
        final colors = Theme.of(context).colorScheme;
        Widget item(BuildContext c, int i) {
          final s = audio[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                visualDensity: const VisualDensity(vertical: -1),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.headphones,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  s.bookSourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  s.bookSourceGroup?.trim().isNotEmpty == true
                      ? s.bookSourceGroup!
                      : '音频书源',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const AppIcon(AppIcons.forward),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MusicSourceExplore(source: s),
                  ),
                ),
              ),
            ),
          );
        }

        return sliver
            ? SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '音频书源',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '选择来源，浏览有声书与章节',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                '${audio.length} 个来源',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: audio.length,
                    itemBuilder: item,
                  ),
                ],
              )
            : ListView.builder(
                itemCount: audio.length + 1,
                itemBuilder: (context, index) => index == 0
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          '音频书源 · ${audio.length} 个来源',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      )
                    : item(context, index - 1),
              );
      },
    );
  }
}

class MusicSearchScreen extends ConsumerStatefulWidget {
  const MusicSearchScreen({super.key});
  @override
  ConsumerState<MusicSearchScreen> createState() => _MusicSearchState();
}

class _MusicSearchState extends ConsumerState<MusicSearchScreen> {
  final _query = TextEditingController();
  final _results = <(BookSource, SearchBook)>[];
  final _failed = <BookSource>[];
  List<(BookSource, SearchBook)> _visible = [];
  MusicOperation? _operation;
  Timer? _publish;
  int _done = 0, _total = 0;
  bool _running = false;
  String? _error;
  @override
  void dispose() {
    _operation?.cancel();
    _publish?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _snapshot() {
    _publish?.cancel();
    _publish = null;
    if (mounted) setState(() => _visible = List.unmodifiable(_results));
  }

  Future<void> _run({bool retry = false}) async {
    if (_query.text.trim().isEmpty) return;
    _operation?.cancel();
    _publish?.cancel();
    final op = _operation = MusicOperation(
      timeout: const Duration(minutes: 10),
      lane: 'search',
    );
    final port = ref.read(onlineBookPortProvider);
    op.onCancel(() => port.cancelSession(op.id));
    List<BookSource> sources;
    try {
      sources = retry
          ? List<BookSource>.from(_failed)
          : (await ref.read(
              enabledSourcesProvider.future,
            )).where((s) => s.bookSourceType == BookSourceType.audio).toList();
    } catch (e) {
      if (mounted && !op.cancelled)
        setState(() {
          _running = false;
          _error = e.toString();
        });
      return;
    }
    if (!mounted || op.cancelled) return;
    setState(() {
      if (!retry) {
        _results.clear();
        _visible = [];
      }
      _failed.clear();
      _done = 0;
      _total = sources.length;
      _running = true;
      _error = null;
    });
    final pending = List<BookSource>.from(sources), hosts = <String, int>{};
    final hostBySource = {
      for (final s in sources)
        s.bookSourceUrl: Uri.tryParse(s.bookSourceUrl)?.host ?? s.bookSourceUrl,
    };
    final query = _query.text.trim();
    Future<void> worker() async {
      while (pending.isNotEmpty && !op.cancelled) {
        final i = pending.indexWhere(
          (s) =>
              (EngineLimits.searchHostCap == 0 ||
              (hosts[hostBySource[s.bookSourceUrl]] ?? 0) <
                  EngineLimits.searchHostCap),
        );
        if (i < 0) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          continue;
        }
        final s = pending.removeAt(i);
        final host = hostBySource[s.bookSourceUrl]!;
        hosts[host] = (hosts[host] ?? 0) + 1;
        try {
          final books = await HttpSession.bind(
            op.id,
            () => port.search(s, query),
          );
          if (!mounted || op.cancelled) return;
          _results.addAll(
            books
                .where(
                  (b) =>
                      bookIdentityError(name: b.name, url: b.bookUrl) == null,
                )
                .map((b) => (s, b)),
          );
          if (_visible.isEmpty && _results.isNotEmpty) {
            _snapshot();
          } else {
            _publish ??= Timer(const Duration(milliseconds: 200), _snapshot);
          }
        } catch (e) {
          if (!op.cancelled) _failed.add(s);
        } finally {
          hosts[host] = hosts[host]! - 1;
        }
        if (!mounted || op.cancelled) return;
        setState(() => _done++);
      }
    }

    await Future.wait(
      List.generate(
        sources.length.clamp(0, EngineLimits.searchPool),
        (_) => worker(),
      ),
    );
    if (!mounted || op.cancelled) return;
    int score(SearchBook b) {
      final n = b.name.toLowerCase(), q = query.toLowerCase();
      return n == q
          ? 0
          : n.startsWith(q)
          ? 1
          : n.contains(q)
          ? 2
          : 3;
    }

    final scores = {for (final item in _results) item.$2: score(item.$2)};
    _results.sort((a, b) {
      final c = scores[a.$2]!.compareTo(scores[b.$2]!);
      return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
    });
    _snapshot();
    setState(() => _running = false);
  }

  void _cancel() {
    _operation?.cancel();
    _publish?.cancel();
    _snapshot();
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('搜索音频'),
      actions: [
        if (_running)
          IconButton(
            tooltip: '取消搜索',
            onPressed: _cancel,
            icon: const Icon(Icons.close),
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _query,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              labelText: '标题、主播或专辑',
              suffixIcon: IconButton(
                tooltip: '搜索',
                onPressed: _run,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        if (_running)
          LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
        Text('书源 $_done / $_total · ${_visible.length} 个结果'),
        if (_failed.isNotEmpty)
          TextButton(
            onPressed: _running ? null : () => _run(retry: true),
            child: Text('重试 ${_failed.length} 个失败书源'),
          ),
        if (_error != null) Text(_error!),
        Expanded(
          child: _visible.isEmpty && !_running
              ? const Center(child: Text('输入关键词搜索全部启用的音频书源'))
              : ListView.builder(
                  itemCount: _visible.length,
                  itemBuilder: (c, i) => MusicSearchTile(
                    source: _visible[i].$1,
                    book: _visible[i].$2,
                  ),
                ),
        ),
      ],
    ),
  );
}

class MusicSearchTile extends StatelessWidget {
  const MusicSearchTile({super.key, required this.source, required this.book});
  final BookSource source;
  final SearchBook book;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: MusicArtwork(url: book.coverUrl),
    title: Text(book.name),
    subtitle: Text('${book.author} · ${source.bookSourceName}'),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicAlbumScreen(
          source: source,
          seed: book.toBook()..type = BookType.audio,
        ),
      ),
    ),
  );
}

class MusicSourceExplore extends ConsumerStatefulWidget {
  const MusicSourceExplore({super.key, required this.source});
  final BookSource source;
  @override
  ConsumerState<MusicSourceExplore> createState() => _MusicSourceExploreState();
}

class _MusicSourceExploreState extends ConsumerState<MusicSourceExplore> {
  List<SearchBook> _books = [];
  List<ExploreKind> _kinds = [];
  String? _url, _error;
  int _page = 0;
  bool _busy = false, _more = true;
  @override
  void initState() {
    super.initState();
    _kinds = ExploreKind.parse(widget.source.exploreUrl);
    if (_kinds.isNotEmpty) {
      _url = _kinds.first.url;
      _load();
    }
  }

  Future<void> _load() async {
    if (_busy || _url == null || !_more) return;
    setState(() => _busy = true);
    try {
      final books = await ref
          .read(onlineBookPortProvider)
          .explore(widget.source, _url!, page: _page + 1);
      if (mounted) {
        setState(() {
          _books.addAll(books);
          _page++;
          _more = books.isNotEmpty;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.source.bookSourceName)),
    body: Column(
      children: [
        if (_kinds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _url,
              items: [
                for (final k in _kinds)
                  DropdownMenuItem(value: k.url, child: Text(k.title)),
              ],
              onChanged: (v) {
                setState(() {
                  _url = v;
                  _books = [];
                  _page = 0;
                  _more = true;
                });
                _load();
              },
            ),
          ),
        if (_kinds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('此书源未提供发现分类，请使用音频搜索'),
          ),
        if (_error != null) Text(_error!),
        Expanded(
          child: ListView.builder(
            itemCount: _books.length + 1,
            itemBuilder: (c, i) => i < _books.length
                ? MusicSearchTile(source: widget.source, book: _books[i])
                : Center(
                    child: TextButton(
                      onPressed: _busy || !_more ? null : _load,
                      child: Text(
                        _busy
                            ? '加载中…'
                            : _more
                            ? '加载更多'
                            : '已到末尾',
                      ),
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}

class MusicAlbumScreen extends ConsumerStatefulWidget {
  const MusicAlbumScreen({super.key, required this.source, required this.seed});
  final BookSource source;
  final Book seed;
  @override
  ConsumerState<MusicAlbumScreen> createState() => _MusicAlbumState();
}

class _MusicAlbumState extends ConsumerState<MusicAlbumScreen> {
  late Book _book;
  List<BookChapter> _chapters = [];
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _book = widget.seed;
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final port = ref.read(onlineBookPortProvider);
      final book = await port.loadBookInfo(widget.source, _book);
      book.type = BookType.audio;
      final chapters = await port.loadChapterList(widget.source, book);
      if (mounted) {
        setState(() {
          _book = book;
          _chapters = chapters;
          _trackSnapshot = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<MusicTrack>? _trackSnapshot;
  List<MusicTrack> get _tracks => _trackSnapshot ??= _chapters
      .asMap()
      .entries
      .map((entry) {
        final chapterIndex = entry.key;
        final ch = entry.value;
        return MusicTrack(
        url: '',
        title: ch.title,
        artist: _book.author,
        album: _book.name,
        coverUrl: _book.coverUrl,
        ref: TrackRef(
          id: TrackRef.identity(
            '${widget.source.bookSourceUrl}\u0000${_book.bookUrl}\u0000${ch.url}',
          ),
          origin: TrackOrigin.source,
          sourceId: widget.source.bookSourceUrl,
          book: _book.toJson(),
          chapter: ch.toJson(),
          nextChapterUrl: chapterIndex + 1 < _chapters.length
              ? _chapters[chapterIndex + 1].url
              : null,
          title: ch.title,
          artist: _book.author,
          album: _book.name,
        ),
      );
      })
      .toList(growable: false);
  @override
  Widget build(BuildContext context) {
    final services = ref.watch(musicServicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.name),
        actions: [
          IconButton(
            tooltip: '刷新目录',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        MusicArtwork(url: _book.coverUrl, size: 160),
                        Text(
                          _book.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(_book.author),
                        if (_book.intro?.isNotEmpty == true) Text(_book.intro!),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => musicAction(
                                context,
                                () => services.play(
                                  _tracks,
                                  resume: true,
                                  index: _book.durChapterIndex.clamp(
                                    0,
                                    (_tracks.length - 1).clamp(0, 1 << 30),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('继续播放'),
                            ),
                            TextButton(
                              onPressed: () => musicAction(
                                context,
                                () => services.play(_tracks),
                              ),
                              child: const Text('全部播放'),
                            ),
                            TextButton(
                              onPressed: () => musicAction(
                                context,
                                () => services.controller.addTracks(_tracks),
                              ),
                              child: const Text('加入队列'),
                            ),
                            TextButton(
                              onPressed: () => musicAction(
                                context,
                                () =>
                                    choosePlaylist(context, services, _tracks),
                              ),
                              child: const Text('加入播放列表'),
                            ),
                            TextButton(
                              onPressed: () => musicAction(
                                context,
                                () => services.downloads.enqueue(_tracks),
                              ),
                              child: const Text('批量下载'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (c, i) => ListTile(
                    leading: Text('${i + 1}'),
                    title: Text(_chapters[i].title),
                    onTap: () => musicAction(
                      context,
                      () => services.play(_tracks, index: i),
                    ),
                    trailing: MusicTrackMenu(
                      track: _tracks[i],
                      services: services,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
