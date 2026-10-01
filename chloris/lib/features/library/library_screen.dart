import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_icons.dart';
import '../../app/widgets/absolutely_widgets.dart';
import '../../app/widgets/meow.dart';
import '../book_detail/open_book.dart';
import '../local/local_book_provider.dart';
import '../local/local_import_screen.dart';
import '../sources/source_library_provider.dart';
import 'book_cleanup.dart';
import 'book_health_screen.dart';
import 'library_provider.dart';
import 'online_shelf_provider.dart';
import 'reading_progress_provider.dart';

part 'library_book_card.dart';
part 'library_chrome.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _grid = true;
  bool _style2 = false;
  bool _selectMode = false;
  final Set<String> _selected = <String>{};
  String _q = '';
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  BookSource? _coverSource(Book book, List<BookSource> sources) {
    for (final item in ref.read(onlineShelfProvider)) {
      if (item.bookUrl == book.bookUrl) return item.source;
    }
    return sourceByOrigin(sources, book.origin);
  }

  @override
  void initState() {
    super.initState();
    () async {
      final kv = KvSettings.instance;
      final grid = await kv.getBool('libraryGrid');
      final style2 = await kv.getBool('libraryStyle2');
      final sort = await kv.getString('librarySort');
      final filter = await kv.getString('libraryFilter');
      if (!mounted) return;
      setState(() {
        _grid = grid ?? true;
        _style2 = style2 ?? false;
      });
      if (sort != null && sort.isNotEmpty) {
        ref.read(librarySortProvider.notifier).state = sort;
      }
      if (filter != null && filter.isNotEmpty) {
        ref.read(libraryFilterProvider.notifier).state = filter;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    ref.watch(pinnedUrlsProvider);
    ref.watch(onlineShelfProvider);
    final sources =
        ref.watch(allSourcesProvider).asData?.value ?? const <BookSource>[];
    final c = AppColors.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.paper,
      endDrawer: _style2 ? _style2Drawer(c) : null,
      body: books.when(
        loading: () => const MeowLoading(label: '正在加载书库'),
        error: (e, _) => MeowError(
          message: '加载失败：$e',
          onRetry: () => ref.invalidate(booksProvider),
        ),
        data: (list) {
          final items = _filterAndSort(list);
          return MeowPage(
            eyebrow: '书库',
            title: '书库',
            variant: MediaQuery.sizeOf(context).height < 240
                ? MeowPageVariant.compact
                : MeowPageVariant.largeTitle,
            fullBleedBody: true,
            actions: [
              MeowIconButton(
                icon: AppIcons.explore,
                tooltip: '书店 · 浏览在线书源',
                onPressed: () => context.go('/explore'),
              ),
              MeowIconButton(
                icon: _style2 ? AppIcons.viewList : AppIcons.menu,
                tooltip: _style2 ? '风格1 顶栏筛选' : '风格2 侧栏',
                onPressed: () {
                  setState(() => _style2 = !_style2);
                  KvSettings.instance.setBool('libraryStyle2', _style2);
                },
              ),
              if (_style2)
                MeowIconButton(
                  icon: AppIcons.filter,
                  tooltip: '筛选',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              MeowIconButton(
                icon: AppIcons.checkCircle,
                tooltip: '检查无效书籍',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookHealthScreen()),
                ),
              ),
              MeowIconButton(
                icon: AppIcons.copy,
                tooltip: '导出书架 JSON',
                onPressed: () async {
                  final books = await ref.read(booksProvider.future);
                  final json = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(books.map((b) => b.toJson()).toList());
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已复制 ${books.length} 本书')),
                    );
                  }
                },
              ),
              MeowIconButton(
                icon: AppIcons.add,
                tooltip: '导入本地书',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LocalImportScreen()),
                ),
              ),
              MeowIconButton(
                icon: _selectMode ? AppIcons.close : AppIcons.selectAll,
                tooltip: _selectMode ? '取消选择' : '选择',
                active: _selectMode,
                onPressed: () => setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selected.clear();
                }),
              ),
              if (_selectMode)
                MeowIconButton(
                  icon: AppIcons.delete,
                  tooltip: '删除所选',
                  onPressed: _deleteSelected,
                ),
            ],
            child: items.isEmpty
                ? MeowEmpty(
                    mark: '书',
                    title: '你的阅读空间',
                    body: '书库还没有书。导入 TXT / EPUB，或打开在线找书与书源探索。',
                    compact: true,
                    action: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        MeowPrimaryButton(
                          icon: AppIcons.add,
                          label: '导入本地书',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LocalImportScreen(),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/search'),
                          icon: const AppIcon(AppIcons.search, size: 17),
                          label: const Text('寻找在线书籍'),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/explore'),
                          icon: const AppIcon(AppIcons.explore, size: 17),
                          label: const Text('探索书源分类'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      MeowQueryField(
                        hint: '搜索书架',
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                      const SizedBox(height: 10),
                      if (!_style2) _toolbar(c),
                      _recentRow(list, c),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final progress = ref.watch(readingProgressProvider);
                            String? progLine(Book book) {
                              final p = progress[book.bookUrl];
                              if (p == null) return null;
                              if (p.chapterTitle.isNotEmpty) {
                                return '读到 · ${p.chapterTitle}';
                              }
                              if (p.chapterIndex > 0) {
                                return '读到第 ${p.chapterIndex + 1} 章';
                              }
                              return null;
                            }

                            return _grid
                                ? GridView.builder(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 186,
                                          childAspectRatio: 0.52,
                                          crossAxisSpacing: 18,
                                          mainAxisSpacing: 30,
                                        ),
                                    itemCount: items.length,
                                    itemBuilder: (context, i) => _BookCard(
                                      book: items[i],
                                      source: _coverSource(items[i], sources),
                                      progress: progLine(items[i]),
                                      selectMode: _selectMode,
                                      selected: _selected.contains(
                                        items[i].bookUrl,
                                      ),
                                      onTap: () => _onBookTap(items[i]),
                                      onSelect: () =>
                                          _toggleSelect(items[i].bookUrl),
                                      onLongPress: () =>
                                          _onBookLongPress(items[i]),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 7),
                                    itemBuilder: (context, i) {
                                      final book = items[i];
                                      final pl = progLine(book);
                                      return InkWell(
                                        onTap: () => _onBookTap(book),
                                        onLongPress: () =>
                                            _onBookLongPress(book),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: c.panel,
                                            border: Border.all(color: c.line),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 46,
                                                child: MeowCover(
                                                  title: book.name,
                                                  imageUrl: book.coverUrl,
                                                  height: 46,
                                                  source: _coverSource(
                                                    book,
                                                    sources,
                                                  ),
                                                  book: book,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      book.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: c.ink,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      pl ?? book.author,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: c.muted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (_selectMode)
                                                Icon(
                                                  _selected.contains(
                                                        book.bookUrl,
                                                      )
                                                      ? AppIcons.checkCircle
                                                      : Icons
                                                            .radio_button_unchecked,
                                                  color:
                                                      _selected.contains(
                                                        book.bookUrl,
                                                      )
                                                      ? c.accent
                                                      : c.muted,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                          },
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
