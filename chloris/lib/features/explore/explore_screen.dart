import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_icons.dart';
import '../../app/widgets/meow.dart';
import '../book_detail/open_book.dart';
import 'explore_controller.dart';
import '../sources/source_library_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  BookSource? _source;
  ExploreKind? _kind;
  int _page = 1;
  bool _loading = false;
  String? _error;
  List<SearchBook> _books = const [];
  String _sourceQ = '';
  String _bookQ = '';
  bool _restored = false;

  Future<void> _savePick() async {
    final p = await KvSettings.ready();
    if (_source != null) {
      await p.setString('exploreLastSource', _source!.bookSourceUrl);
    }
    if (_kind != null) {
      await p.setString('exploreLastKind', _kind!.title);
    }
  }

  Future<void> _restore(List<BookSource> list) async {
    if (_restored) return;
    _restored = true;
    final p = await KvSettings.ready();
    final url = p.getString('exploreLastSource');
    final kindTitle = p.getString('exploreLastKind');
    if (url == null || url.isEmpty) return;
    BookSource? hit;
    for (final s in list) {
      if (s.bookSourceUrl == url) {
        hit = s;
        break;
      }
    }
    if (hit == null || !mounted) return;
    ExploreKind? kind;
    final kinds = hit.exploreKinds;
    if (kindTitle != null) {
      for (final k in kinds) {
        if (k.title == kindTitle) {
          kind = k;
          break;
        }
      }
    }
    kind ??= kinds.isEmpty ? null : kinds.first;
    setState(() {
      _source = hit;
      _kind = kind;
    });
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final source = _source;
    final kind = _kind;
    if (source == null ||
        kind == null ||
        kind.url == null ||
        kind.url!.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = more ? _page + 1 : 1;
      final list = await exploreBooks(
        ref,
        source: source,
        url: kind.url!,
        page: page,
      );
      setState(() {
        _page = page;
        _books = more ? [..._books, ...list] : list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = _exploreError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sources = ref.watch(enabledExploreSourcesProvider);
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: '探索',
        title: '探索',
        subtitle: '按书源发现分类浏览。',
        actions: [
          MeowGhostButton(
            icon: AppIcons.copy,
            label: '复制列表',
            onPressed: () async {
              final json = const JsonEncoder.withIndent('  ').convert(
                _books
                    .map(
                      (b) => {
                        'name': b.name,
                        'author': b.author,
                        'bookUrl': b.bookUrl,
                        'originName': b.originName,
                        'latest': b.latestChapterTitle,
                      },
                    )
                    .toList(),
              );
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制 ' + _books.length.toString() + ' 条'),
                  ),
                );
              }
            },
          ),
        ],
        child: sources.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(_exploreError(e))),
          data: (list) {
            if (list.isEmpty) {
              return const MeowEmpty(
                title: '没有可发现的书源',
                body: '在「书源」里启用带发现地址的书源。',
              );
            }
            _source ??= list.first;
            final kinds = _source?.exploreKinds ?? const <ExploreKind>[];
            _kind ??= kinds.isEmpty ? null : kinds.first;
            Future.microtask(() => _restore(list));
            final filteredSources = _sourceQ.isEmpty
                ? list
                : list
                      .where(
                        (s) => s.bookSourceName.toLowerCase().contains(
                          _sourceQ.toLowerCase(),
                        ),
                      )
                      .toList();
            final shownBooks = _bookQ.isEmpty
                ? _books
                : _books
                      .where(
                        (b) =>
                            b.name.toLowerCase().contains(
                              _bookQ.toLowerCase(),
                            ) ||
                            b.author.toLowerCase().contains(
                              _bookQ.toLowerCase(),
                            ),
                      )
                      .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MeowQueryField(
                  hint: '筛选发现源',
                  onChanged: (v) => setState(() => _sourceQ = v.trim()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final s in filteredSources.take(60))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: MeowChip(
                            label: s.bookSourceName,
                            active: _source?.bookSourceUrl == s.bookSourceUrl,
                            onTap: () {
                              setState(() {
                                _source = s;
                                _kind = s.exploreKinds.isEmpty
                                    ? null
                                    : s.exploreKinds.first;
                                _books = const [];
                              });
                              _savePick();
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (kinds.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final k in kinds.take(30))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: MeowChip(
                              label: k.title,
                              active:
                                  _kind?.title == k.title &&
                                  _kind?.url == k.url,
                              onTap: () {
                                setState(() {
                                  _kind = k;
                                  _books = const [];
                                });
                                _savePick();
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (_books.isNotEmpty)
                  MeowQueryField(
                    hint: '筛选书名/作者',
                    leading: AppIcons.filter,
                    onChanged: (v) => setState(() => _bookQ = v.trim()),
                  ),
                if (_books.isNotEmpty) const SizedBox(height: 8),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: c.danger, fontSize: 13),
                    ),
                  ),
                Expanded(
                  child: _loading && _books.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _books.isEmpty
                      ? MeowEmpty(
                          title: '选择分类开始浏览',
                          body: '点上方书源和分类加载书籍（Web 经同源代理）。',
                          action: MeowPrimaryButton(
                            label: '加载',
                            onPressed: _load,
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 186,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                          itemCount: shownBooks.length + 1,
                          itemBuilder: (context, i) {
                            if (i == shownBooks.length) {
                              return Center(
                                child: MeowGhostButton(
                                  label: _loading ? '…' : '加载更多',
                                  onPressed: _loading
                                      ? null
                                      : () => _load(more: true),
                                ),
                              );
                            }
                            final b = shownBooks[i];
                            final src = _source!;
                            return GestureDetector(
                              onTap: () => openOnlineBook(
                                context,
                                ref,
                                source: src,
                                searchBook: b,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MeowCover(
                                    title: b.name,
                                    imageUrl: b.coverUrl,
                                    height: 160,
                                    source: src,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    b.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: c.ink,
                                    ),
                                  ),
                                  Text(
                                    b.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _exploreError(Object e) {
  final s = e.toString();
  if (s.contains('HandshakeException') ||
      s.contains('handshake') ||
      s.contains('CERTIFICATE')) {
    return '该站点安全连接失败，请换一个书源或分类。';
  }
  if (s.contains('TimeoutException') || s.contains('超时')) {
    return '站点超时，请重试或换源。';
  }
  if (s.contains('Failed host lookup') || s.contains('SocketException')) {
    return '无法连接该站点，请换源。';
  }
  return '加载失败，请换源或重试。';
}
