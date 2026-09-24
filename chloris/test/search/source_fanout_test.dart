import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chloris/core/search/source_fanout.dart';
import 'package:chloris/features/search/search_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认搜索会完成全部源，不因命中数提前停在前十五个', () async {
    SharedPreferences.setMockInitialValues({});
    final sources = [
      for (var i = 0; i < 40; i++)
        BookSource(
          // All entries share one host so the host-cap queue is exercised too.
          bookSourceUrl: 'https://full-scan.example/source/$i',
          bookSourceName: '全量源 $i',
          searchUrl: 'https://full-scan.example/search',
        ),
    ];
    final rows = <SourceSearchResult>[];

    // earlyStop disabled: the fanout must still complete every source. The
    // early-stop path is covered by the dedicated test below.
    final stoppedEarly = await SourceFanout.run(
      sources: sources,
      query: '全量扫描',
      page: 1,
      search: (source) async => [
        SearchBook(
          name: '全量扫描结果',
          author: '测试作者',
          bookUrl: '${source.bookSourceUrl}/book',
          origin: source.bookSourceUrl,
          originName: source.bookSourceName,
        ),
      ],
      isCancelled: () => false,
      earlyStop: false,
      onRow: rows.add,
    );

    expect(stoppedEarly, isFalse);
    expect(rows, hasLength(sources.length));
    expect(
      rows.map((row) => row.source.bookSourceUrl).toSet(),
      hasLength(sources.length),
    );
  });

  test('命中数达到阈值后停止发起剩余源，且已发出请求仍归并完成', () async {
    SharedPreferences.setMockInitialValues({});
    final prevHits = EngineLimits.searchEarlyStopHits;
    EngineLimits.searchEarlyStopHits = 8;
    addTearDown(() => EngineLimits.searchEarlyStopHits = prevHits);

    // 40 sources, each returns 1 usable book. With a pool of 1 we get
    // deterministic stopping once 8 hits have been delivered.
    final sources = [
      for (var i = 0; i < 40; i++)
        BookSource(
          bookSourceUrl: 'https://early.example/source/$i',
          bookSourceName: '早停源 $i',
          searchUrl: 'https://early.example/search',
        ),
    ];
    final prevPool = EngineLimits.searchPool;
    final prevHostCap = EngineLimits.searchHostCap;
    EngineLimits.searchPool = 1;
    EngineLimits.searchHostCap = 0;
    addTearDown(() {
      EngineLimits.searchPool = prevPool;
      EngineLimits.searchHostCap = prevHostCap;
    });

    final rows = <SourceSearchResult>[];
    final stoppedEarly = await SourceFanout.run(
      sources: sources,
      query: '早停',
      page: 1,
      search: (source) async => [
        SearchBook(
          name: '早停结果',
          author: '作者',
          bookUrl: '${source.bookSourceUrl}/book',
          origin: source.bookSourceUrl,
          originName: source.bookSourceName,
        ),
      ],
      isCancelled: () => false,
      onRow: rows.add,
    );

    expect(stoppedEarly, isTrue);
    // Fewer than the full 40 sources were launched.
    expect(rows.length, lessThan(sources.length));
    // Every delivered row must still carry its results (no dropped output).
    expect(rows.every((r) => r.books.isNotEmpty), isTrue);
  });

  test('搜索会把部分失败暴露为可恢复的任务结果', () {
    final source = BookSource(bookSourceUrl: 'https://failed.example');
    final error = DomainError(
      code: 'network_error',
      stage: DomainErrorStage.search,
      message: '连接失败',
      retryable: true,
    );
    final session = SearchSession(
      query: '测试',
      rows: [
        SourceSearchResult(
          source: source,
          error: error.message,
          errorInfo: error,
        ),
      ],
      done: 1,
      total: 1,
      finished: true,
    );
    expect(session.taskState, isA<TaskFailed<List<SourceSearchResult>>>());
    final failed = session.taskState as TaskFailed<List<SourceSearchResult>>;
    expect(failed.error.retryable, isTrue);
    expect(friendlySearchError(error), contains('连接失败'));
  });

  test('取消后继续扫描只提交尚未尝试的源', () {
    final a = BookSource(bookSourceUrl: 'https://resume.example/a');
    final b = BookSource(bookSourceUrl: 'https://resume.example/b');
    final state = SearchSession(
      query: '测试',
      rows: [SourceSearchResult(source: a)],
      done: 1,
      total: 2,
      finished: true,
      remaining: 1,
      universe: 2,
    );
    expect(searchAttemptedSourceUrls(state), {a.bookSourceUrl});
    expect(searchAttemptedSourceUrls(state).contains(b.bookSourceUrl), isFalse);
  });

  test('取消时保留尚未渲染但已发起请求的源集合', () {
    final a = BookSource(bookSourceUrl: 'https://resume.example/a');
    final b = BookSource(bookSourceUrl: 'https://resume.example/b');
    final state = SearchSession(
      query: '测试',
      rows: [SourceSearchResult(source: a)],
      done: 1,
      total: 3,
      finished: true,
      remaining: 2,
      universe: 3,
      attemptedSourceUrls: {a.bookSourceUrl, b.bookSourceUrl},
    );
    expect(searchAttemptedSourceUrls(state), {
      a.bookSourceUrl,
      b.bookSourceUrl,
    });
  });

  test('队列在请求开始时记录源，取消后不会重复尝试', () async {
    final source = BookSource(
      bookSourceUrl: 'https://cancel.example/source',
      searchUrl: 'https://cancel.example/search',
    );
    final started = <String>[];
    var cancelled = false;
    final release = Completer<List<SearchBook>>();
    final run = SourceFanout.run(
      sources: [source],
      query: 'q',
      page: 1,
      search: (_) => release.future,
      isCancelled: () => cancelled,
      onStart: (s) {
        started.add(s.bookSourceUrl);
        cancelled = true;
      },
      onRow: (_) => fail('取消后不应提交迟到结果'),
    );
    // Let the worker claim the source before releasing its request.
    await Future<void>.delayed(Duration.zero);
    expect(started, [source.bookSourceUrl]);
    release.complete(const <SearchBook>[]);
    await run;
  });

  test(
    'same-host queue wakes on a free slot and stays under host cap',
    () async {
      final prevCap = EngineLimits.searchHostCap;
      final prevPool = EngineLimits.searchPool;
      EngineLimits.searchHostCap = 2;
      EngineLimits.searchPool = 8;
      addTearDown(() {
        EngineLimits.searchHostCap = prevCap;
        EngineLimits.searchPool = prevPool;
      });

      var current = 0;
      var peak = 0;
      final sources = [
        for (var i = 0; i < 6; i++)
          BookSource(
            bookSourceUrl: 'https://cap.example/source/$i',
            searchUrl: 'https://cap.example/search',
          ),
      ];
      final rows = <SourceSearchResult>[];
      await SourceFanout.run(
        sources: sources,
        query: 'host-cap',
        page: 1,
        search: (_) async {
          current++;
          if (current > peak) peak = current;
          await Future<void>.delayed(const Duration(milliseconds: 15));
          current--;
          return const <SearchBook>[];
        },
        isCancelled: () => false,
        onRow: rows.add,
      );

      expect(rows, hasLength(sources.length));
      expect(peak, 2);
    },
  );
}
