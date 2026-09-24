part of 'library_screen.dart';

extension _LibraryChrome on _LibraryScreenState {
  Widget _style2Drawer(AppColors c) {
    final filter = ref.watch(libraryFilterProvider);
    final sort = ref.watch(librarySortProvider);
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('书架 · 风格2')),
            const Divider(),
            RadioListTile<String>(
              title: const Text('全部'),
              value: 'all',
              groupValue: filter,
              onChanged: (v) {
                if (v != null) _setFilter(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('在读'),
              value: 'reading',
              groupValue: filter,
              onChanged: (v) {
                if (v != null) _setFilter(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('本地'),
              value: 'local',
              groupValue: filter,
              onChanged: (v) {
                if (v != null) _setFilter(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('在线'),
              value: 'online',
              groupValue: filter,
              onChanged: (v) {
                if (v != null) _setFilter(v);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            const ListTile(title: Text('排序')),
            RadioListTile<String>(
              title: const Text('最近更新'),
              value: 'latest',
              groupValue: sort,
              onChanged: (v) {
                if (v == null) return;
                ref.read(librarySortProvider.notifier).state = v;
                KvSettings.instance.setString('librarySort', v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('书名'),
              value: 'name',
              groupValue: sort,
              onChanged: (v) {
                if (v == null) return;
                ref.read(librarySortProvider.notifier).state = v;
                KvSettings.instance.setString('librarySort', v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('作者'),
              value: 'author',
              groupValue: sort,
              onChanged: (v) {
                if (v == null) return;
                ref.read(librarySortProvider.notifier).state = v;
                KvSettings.instance.setString('librarySort', v);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(AppColors c) {
    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          MeowChip(
            label: '全部',
            active: ref.watch(libraryFilterProvider) == 'all',
            onTap: () => _setFilter('all'),
          ),
          const SizedBox(width: 6),
          MeowChip(
            label: '在读',
            icon: const Icon(Icons.auto_stories_outlined, size: 16),
            active: ref.watch(libraryFilterProvider) == 'reading',
            onTap: () => _setFilter('reading'),
          ),
          const SizedBox(width: 6),
          MeowChip(
            label: '本地',
            icon: const Icon(Icons.book_outlined, size: 16),
            active: ref.watch(libraryFilterProvider) == 'local',
            onTap: () => _setFilter('local'),
          ),
          const SizedBox(width: 6),
          MeowChip(
            label: '在线',
            icon: const Icon(Icons.cloud_outlined, size: 16),
            active: ref.watch(libraryFilterProvider) == 'online',
            onTap: () => _setFilter('online'),
          ),
          const SizedBox(width: 6),
          MeowChip(
            label: '分组',
            active: ref.watch(libraryFilterProvider).startsWith('group:'),
            onTap: () => _pickGroupFilter(),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            initialValue: ref.watch(librarySortProvider),
            onSelected: (v) {
              ref.read(librarySortProvider.notifier).state = v;
              KvSettings.instance.setString('librarySort', v);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'latest', child: Text('最近更新')),
              PopupMenuItem(value: 'name', child: Text('书名')),
              PopupMenuItem(value: 'author', child: Text('作者')),
              PopupMenuItem(value: 'order', child: Text('自定义顺序')),
            ],
            child: MeowChip(label: '排序', active: true),
          ),
          const SizedBox(width: 6),
          MeowIconButton(
            icon: _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
            onPressed: () {
              setState(() => _grid = !_grid);
              KvSettings.instance.setBool('libraryGrid', _grid);
            },
            tooltip: _grid ? '列表' : '网格',
          ),
        ],
      ),
    );
  }
  List<Book> _filterAndSort(List<Book> list) {
    final filter = ref.read(libraryFilterProvider);
    var out = list;
    if (_q.isNotEmpty) {
      final k = _q.toLowerCase();
      out = out
          .where((b) =>
              b.name.toLowerCase().contains(k) ||
              b.author.toLowerCase().contains(k))
          .toList();
    }
    if (filter == 'reading') {
      final prog = ref.read(readingProgressProvider);
      out = out
          .where((b) =>
              b.durChapterIndex > 0 ||
              (prog[b.bookUrl]?.chapterIndex ?? 0) > 0)
          .toList();
    } else if (filter == 'local') {
      // `Book.isLocal` keys off the type bit flag (like Legado's `type &
      // local`) and also covers `webDav::` origins. Comparing `origin` against
      // the local tag directly both ignored the flag and filed WebDAV-backed
      // books under "online".
      out = out.where((b) => b.isLocal).toList();
    } else if (filter == 'online') {
      out = out.where((b) => !b.isLocal).toList();
    } else if (filter.startsWith('group:')) {
      // group:<id> = 分组成员；group:0 = 未分组
      final id = int.tryParse(filter.substring(6)) ?? -1;
      final bits = ref.read(bookGroupMapProvider);
      out = id <= 0
          ? out.where((b) => (bits[b.bookUrl] ?? 0) == 0).toList()
          : out.where((b) => (bits[b.bookUrl] ?? 0) & (1 << id) != 0).toList();
    }
    final pinned = ref.read(pinnedUrlsProvider);
    final sort = ref.read(librarySortProvider);
    switch (sort) {
      case 'name':
        out.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'author':
        out.sort((a, b) => a.author.compareTo(b.author));
        break;
      case 'order':
        out.sort((a, b) => a.order.compareTo(b.order));
        break;
      default:
        out.sort((a, b) => (b.latestChapterTime ?? 0).compareTo(a.latestChapterTime ?? 0));
    }
    if (pinned.isNotEmpty) {
      out.sort((a, b) {
        final pa = pinned.contains(a.bookUrl) ? 0 : 1;
        final pb = pinned.contains(b.bookUrl) ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        return 0;
      });
    }
    return out;
  }

  /// Removes a book from the shelf *and* every piece of state derived from it.
  ///
  /// The chapter text cache is keyed by `<sourceUrl>|<chapterUrl>`, and one
  /// source hosts many books, so the source URL has to be resolved from the
  /// shelf entry rather than guessed from the book.
  Future<void> _purgeBook({
    required String bookUrl,
    required String name,
    required String author,
    required String sourceUrl,
  }) async {
    ref.read(pinnedUrlsProvider.notifier).unpin(bookUrl);
    await ref.read(bookCleanupProvider).cleanBook(
          bookUrl: bookUrl,
          name: name,
          author: author,
          sourceUrl: sourceUrl,
        );
    ref.read(onlineShelfProvider.notifier).remove(bookUrl);
    ref.read(localShelfProvider.notifier).remove(bookUrl);
  }

  Future<void> _deleteBook(Book book) async {
    var sourceUrl = book.origin;
    for (final item in ref.read(onlineShelfProvider)) {
      if (item.bookUrl == book.bookUrl) {
        sourceUrl = item.source.bookSourceUrl;
        break;
      }
    }
    await _purgeBook(
      bookUrl: book.bookUrl,
      name: book.name,
      author: book.author,
      sourceUrl: sourceUrl,
    );
  }

  /// Resolves the book identity a bare `bookUrl` needs for cleanup. Selection
  /// mode only carries URLs, but bookmarks are keyed by name+author.
  Future<void> _deleteByUrl(String url) async {
    var name = '';
    var author = '';
    var sourceUrl = '';
    for (final item in ref.read(onlineShelfProvider)) {
      if (item.bookUrl == url) {
        name = item.searchBook.name;
        author = item.searchBook.author;
        sourceUrl = item.source.bookSourceUrl;
        break;
      }
    }
    if (sourceUrl.isEmpty) {
      for (final bundle in ref.read(localShelfProvider)) {
        if (bundle.book.bookUrl == url) {
          name = bundle.book.name;
          author = bundle.book.author;
          sourceUrl = bundle.book.origin;
          break;
        }
      }
    }
    await _purgeBook(
      bookUrl: url,
      name: name,
      author: author,
      sourceUrl: sourceUrl,
    );
  }

  void _onBookLongPress(Book book) {
    final pinned = ref.read(pinnedUrlsProvider).contains(book.bookUrl);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('书籍详情 / 目录'),
              onTap: () {
                Navigator.pop(ctx);
                for (final bundle in ref.read(localShelfProvider)) {
                  if (bundle.book.bookUrl == book.bookUrl) {
                    openLocalBook(context, ref, bundle, forceToc: true);
                    return;
                  }
                }
                for (final item in ref.read(onlineShelfProvider)) {
                  if (item.bookUrl == book.bookUrl) {
                    openOnlineBook(
                      context,
                      ref,
                      source: item.source,
                      searchBook: item.searchBook,
                      forceDetail: true,
                    );
                    return;
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                pinned ? Icons.vertical_align_bottom : Icons.vertical_align_top,
              ),
              title: Text(pinned ? '取消置顶' : '置顶'),
              onTap: () {
                if (pinned) {
                  ref.read(pinnedUrlsProvider.notifier).unpin(book.bookUrl);
                } else {
                  ref.read(pinnedUrlsProvider.notifier).pin(book.bookUrl);
                  ref.read(onlineShelfProvider.notifier).top(book.bookUrl);
                  ref.read(localShelfProvider.notifier).top(book.bookUrl);
                }
                Navigator.pop(ctx);
              },
            ),
            Consumer(
              builder: (sheetCtx, sheetRef, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final g in sheetRef.watch(bookGroupsProvider))
                    ListTile(
                      leading: Icon(
                        sheetRef.watch(bookGroupMapProvider).containsKey(
                                  book.bookUrl,
                                ) &&
                            (sheetRef
                                        .watch(bookGroupMapProvider)[
                                    book.bookUrl] ??
                                0) &
                                (1 << g.id) !=
                                0
                            ? Icons.folder_special
                            : Icons.folder_outlined,
                      ),
                      title: Text(g.name),
                      onTap: () => sheetRef
                          .read(bookGroupMapProvider.notifier)
                          .toggle(book.bookUrl, g.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('新建分组并加入'),
                    onTap: () async {
                      final name = await _promptGroupName(ctx);
                      if (name == null || name.trim().isEmpty) return;
                      await ref.read(bookGroupsProvider.notifier).addGroup(name);
                      final groups = ref.read(bookGroupsProvider);
                      final hit = groups.where((g) => g.name == name.trim());
                      if (hit.isNotEmpty) {
                        await sheetRef
                            .read(bookGroupMapProvider.notifier)
                            .toggle(book.bookUrl, hit.first.id);
                      }
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                _deleteBook(book);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentRow(List<Book> list, AppColors c) {
    final prog = ref.watch(readingProgressProvider);
    if (prog.isEmpty) return const SizedBox.shrink();
    final byUrl = {for (final b in list) b.bookUrl: b};
    final recent = prog.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final shown = <Book>[];
    for (final p in recent) {
      final b = byUrl[p.bookUrl];
      if (b != null) shown.add(b);
      if (shown.length >= 8) break;
    }
    if (shown.isEmpty) return const SizedBox.shrink();
    final absolutely = Theme.of(context).extension<AppStyleExtension>()?.style ==
        AppUiStyle.absolutely;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              // Absolutely: the recent shelf opens with a specimen tag —
              // the "fig." plate label from the style book (§8 式二).
              child: absolutely
                  ? AbsolutelySpecimenTag(label: '最近 · ${shown.length}')
                  : Text(
                      '最近',
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
            ),
            for (final b in shown)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () => _onBookTap(b),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onBookTap(Book book) {
    if (_selectMode) {
      _toggleSelect(book.bookUrl);
      return;
    }
    for (final bundle in ref.read(localShelfProvider)) {
      if (bundle.book.bookUrl == book.bookUrl) {
        openLocalBook(context, ref, bundle);
        return;
      }
    }
    for (final item in ref.read(onlineShelfProvider)) {
      if (item.bookUrl == book.bookUrl) {
        openOnlineBook(
          context,
          ref,
          source: item.source,
          searchBook: item.searchBook,
          directRead: true,
        );
        return;
      }
    }
  }

  Future<void> _deleteSelected() async {
    final urls = _selected.toList();
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    for (final url in urls) {
      await _deleteByUrl(url);
    }
  }

  void _setFilter(String v) {
    ref.read(libraryFilterProvider.notifier).state = v;
    KvSettings.instance.setString('libraryFilter', v);
  }

  /// 分组筛选弹层：未分组 / 各分组 / 新建分组 / 清除筛选。
  Future<void> _pickGroupFilter() async {
    final groups = ref.read(bookGroupsProvider);
    final current = ref.read(libraryFilterProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in groups)
              ListTile(
                leading: Icon(
                  current == 'group:${g.id}'
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank_outlined,
                ),
                title: Text(g.name),
                onTap: () {
                  _setFilter(
                    current == 'group:${g.id}' ? 'all' : 'group:${g.id}',
                  );
                  Navigator.pop(ctx);
                },
              ),
            if (groups.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.filter_alt_off_outlined),
                title: const Text('未分组'),
                onTap: () {
                  _setFilter('group:0');
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建分组'),
              onTap: () async {
                final name = await _promptGroupName(ctx);
                if (name != null && name.trim().isNotEmpty) {
                  await ref.read(bookGroupsProvider.notifier).addGroup(name);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptGroupName(BuildContext ctx) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _toggleSelect(String url) {
    setState(() {
      if (_selected.contains(url)) {
        _selected.remove(url);
      } else {
        _selected.add(url);
      }
    });
  }

}
