part of 'reader_screen.dart';

extension _ReaderActions on _ReaderScreenState {
  void _toggleDayNight() {
    applyThemeMode(ref, flipThemeMode(ref.read(themeModeProvider)));
  }

  void _showKeys() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('阅读快捷键'),
        content: const Text(
          '↑ / W / PageUp  上一页（滚动模式为上滚）\n'
          '↓ / S / PageDown / 空格  下一页（滚动模式为下滚）\n'
          '← / A  上一章\n'
          '→ / D  下一章\n'
          'Esc  显隐阅读栏\n'
          '点中央或屏幕上下边缘可重新拉起阅读栏',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    final clip = widget.content.length > 80
        ? widget.content.substring(0, 80)
        : widget.content;
    ref.read(bookmarkListProvider.notifier).add(
          Bookmark(
            time: DateTime.now().millisecondsSinceEpoch,
            bookName: widget.bookTitle ?? '',
            bookAuthor: widget.bookAuthor,
            chapterIndex: widget.chapterIndex,
            chapterPos: _page,
            chapterName: widget.chapterTitle,
            content: clip,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加书签')),
    );
  }

  Future<void> _searchInChapter(int total) async {
    final ctrl = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本章搜索'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '关键词'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    if (q == null || q.trim().isEmpty || !mounted) return;
    final key = q.trim();
    final hits = <int>[];
    var from = 0;
    final lower = widget.content.toLowerCase();
    final k = key.toLowerCase();
    while (true) {
      final at = lower.indexOf(k, from);
      if (at < 0) break;
      hits.add(at);
      from = at + k.length;
      if (hits.length > 50) break;
    }
    if (hits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到')),
      );
      return;
    }
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('共 ' + hits.length.toString() + ' 处'),
        content: SizedBox(
          width: 360,
          height: 320,
          child: ListView.builder(
            itemCount: hits.length,
            itemBuilder: (c, i) {
              final pos = hits[i];
              final a = (pos - 12).clamp(0, widget.content.length);
              final b = (pos + key.length + 12).clamp(0, widget.content.length);
              return ListTile(
                dense: true,
                title: Text(widget.content.substring(a, b)),
                onTap: () => Navigator.pop(ctx, pos),
              );
            },
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ratio = picked / widget.content.length;
    setState(() => _page = (ratio * (total - 1)).round().clamp(0, total - 1));
    if (_scroll.hasClients) {
      _scroll.jumpTo(ratio * _scroll.position.maxScrollExtent);
    }
  }
}
