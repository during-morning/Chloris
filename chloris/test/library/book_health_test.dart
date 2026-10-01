import 'dart:io';
import 'package:chloris/app/providers.dart';
import 'package:chloris/application/online/online_book_port.dart';
import 'package:chloris/features/library/book_health_screen.dart';
import 'package:chloris/features/library/online_shelf_provider.dart';
import 'package:chloris/core/search/search_match.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class HealthPort implements OnlineBookPort {
  final cancelled = <String>[];
  @override
  void cancelSession(String id) => cancelled.add(id);
  @override
  Future<List<BookChapter>> loadChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter>)? onPartial,
  }) async {
    if (book.name == '断网书') throw const SocketException('网络不可用');
    if (book.name == '空目录') return [];
    return [
      BookChapter(
        title: '一',
        url: '${book.bookUrl}/1',
        index: 0,
        bookUrl: book.bookUrl,
      ),
    ];
  }

  @override
  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) async => book.name == '空正文' ? '' : '可读的正文';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HealthShelf extends OnlineShelfNotifier {
  @override
  List<OnlineShelfItem> build() => [
    for (final name in ['正常书', '空目录', '空正文', '断网书'])
      OnlineShelfItem(
        source: BookSource(
          bookSourceUrl: 'https://source.test',
          bookSourceName: '测试源',
        ),
        searchBook: SearchBook(
          name: name,
          bookUrl: 'https://source.test/$name',
          origin: 'https://source.test',
        ),
      ),
  ];
  @override
  void remove(String bookUrl) =>
      state = state.where((b) => b.bookUrl != bookUrl).toList();
}

void main() {
  test('有效单字与包含登录字样的书名不被误伤', () {
    for (final name in ['道', '登录万界']) {
      expect(
        isUsableSearchBook(
          SearchBook(name: name, bookUrl: 'https://source.test/book'),
        ),
        true,
      );
    }
    expect(
      isUsableSearchBook(
        SearchBook(name: '用户登录', bookUrl: 'https://source.test/login'),
      ),
      false,
    );
  });
  testWidgets('检查区分空内容和断网，确认页列出待移除书籍', (tester) async {
    final port = HealthPort();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineShelfProvider.overrideWith(HealthShelf.new),
          onlineBookPortProvider.overrideWithValue(port),
        ],
        child: const MaterialApp(home: BookHealthScreen()),
      ),
    );
    await tester.tap(find.byTooltip('检查在线书籍'));
    await tester.pumpAndSettle();
    expect(find.textContaining('首章可读取'), findsOneWidget);
    expect(find.textContaining('书源返回空目录'), findsOneWidget);
    expect(find.textContaining('首章正文为空'), findsOneWidget);
    expect(find.textContaining('暂时无法验证'), findsOneWidget);
    await tester.tap(find.byTooltip('移除确认无效的书籍'));
    await tester.pumpAndSettle();
    expect(find.text('移除 2 本无效书籍？'), findsOneWidget);
    expect(find.textContaining('• 空目录'), findsOneWidget);
    expect(find.textContaining('• 空正文'), findsOneWidget);
    await tester.tap(find.text('移除').last);
    await tester.pumpAndSettle();
    expect(find.text('正常书'), findsOneWidget);
    expect(find.text('断网书'), findsOneWidget);
    expect(find.text('空目录'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(port.cancelled, isNotEmpty);
  });
}
