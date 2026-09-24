import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/online/online_reading_use_cases.dart';
import '../../core/search/source_fanout.dart';
import '../../app/providers.dart';
import '../search/search_provider.dart';
import '../../core/search/search_schedule.dart';
import '../sources/source_library_provider.dart';

class ChangeSourceSheet extends ConsumerStatefulWidget {
  const ChangeSourceSheet({
    super.key,
    required this.bookName,
    required this.bookAuthor,
    required this.currentSourceUrl,
    required this.currentBookUrl,
    required this.seedBook,
  });

  final String bookName;
  final String bookAuthor;
  final String currentSourceUrl;
  final String currentBookUrl;
  final SearchBook seedBook;

  @override
  ConsumerState<ChangeSourceSheet> createState() => _ChangeSourceSheetState();
}

class _ChangeSourceSheetState extends ConsumerState<ChangeSourceSheet> {
  bool _loading = true;
  String? _error;
  var _done = 0;
  var _total = 0;
  var _token = 0;
  SearchOnlineBooksUseCase? _searchUseCase;
  Timer? _uiFlushTimer;
  final _hits = <(BookSource, SearchBook, int)>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_run);
  }

  @override
  void dispose() {
    _token++;
    _uiFlushTimer?.cancel();
    _uiFlushTimer = null;
    _searchUseCase?.cancel();
    super.dispose();
  }

  int _score(SearchBook b) {
    final byName = searchMatchScore(b, widget.bookName);
    if (byName >= 300) return byName;
    if (searchMatchRatio(b, widget.bookName) >= 0.5) {
      return 400;
    }
    final author = widget.bookAuthor.trim();
    if (author.length >= 2) {
      final byAuthor = searchMatchScore(b, author);
      if (byAuthor >= 520 &&
          normalizeSearchText(
            b.name,
          ).contains(normalizeSearchText(widget.bookName))) {
        return byAuthor;
      }
    }
    return byName;
  }

  bool _accept(SearchBook b) {
    if (!isUsableSearchBook(b, query: widget.bookName)) return false;
    return _score(b) >= 300;
  }

  SearchBook _copyForOrigin(SearchBook b, BookSource src, String url) {
    return SearchBook(
      bookUrl: url,
      origin: src.bookSourceUrl,
      originName: src.bookSourceName,
      type: b.type,
      name: b.name,
      author: b.author,
      kind: b.kind,
      coverUrl: b.coverUrl,
      intro: b.intro,
      wordCount: b.wordCount,
      latestChapterTitle: b.latestChapterTitle,
      tocUrl: b.tocUrl,
    );
  }

  void _consider(BookSource s, SearchBook b) {
    if (s.bookSourceUrl == widget.currentSourceUrl) return;
    if (b.bookUrl == widget.currentBookUrl) return;
    if (!_accept(b)) return;
    final sc = _score(b);
    final i = _hits.indexWhere((e) => e.$1.bookSourceUrl == s.bookSourceUrl);
    if (i >= 0) {
      if (sc > _hits[i].$3) _hits[i] = (s, b, sc);
      return;
    }
    _hits.add((s, b, sc));
  }

  Future<void> _run() async {
    final token = ++_token;
    final searchUseCase = ref.read(searchOnlineBooksUseCaseProvider);
    _searchUseCase = searchUseCase;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _done = 0;
        _total = 0;
        _hits.clear();
      });
    }
    try {
      final all = await ref.read(allSourcesProvider.future);
      if (!mounted || token != _token) return;
      final enabled = all
          .where((s) => s.enabled && s.hasSearch)
          .toList(growable: false);
      await SourceLatencyStore.ensureLoaded();
      SourceLatencyStore.applyTo(enabled);

      final byUrl = <String, BookSource>{
        for (final s in all) s.bookSourceUrl: s,
      };
      for (final origin in widget.seedBook.origins) {
        final src = byUrl[origin];
        if (src == null) continue;
        final url =
            widget.seedBook.originUrls[origin] ?? widget.seedBook.bookUrl;
        _consider(src, _copyForOrigin(widget.seedBook, src, url));
      }
      final session = ref.read(searchControllerProvider);
      final qn = normalizeSearchText(session.query);
      final kn = normalizeSearchText(widget.bookName);
      if (qn.isNotEmpty && (qn == kn || kn.contains(qn) || qn.contains(kn))) {
        for (final row in session.rows) {
          for (final b in row.books) {
            _consider(row.source, b);
          }
        }
      }
      for (final s in enabled) {
        final cached = SearchHitCache.instance.take(
          widget.bookName,
          1,
          s.bookSourceUrl,
        );
        if (cached == null) continue;
        for (final b in cached) {
          _consider(s, b);
        }
      }
      _hits.sort((a, b) => b.$3.compareTo(a.$3));
      if (mounted && token == _token) setState(() {});

      final already = <String>{
        widget.currentSourceUrl,
        for (final h in _hits) h.$1.bookSourceUrl,
      };
      final queue = orderSearchSources(
        enabled.where((s) => !already.contains(s.bookSourceUrl)).toList(),
      );
      if (!mounted || token != _token) return;
      await _searchSources(queue, token, searchUseCase);
      if (!mounted || token != _token) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _searchSources(
    List<BookSource> sources,
    int token,
    SearchOnlineBooksUseCase searchUseCase,
  ) async {
    if (sources.isEmpty) return;
    var completed = 0;
    var lastUi = DateTime.fromMillisecondsSinceEpoch(0);

    void publishUi({bool force = false}) {
      if (!mounted || token != _token) return;
      final now = DateTime.now();
      final elapsed = now.difference(lastUi);

      void apply() {
        _uiFlushTimer = null;
        if (!mounted || token != _token) return;
        _hits.sort((a, b) => b.$3.compareTo(a.$3));
        lastUi = DateTime.now();
        setState(() {
          _done = completed;
          _loading = true;
        });
      }

      if (force || elapsed >= const Duration(milliseconds: 120)) {
        _uiFlushTimer?.cancel();
        apply();
        return;
      }
      _uiFlushTimer ??= Timer(const Duration(milliseconds: 120), apply);
    }

    if (mounted && token == _token) {
      setState(() {
        _done = 0;
        _total = sources.length;
      });
    }
    await SourceFanout.run(
      sources: sources,
      query: widget.bookName,
      page: 1,
      search: (s) => searchUseCase(s, widget.bookName),
      isCancelled: () => !mounted || token != _token,
      // Do not delay the first live alternative on a platform preferences
      // hydration round-trip.  SourceFanout still waits for hydration before
      // flushing, so persisted entries cannot be lost or overwritten.
      waitForCache: false,
      // Change-source ranks every candidate by score and wants the best
      // alternative, so it scans all sources rather than stopping at a hit
      // threshold (its hit semantics also differ from the merged search view).
      earlyStop: false,
      onRow: (row) {
        if (!mounted || token != _token) return;
        for (final b in row.books) {
          _consider(row.source, b);
        }
        completed++;
        publishUi(force: completed >= sources.length);
      },
    );
    _uiFlushTimer?.cancel();
    _uiFlushTimer = null;
    if (mounted && token == _token) {
      _hits.sort((a, b) => b.$3.compareTo(a.$3));
      setState(() {
        _done = completed;
        _loading = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '换源 · ${widget.bookName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _run,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          if (_loading)
            LinearProgressIndicator(
              value: _total <= 0 ? null : (_done / _total).clamp(0, 1),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loading
                    ? '正在搜索 $_done / $_total · 命中 ${_hits.length}'
                    : (_hits.isEmpty ? '未找到可换书源' : '找到 ${_hits.length} 个源'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: _hits.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('未找到其它可换书源'),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _run,
                          child: const Text('再搜一次'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (context, i) {
                      final (s, b, sc) = _hits[i];
                      return ListTile(
                        title: Text(s.bookSourceName),
                        subtitle: Text(
                          b.name +
                              (b.author.isEmpty ? '' : ' · ${b.author}') +
                              (b.latestChapterTitle == null ||
                                      b.latestChapterTitle!.isEmpty
                                  ? ''
                                  : ' · ${b.latestChapterTitle!}'),
                        ),
                        trailing: sc >= 800
                            ? const Text('精确')
                            : Text(sc.toString()),
                        onTap: () => Navigator.of(context).pop((s, b)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
