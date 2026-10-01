import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chloris/application/download/download_use_cases.dart';
import 'package:chloris/features/book_detail/cache_provider.dart';

void main() {
  test('快速取消再恢复等待旧请求退出，不重复启动旧任务', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cacheJobsProvider.notifier);
    await notifier.restored;
    final entered = Completer<void>(), release = Completer<void>();
    var oldCalls = 0, resumedCalls = 0;
    final initial = notifier.enqueue(
      bookName: '取消恢复',
      fromIndex: 0,
      total: 1,
      fetchChapter: (_) async {
        oldCalls++;
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    final job = notifier.state.single;
    notifier.cancel(job);
    final resumed = notifier.resume(
      job,
      fetchChapter: (_) async {
        resumedCalls++;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(resumedCalls, 0);
    release.complete();
    await Future.wait([initial, resumed]);
    expect(oldCalls, 1);
    expect(resumedCalls, 1);
    expect(job.completedIndexes, {0});
    expect(job.running, false);
  });

  test('恢复多本书同时调度，受共享队列约束', () async {
    SharedPreferences.setMockInitialValues({
      'cacheJobsV1': jsonEncode(
        List.generate(
          2,
          (i) => CacheJob(
            id: 'parallel-$i',
            bookName: '并行$i',
            fromIndex: 0,
            total: 1,
            running: false,
            paused: true,
          ).toJson(),
        ),
      ),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cacheJobsProvider.notifier);
    await notifier.restored;
    var active = 0, peak = 0;
    expect(
      await notifier.resumePending(
        resolve: (_) async => DownloadResumeHandler(
          fetchChapter: (_) async {
            active++;
            if (active > peak) peak = active;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            active--;
          },
        ),
      ),
      2,
    );
    expect(peak, 2);
    expect(notifier.state.every((j) => j.pendingCount == 0), true);
  });
  test('缓存任务序列化保留成功、失败和暂停状态', () {
    final original = CacheJob(
      id: 'job-1',
      createdAt: 42,
      bookName: '测试书',
      fromIndex: 2,
      total: 8,
      done: 4,
      failed: 1,
      running: false,
      paused: true,
      completedIndexes: {2, 3, 5},
      failedIndexes: {4},
    );

    final restored = CacheJob.fromJson(original.toJson());

    expect(restored.id, 'job-1');
    expect(restored.createdAt, 42);
    expect(restored.bookName, '测试书');
    expect(restored.fromIndex, 2);
    expect(restored.total, 8);
    expect(restored.done, 4);
    expect(restored.failed, 1);
    expect(restored.paused, isTrue);
    expect(restored.completedIndexes, {2, 3, 5});
    expect(restored.failedIndexes, {4});
  });

  test('缓存任务序列化保留书源、书籍和章节恢复元数据', () {
    final original = CacheJob(
      id: 'job-with-metadata',
      bookName: '恢复书',
      fromIndex: 1,
      total: 4,
      running: false,
      paused: true,
      completedIndexes: {1},
      metadata: const BatchDownloadMetadata(
        sourceId: 'https://source.example',
        bookUrl: 'https://source.example/book',
        tocUrl: 'https://source.example/toc',
        chapters: [
          BatchDownloadChapterRef(
            index: 1,
            title: '第一章',
            url: 'https://source.example/chapter/1',
            baseUrl: 'https://source.example',
          ),
        ],
      ),
    );

    final restored = CacheJob.fromJson(original.toJson());

    expect(restored.metadata?.sourceId, 'https://source.example');
    expect(restored.metadata?.bookUrl, 'https://source.example/book');
    expect(restored.metadata?.tocUrl, 'https://source.example/toc');
    expect(restored.metadata?.chapters.single.title, '第一章');
    expect(restored.metadata?.chapters.single.url, contains('/chapter/1'));
    expect(restored.pendingIndexes.toList(), [2, 3]);
    expect(restored.pendingCount, 2);
    expect(restored.metadata?.canResolve, isTrue);
  });

  test('恢复 API 只对解析成功的任务注入新闭包并发出状态事件', () async {
    final persisted = CacheJob(
      id: 'pending-job',
      bookName: '待恢复书',
      fromIndex: 0,
      total: 2,
      running: true,
      metadata: const BatchDownloadMetadata(
        sourceId: 'source-id',
        bookUrl: 'book-id',
      ),
    );
    SharedPreferences.setMockInitialValues({
      'cacheJobsV1': jsonEncode([persisted.toJson()]),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cacheJobsProvider.notifier);
    final events = <CacheJobEvent>[];
    final subscription = notifier.events.listen(events.add);
    addTearDown(subscription.cancel);

    for (var i = 0; i < 20 && notifier.state.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(notifier.state.single.paused, isTrue);
    expect(notifier.pendingJobs.single.metadata?.bookUrl, 'book-id');

    final fetched = <int>[];
    final resumed = await notifier.resumePending(
      resolve: (job) async {
        expect(job.id, 'pending-job');
        return DownloadResumeHandler(
          fetchChapter: (index) async => fetched.add(index),
        );
      },
    );

    expect(resumed, 1);
    expect(fetched.toSet(), {0, 1});
    expect(notifier.state.single.pendingCount, 0);
    expect(notifier.state.single.completedIndexes, {0, 1});
    await Future<void>.delayed(Duration.zero);
    expect(
      events.map((event) => event.type),
      containsAllInOrder([
        CacheJobEventType.restored,
        CacheJobEventType.resumed,
        CacheJobEventType.started,
        CacheJobEventType.progress,
        CacheJobEventType.completed,
      ]),
    );
  });

  test('restored future completes after SharedPreferences snapshot', () async {
    SharedPreferences.setMockInitialValues({
      'cacheJobsV1': jsonEncode([
        CacheJob(
          id: 'wait-restore',
          bookName: '等待恢复',
          fromIndex: 0,
          total: 1,
          running: true,
        ).toJson(),
      ]),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(cacheJobsProvider.notifier);
    await notifier.restored;
    expect(notifier.state, isNotEmpty);
    expect(notifier.state.single.paused, isTrue);
  });
}
