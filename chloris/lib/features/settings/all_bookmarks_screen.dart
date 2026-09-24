import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/bookmark_provider.dart';

class AllBookmarksScreen extends ConsumerWidget {
  const AllBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(bookmarkListProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('全部书签'),
        actions: [
          IconButton(
            tooltip: '复制 JSON',
            onPressed: () async {
              final json = const JsonEncoder.withIndent(
                '  ',
              ).convert(marks.map((e) => e.toJson()).toList());
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制 ' + marks.length.toString() + ' 条书签'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '从剪贴板导入',
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final raw = data?.text;
              if (raw == null || raw.trim().isEmpty) return;
              try {
                final decoded = jsonDecode(raw);
                final list = <Bookmark>[];
                if (decoded is List) {
                  for (final e in decoded) {
                    if (e is Map) {
                      list.add(Bookmark.fromJson(Map<String, dynamic>.from(e)));
                    }
                  }
                }
                ref.read(bookmarkListProvider.notifier).addAll(list);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已导入 ' + list.length.toString() + ' 条'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导入失败：' + e.toString())),
                  );
                }
              }
            },
            icon: const Icon(Icons.content_paste),
          ),
          if (marks.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(bookmarkListProvider.notifier).clear(),
              child: const Text('清空'),
            ),
        ],
      ),
      body: marks.isEmpty
          ? const Center(child: Text('暂无书签'))
          : ListView.builder(
              itemCount: marks.length,
              itemBuilder: (context, i) {
                final m = marks[i];
                return ListTile(
                  title: Text(m.bookName + ' · ' + m.chapterName),
                  subtitle: Text(m.content, maxLines: 2),
                  onLongPress: () =>
                      ref.read(bookmarkListProvider.notifier).removeAt(m.time),
                );
              },
            ),
    );
  }
}
