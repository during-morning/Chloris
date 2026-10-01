import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../book_detail/cache_provider.dart';
import '../book_detail/chapter_text_cache.dart';
import '../../application/download/download_recovery.dart';
import '../sources/source_library_provider.dart';
import '../book_detail/book_detail_provider.dart';

class CacheManageScreen extends ConsumerStatefulWidget {
  const CacheManageScreen({super.key});

  @override
  ConsumerState<CacheManageScreen> createState() => _CacheManageScreenState();
}

class _CacheManageScreenState extends ConsumerState<CacheManageScreen> {
  Future<void> _resume(CacheJob job) async {
    try {
      final sources = await ref.read(allSourcesProvider.future);
      if (!mounted) return;
      final handler = resolvePersistedDownloadJob(
        metadata: job.metadata,
        bookName: job.bookName,
        sources: sources,
        content: ref.read(loadOnlineChapterContentUseCaseProvider),
      );
      if (handler == null) throw StateError('缺少恢复信息或书源，请从书籍详情重新下载');
      await ref
          .read(cacheJobsProvider.notifier)
          .resume(
            job,
            fetchChapter: handler.fetchChapter,
            hostOf: handler.hostOf,
          );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('恢复下载失败：$e')));
    }
  }

  @override
  void initState() {
    super.initState();
    ChapterTextCache.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(cacheJobsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('缓存管理'),
        actions: [
          TextButton(
            onPressed: () async {
              await ChapterTextCache.instance.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已清空正文缓存')));
              }
            },
            child: const Text('清空正文缓存'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(cacheJobsProvider.notifier).clearFinished(),
            child: const Text('清除已完成'),
          ),
          IconButton(
            tooltip: '复制缓存正文',
            onPressed: () async {
              final text = ChapterTextCache.instance.dumpAll();
              if (text.trim().isEmpty) return;
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制缓存正文')));
              }
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('正文缓存'),
            subtitle: Text(
              ChapterTextCache.instance.chapterCount.toString() +
                  ' 章 · 约 ' +
                  (ChapterTextCache.instance.approxBytes / 1024)
                      .toStringAsFixed(1) +
                  ' KB',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: jobs.isEmpty
                ? const Center(child: Text('没有下载任务。阅读过的章节会自动缓存；详情里也可「下载」。'))
                : ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, i) {
                      final j = jobs[jobs.length - 1 - i];
                      final total = j.total - j.fromIndex;
                      final v = total <= 0 ? 0.0 : j.done / total;
                      return ListTile(
                        title: Text(j.bookName),
                        trailing: j.running
                            ? TextButton(
                                onPressed: () => ref
                                    .read(cacheJobsProvider.notifier)
                                    .cancel(j),
                                child: const Text('取消'),
                              )
                            : j.hasPending
                            ? TextButton(
                                onPressed: () => _resume(j),
                                child: Text(j.failed > 0 ? '重试' : '继续'),
                              )
                            : null,
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (j.paused
                                      ? '已暂停 '
                                      : j.cancelled
                                      ? '已取消 '
                                      : j.running
                                      ? '进行中 '
                                      : '完成 ') +
                                  j.done.toString() +
                                  '/' +
                                  total.toString() +
                                  (j.failed > 0
                                      ? ' · 失败 ' + j.failed.toString()
                                      : ''),
                            ),
                            LinearProgressIndicator(value: v.clamp(0.0, 1.0)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
