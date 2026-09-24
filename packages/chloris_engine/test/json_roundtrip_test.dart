import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('BookSource round-trips every legado field', () {
    final source = BookSource(
      bookSourceUrl: 'https://example.com',
      bookSourceName: '示例源',
      bookSourceGroup: '小说',
      bookSourceType: BookSourceType.text,
      bookUrlPattern: r'https://example.com/book/\d+',
      customOrder: 3,
      enabled: true,
      enabledExplore: true,
      jsLib: 'function x(){}',
      enabledCookieJar: true,
      concurrentRate: '20/60000',
      header: '{"User-Agent":"Chloris"}',
      loginUrl: 'function login(){}',
      loginUi: '[{"name":"Token","type":"text"}]',
      loginCheckJs: 'true',
      coverDecodeJs: 'result',
      bookSourceComment: 'comment',
      variableComment: 'vars',
      lastUpdateTime: 1700000000000,
      respondTime: 1200,
      weight: 8,
      exploreUrl: 'https://example.com/explore',
      searchUrl: 'https://example.com/search?q={{key}}&page={{page}}',
      ruleSearch: SearchRule(
        checkKeyWord: '测试',
        bookList: 'class.item',
        name: 'tag.a@text',
        author: 'class.author@text',
        intro: 'class.intro@text',
        kind: 'class.kind@text',
        lastChapter: 'class.last@text',
        updateTime: 'class.time@text',
        bookUrl: 'tag.a@href',
        coverUrl: 'tag.img@src',
        wordCount: 'class.wc@text',
      ),
      ruleExplore: ExploreRule(bookList: 'class.card', name: 'tag.a@text'),
      ruleBookInfo: BookInfoRule(
        name: 'tag.h1@text',
        author: 'class.author@text',
        intro: 'id.intro@html',
        coverUrl: 'tag.img@src',
        tocUrl: 'class.toc@href',
      ),
      ruleToc: TocRule(
        chapterList: 'class.chapter',
        chapterName: 'tag.a@text',
        chapterUrl: 'tag.a@href',
        nextTocUrl: 'text.下一页@href',
      ),
      ruleContent: ContentRule(
        content: 'id.content@html',
        nextContentUrl: 'text.下一页@href',
        replaceRegex: '广告',
        imageStyle: 'FULL',
      ),
    );

    final encoded = source.toJson();
    final again = BookSource.fromJson(encoded);
    expect(again.bookSourceUrl, source.bookSourceUrl);
    expect(again.bookSourceName, source.bookSourceName);
    expect(again.bookSourceGroup, source.bookSourceGroup);
    expect(again.bookSourceType, source.bookSourceType);
    expect(again.bookUrlPattern, source.bookUrlPattern);
    expect(again.customOrder, source.customOrder);
    expect(again.enabled, isTrue);
    expect(again.jsLib, source.jsLib);
    expect(again.concurrentRate, source.concurrentRate);
    expect(again.header, source.header);
    expect(again.loginUrl, source.loginUrl);
    expect(again.loginUi, source.loginUi);
    expect(again.searchUrl, source.searchUrl);
    expect(again.ruleSearch?.name, 'tag.a@text');
    expect(again.ruleSearch?.coverUrl, 'tag.img@src');
    expect(again.ruleBookInfo?.tocUrl, 'class.toc@href');
    expect(again.ruleToc?.nextTocUrl, 'text.下一页@href');
    expect(again.ruleContent?.imageStyle, 'FULL');
    expect(again.hasCompleteRules, isTrue);
  });

  test('nested rule stored as JSON string still parses', () {
    final source = BookSource.fromJson({
      'bookSourceUrl': 'https://string-rule.example',
      'bookSourceName': 'string-rule',
      'ruleSearch': jsonEncode({'bookList': '\$[*]', 'name': '\$.title'}),
    });
    expect(source.ruleSearch?.bookList, r'$[*]');
    expect(source.ruleSearch?.name, r'$.title');
  });

  test('Book / chapter / progress / replace / toc round-trip', () {
    final book = Book(
      bookUrl: 'https://example.com/b/1',
      name: '书名',
      author: '作者',
      origin: 'https://example.com',
      originName: '示例源',
      type: BookType.text,
      durChapterIndex: 12,
      durChapterPos: 345,
      durChapterTitle: '第十三章',
      coverUrl: 'https://example.com/c.jpg',
      intro: '简介',
      readConfig: ReadConfig(pageAnim: PageAnim.slide, playSpeed: 1.25),
    );
    final book2 = Book.fromJson(book.toJson());
    expect(book2.durChapterIndex, 12);
    expect(book2.durChapterPos, 345);
    expect(book2.readConfig?.pageAnim, PageAnim.slide);
    expect(book2.readConfig?.playSpeed, 1.25);

    final chapter = BookChapter(
      url: 'https://example.com/c/1',
      title: '第一章',
      bookUrl: book.bookUrl,
      start: 10,
      end: 200,
      startFragmentId: 'ch1',
    );
    expect(BookChapter.fromJson(chapter.toJson()).start, 10);

    final progress = BookProgress.fromBook(book2);
    expect(BookProgress.fromJson(progress.toJson()).durChapterPos, 345);

    final replace = ReplaceRule(
      id: 1,
      name: '去广告',
      pattern: '广告',
      replacement: '',
      isRegex: false,
      scopeContent: true,
    );
    expect(ReplaceRule.fromJson(replace.toJson()).pattern, '广告');
    expect(replace.isValid, isTrue);

    final toc = TxtTocRule(
      id: -2,
      name: '目录',
      rule: r'^第.+章',
      example: '第一章',
    );
    expect(TxtTocRule.fromJson(toc.toJson()).rule, r'^第.+章');
  });

  test('SearchBook merges origins and converts to Book', () {
    final a = SearchBook(
      bookUrl: 'https://a/book',
      origin: 'https://a',
      originName: 'A',
      name: '仙逆',
      author: '耳根',
      type: BookType.text,
      coverUrl: 'https://a/cover.jpg',
      intro: '简介',
    );
    a.addOrigin('https://b');
    expect(a.origins, containsAll(['https://a', 'https://b']));
    final book = a.toBook();
    expect(book.name, '仙逆');
    expect(book.coverUrl, 'https://a/cover.jpg');
  });

  test('parses a real 开源阅读 source file when present', () {
    final file = File(
      '../../开源阅读/书源管理/【阅读】轻小说书源@小霖子.json',
    );
    if (!file.existsSync()) {
      file.path; // keep the relative path documented
      return;
    }
    final sources = BookSource.listFromJson(jsonDecode(file.readAsStringSync()));
    expect(sources, isNotEmpty);
    expect(sources.every((s) => s.bookSourceUrl.isNotEmpty), isTrue);
    expect(sources.every((s) => s.bookSourceType == BookSourceType.text), isTrue);
    final first = sources.first;
    final again = BookSource.fromJson(first.toJson());
    expect(again.bookSourceUrl, first.bookSourceUrl);
    expect(again.bookSourceName, first.bookSourceName);
    expect(again.searchUrl, first.searchUrl);
    expect(again.ruleSearch?.bookList, first.ruleSearch?.bookList);
    expect(again.ruleContent?.content, first.ruleContent?.content);
    expect(again.ruleToc?.chapterList, first.ruleToc?.chapterList);
  });

  test('ReplaceRule list from 净化 JSON when present', () {
    final file = File('../../开源阅读/净化替换规则/【阅读】净化规则@小霖子.json');
    if (!file.existsSync()) return;
    final rules = ReplaceRule.listFromJson(jsonDecode(file.readAsStringSync()));
    expect(rules.length, greaterThan(10));
    final again = ReplaceRule.fromJson(rules.first.toJson());
    expect(again.name, rules.first.name);
    expect(again.pattern, rules.first.pattern);
  });
}
