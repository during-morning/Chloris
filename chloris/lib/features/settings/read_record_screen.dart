import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../book_detail/open_book.dart';
import '../library/online_shelf_provider.dart';
import '../local/local_book_provider.dart';
import 'read_record_provider.dart';

class ReadRecordScreen extends ConsumerWidget {
  const ReadRecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(readRecordProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('阅读记录'),
        actions: [
          IconButton(
            tooltip: '从剪贴板导入',
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final raw = data?.text;
              if (raw == null || raw.trim().isEmpty) return;
              try {
                final decoded = jsonDecode(raw);
                final out = <ReadRecord>[];
                if (decoded is List) {
                  for (final e in decoded) {
                    if (e is Map) {
                      out.add(
                        ReadRecord.fromJson(Map<String, dynamic>.from(e)),
                      );
                    }
                  }
                }
                ref.read(readRecordProvider.notifier).addAll(out);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已导入 ' + out.length.toString() + ' 条'),
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
          IconButton(
            tooltip: '复制 JSON',
            onPressed: () async {
              final json = const JsonEncoder.withIndent(
                '  ',
              ).convert(list.map((e) => e.toJson()).toList());
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制 ' + list.length.toString() + ' 条记录'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
          if (list.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(readRecordProvider.notifier).clear(),
              child: const Text('清空'),
            ),
        ],
      ),
      body: list.isEmpty
          ? const Center(child: Text('暂无阅读记录'))
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                final t = DateTime.fromMillisecondsSinceEpoch(r.time);
                return ListTile(
                  title: Text(r.bookName),
                  subtitle: Text(
                    r.chapterTitle +
                        ' · ' +
                        t.toLocal().toString().substring(0, 16),
                  ),
                  onTap: () {
                    for (final bundle in ref.read(localShelfProvider)) {
                      if (bundle.book.bookUrl == r.bookUrl) {
                        openLocalBook(context, ref, bundle);
                        return;
                      }
                    }
                    for (final item in ref.read(onlineShelfProvider)) {
                      if (item.bookUrl == r.bookUrl) {
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('该书不在书架，无法打开')),
                    );
                  },
                );
              },
            ),
    );
  }
}
