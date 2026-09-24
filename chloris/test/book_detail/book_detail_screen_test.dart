import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/engine/engine_facade.dart';
import 'package:chloris/app/providers.dart';
import 'package:chloris/core/search/search_schedule.dart';
import 'package:chloris/features/book_detail/book_detail_provider.dart';
import 'package:chloris/features/book_detail/book_detail_screen.dart';
import 'package:chloris/features/book_detail/chapter_text_cache.dart';
import 'package:chloris/features/sources/source_library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      StrResponse(url: spec.url, body: '', code: 404);

  @override
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
  }) async => Uint8List(0);

  @override
  void cancelInFlight() {}
}

class _ChangeSourceFacade extends EngineFacade {
  _ChangeSourceFacade({this.hits = const {}}) : super(http: _SilentHttp());

  final Map<String, List<SearchBook>> hits;

  @override
  Future<List<SearchBook>> search(
    BookSource source,
    String key, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async {
    return hits[source.bookSourceUrl] ?? const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('详情页先画搜索书信息，目录区 skeleton，加入书架可用', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final source = BookSource(
      bookSourceUrl: 'https://a.com',
      bookSourceName: 'A',
    );
    final searchBook = SearchBook(
      name: '仙逆',
      author: '耳根',
      bookUrl: 'https://a.com/xianni',
      intro: '修仙简介',
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
    );
    final chapters = [
      BookChapter(
        url: 'https://a.com/1',
        title: '第一章',
        bookUrl: searchBook.bookUrl,
        index: 0,
      ),
      BookChapter(
        url: 'https://a.com/2',
        title: '第二章',
        bookUrl: searchBook.bookUrl,
        index: 1,
      ),
    ];
    await ChapterTextCache.instance.clear();
    await ChapterTextCache.instance.put(
      source.bookSourceUrl,
      chapters.first.url,
      'cached',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          engineFacadeProvider.overrideWithValue(
            EngineFacade(http: _SilentHttp()),
          ),
          bookInfoProvider.overrideWith(
            (ref, args) async => args.searchBook.toBook(),
          ),
          bookTocProvider.overrideWith((ref, args) async {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return chapters;
          }),
        ],
        child: MaterialApp(
          home: BookDetailScreen(source: source, searchBook: searchBook),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('仙逆'), findsWidgets);
    expect(find.text('耳根'), findsOneWidget);
    expect(find.textContaining('修仙简介'), findsOneWidget);
    expect(find.text('加入书架'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始阅读'),
    );
    expect(start.onPressed, isNull);

    await tester.pumpAndSettle();
    expect(find.text('目录（2 章）'), findsOneWidget);
    expect(find.text('第一章'), findsOneWidget);
    final started = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始阅读'),
    );
    expect(started.onPressed, isNotNull);
    await ChapterTextCache.instance.clear();
  });

  testWidgets('换源用已有源立刻列出，点选后在当前页切换', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SearchHitCache.instance.clear();
    final sourceA = BookSource(
      bookSourceUrl: 'https://a.com',
      bookSourceName: 'A源',
      searchUrl: 'https://a.com/s?q={{key}}',
    );
    final sourceB = BookSource(
      bookSourceUrl: 'https://b.com',
      bookSourceName: 'B源',
      searchUrl: 'https://b.com/s?q={{key}}',
    );
    final searchBook = SearchBook(
      name: '仙逆',
      author: '耳根',
      bookUrl: 'https://a.com/xianni',
      origin: sourceA.bookSourceUrl,
      originName: sourceA.bookSourceName,
    );
    searchBook.addOrigin(sourceB.bookSourceUrl, 'https://b.com/xianni');
    final chapters = [
      BookChapter(
        url: 'https://a.com/1',
        title: '第一章',
        bookUrl: searchBook.bookUrl,
        index: 0,
      ),
      BookChapter(
        url: 'https://a.com/2',
        title: '第二章',
        bookUrl: searchBook.bookUrl,
        index: 1,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          engineFacadeProvider.overrideWithValue(_ChangeSourceFacade()),
          allSourcesProvider.overrideWith((ref) async => [sourceA, sourceB]),
          enabledSourcesProvider.overrideWith(
            (ref) async => [sourceA, sourceB],
          ),
          bookInfoProvider.overrideWith(
            (ref, args) async => args.searchBook.toBook(),
          ),
          bookTocProvider.overrideWith((ref, args) async => chapters),
        ],
        child: MaterialApp(
          home: BookDetailScreen(source: sourceA, searchBook: searchBook),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A源'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, '换源'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('换源 · 仙逆'), findsOneWidget);
    expect(find.text('B源'), findsWidgets);
    await tester.tap(find.text('B源'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(OutlinedButton, '换源'), findsOneWidget);
    expect(find.text('B源'), findsWidgets);
    expect(find.text('换源 · 仙逆'), findsNothing);
  });

  testWidgets('换源搜索其它书源，点选后目录仍可点', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SearchHitCache.instance.clear();
    final sourceA = BookSource(
      bookSourceUrl: 'https://a.com',
      bookSourceName: '甲源',
      searchUrl: 'https://a.com/s?q={{key}}',
    );
    final sourceB = BookSource(
      bookSourceUrl: 'https://b.com',
      bookSourceName: '乙源',
      searchUrl: 'https://b.com/s?q={{key}}',
    );
    final searchBook = SearchBook(
      name: '仙逆',
      author: '耳根',
      bookUrl: 'https://a.com/xianni',
      origin: sourceA.bookSourceUrl,
      originName: sourceA.bookSourceName,
    );
    final chapters = [
      BookChapter(
        url: 'https://x.com/1',
        title: '第一章',
        bookUrl: searchBook.bookUrl,
        index: 0,
      ),
      BookChapter(
        url: 'https://x.com/2',
        title: '第二章',
        bookUrl: searchBook.bookUrl,
        index: 1,
      ),
    ];
    final facade = _ChangeSourceFacade(
      hits: {
        sourceB.bookSourceUrl: [
          SearchBook(
            name: '仙逆',
            author: '耳根',
            bookUrl: 'https://b.com/xianni',
            origin: sourceB.bookSourceUrl,
            originName: sourceB.bookSourceName,
            latestChapterTitle: '第999章',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          engineFacadeProvider.overrideWithValue(facade),
          allSourcesProvider.overrideWith((ref) async => [sourceA, sourceB]),
          enabledSourcesProvider.overrideWith(
            (ref) async => [sourceA, sourceB],
          ),
          bookInfoProvider.overrideWith(
            (ref, args) async => args.searchBook.toBook(),
          ),
          bookTocProvider.overrideWith((ref, args) async => chapters),
        ],
        child: MaterialApp(
          home: BookDetailScreen(source: sourceA, searchBook: searchBook),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '换源'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('乙源'), findsOneWidget);
    await tester.tap(find.text('乙源'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('乙源'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '换源'), findsOneWidget);
  });
}
