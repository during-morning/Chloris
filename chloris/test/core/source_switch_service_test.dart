import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/core/search/source_switch_service.dart';

void main() {
  BookSource source(String url) =>
      BookSource(bookSourceUrl: url, bookSourceName: url);

  SearchBook book(String url, String name) =>
      SearchBook(bookUrl: url, name: name, author: '作者');

  test('按来源去重并保留每个来源最高分候选', () {
    final service = SourceSwitchService(
      verify: (_) async => const SourceVerification.rejected('unused'),
    );
    final a = source('https://a.example');
    final ranked = service.rank([
      service.candidate(a, book('https://a.example/low', '目标书（完）'), bookName: '目标书')!,
      service.candidate(a, book('https://a.example/high', '目标书'), bookName: '目标书')!,
      service.candidate(
        source('https://b.example'),
        book('https://b.example/book', '目标书'),
        bookName: '目标书',
      )!,
    ]);

    expect(ranked, hasLength(2));
    expect(ranked.first.book.bookUrl, 'https://a.example/high');
  });

  test('验证失败后继续尝试候选并记录选择理由', () async {
    final attempts = <String>[];
    final service = SourceSwitchService(
      verify: (candidate) async {
        attempts.add(candidate.source.bookSourceUrl);
        if (attempts.length == 1) {
          return const SourceVerification.rejected('toc_empty');
        }
        return const SourceVerification(
          level: SourceVerificationLevel.l1Catalog,
          chapterCount: 12,
        );
      },
    );
    final selection = await service.select([
      service.candidate(
        source('https://a.example'),
        book('https://a.example/book', '目标书'),
        bookName: '目标书',
      )!,
      service.candidate(
        source('https://b.example'),
        book('https://b.example/book', '目标书'),
        bookName: '目标书',
      )!,
    ]);

    expect(selection, isNotNull);
    expect(attempts, hasLength(2));
    expect(selection!.verification.chapterCount, 12);
    expect(selection.decision.reasons, contains('目录 12 章'));
    expect(service.decisions, hasLength(2));
    expect(service.decisions.first.selected, isFalse);
    expect(service.decisions.last.selected, isTrue);
  });
}
