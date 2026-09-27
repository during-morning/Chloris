import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/meow.dart';
import '../reader/bookmark_provider.dart';

/// Shared chapter / bookmark panel used by TocPage and the reader drawer.
class ChapterTocPanel extends ConsumerStatefulWidget {
  const ChapterTocPanel({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onOpenChapter,
    this.bookName = '',
    this.bookAuthor = '',
    this.onClose,
    this.foreground,
    this.background,
    this.embedded = false,
  });

  final List<BookChapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onOpenChapter;
  final String bookName;
  final String bookAuthor;
  final VoidCallback? onClose;
  final Color? foreground;
  final Color? background;
  final bool embedded;

  @override
  ConsumerState<ChapterTocPanel> createState() => _ChapterTocPanelState();
}

class _ChapterTocPanelState extends ConsumerState<ChapterTocPanel> {
  String _q = '';
  bool _rev = false;
  final _scroll = ScrollController();
  bool _didJump = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<MapEntry<int, BookChapter>> get _list {
    final query = _q.trim().toLowerCase();
    var list = widget.chapters
        .asMap()
        .entries
        .where((e) => query.isEmpty || e.value.title.toLowerCase().contains(query))
        .toList();
    if (_rev) list = list.reversed.toList();
    return list;
  }

  void _jump(List<MapEntry<int, BookChapter>> list) {
    if (_didJump || !_scroll.hasClients) return;
    final i = list.indexWhere((e) => e.key == widget.currentIndex);
    _didJump = true;
    if (i <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final offset =
          (i * AppTokens.tocItemExtent).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.foreground ?? cs.onSurface;
    final bg = widget.background ?? cs.surface;
    final list = _list;
    final marks = ref
        .watch(bookmarkListProvider)
        .where((b) =>
            b.bookName == widget.bookName && b.bookAuthor == widget.bookAuthor)
        .toList();

    final body = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          ListTile(
            title: Text(
              '目录 · 共 ${widget.chapters.length} 章',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '当前 ${(widget.currentIndex + 1).clamp(1, widget.chapters.isEmpty ? 1 : widget.chapters.length)}',
              style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _rev ? '正序' : '倒序',
                  onPressed: () => setState(() {
                    _rev = !_rev;
                    _didJump = false;
                  }),
                  icon: Icon(
                    _rev ? Icons.arrow_upward : Icons.arrow_downward,
                    color: fg,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: Icon(Icons.close, color: fg),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space12,
              0,
              AppTokens.space12,
              AppTokens.space8,
            ),
            child: MeowQueryField(
              hint: '筛选章节',
              onChanged: (v) => setState(() {
                _q = v;
                _didJump = false;
              }),
            ),
          ),
          TabBar(
            labelColor: fg,
            unselectedLabelColor: fg.withValues(alpha: 0.5),
            tabs: const [Tab(text: '章节'), Tab(text: '书签')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  controller: _scroll,
                  physics: const ClampingScrollPhysics(),
                  itemExtent: AppTokens.tocItemExtent,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    if (i == 0) _jump(list);
                    final e = list[i];
                    final selected = e.key == widget.currentIndex;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.6),
                      title: Text(
                        e.value.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      onTap: () => widget.onOpenChapter(e.key),
                    );
                  },
                ),
                marks.isEmpty
                    ? Center(child: Text('暂无书签', style: TextStyle(color: fg)))
                    : ListView.builder(
                        itemExtent: AppTokens.listTileComfort,
                        itemCount: marks.length,
                        itemBuilder: (context, i) {
                          final m = marks[i];
                          return ListTile(
                            title: Text(m.chapterName, style: TextStyle(color: fg)),
                            subtitle: Text(
                              m.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg.withValues(alpha: 0.6)),
                            ),
                            onTap: () => widget.onOpenChapter(m.chapterIndex),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: bg, child: SafeArea(child: body));
    }
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(child: body),
    );
  }
}
