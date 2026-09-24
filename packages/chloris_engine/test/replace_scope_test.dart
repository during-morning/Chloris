// 替换规则作用域语义测试 —— 对齐 legado ReplaceRuleDao.findEnabledByContentScope/TitleScope：
//   scope 为空 = 全适用；非空时列值须包含 书名/书源名 子串（LIKE '%x%'）；
//   excludeScope 列值包含 书名/书源名 子串 → 排除；
//   scopeTitle / scopeContent 决定规则进入哪条管线。
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

Book _book({String name = '凡人修仙传', String origin = 'https://src.example.com'}) =>
    Book(bookUrl: '$origin/book/1', name: name, origin: origin);

ReplaceRule _rule({
  String pattern = '广告',
  String replacement = '',
  bool isRegex = false,
  String? scope,
  String? excludeScope,
  bool scopeTitle = false,
  bool scopeContent = true,
}) =>
    ReplaceRule(
      name: 'r',
      pattern: pattern,
      replacement: replacement,
      isRegex: isRegex,
      scope: scope,
      excludeScope: excludeScope,
      scopeTitle: scopeTitle,
      scopeContent: scopeContent,
    );

void main() {
  group('replace rule scope', () {
    test('空 scope 全适用', () {
      final book = _book();
      final p = ContentProcessor.forBook(book, allRules: [_rule()]);
      expect(p.contentRules, hasLength(1));
    });

    test('scope 命中书名', () {
      final p = ContentProcessor.forBook(
        _book(name: '凡人修仙传'),
        allRules: [_rule(scope: '另一本书;凡人修仙传')],
      );
      expect(p.contentRules, hasLength(1));
    });

    test('scope 命中书源', () {
      final p = ContentProcessor.forBook(
        _book(origin: 'https://src.example.com'),
        allRules: [_rule(scope: 'https://src.example.com')],
      );
      expect(p.contentRules, hasLength(1));
    });

    test('scope 未命中 → 跳过', () {
      final p = ContentProcessor.forBook(
        _book(name: '别的书', origin: 'https://other.example.com'),
        allRules: [_rule(scope: '凡人修仙传')],
      );
      expect(p.contentRules, isEmpty);
    });

    test('excludeScope 命中书名 → 排除（对齐 legado SQL 语义）', () {
      final p = ContentProcessor.forBook(
        _book(name: '凡人修仙传'),
        allRules: [_rule(excludeScope: '凡人修仙传')],
      );
      expect(p.contentRules, isEmpty);
    });

    test('excludeScope 列值包含书源串 → 排除（legado LIKE %origin% 语义）', () {
      final p = ContentProcessor.forBook(
        _book(origin: 'https://src.example.com'),
        allRules: [_rule(excludeScope: '备用;https://src.example.com')],
      );
      expect(p.contentRules, isEmpty);
    });

    test('excludeScope 列值不包含完整书源串 → 保留（短域名≠URL，对齐 legado）', () {
      final p = ContentProcessor.forBook(
        _book(origin: 'https://src.example.com'),
        allRules: [_rule(excludeScope: 'src.example.com')],
      );
      expect(p.contentRules, hasLength(1));
    });

    test('excludeScope 未命中 → 保留', () {
      final p = ContentProcessor.forBook(
        _book(name: '别的书'),
        allRules: [_rule(excludeScope: '凡人修仙传')],
      );
      expect(p.contentRules, hasLength(1));
    });

    test('scopeContent=false → 不进正文管线', () {
      final p = ContentProcessor.forBook(
        _book(),
        allRules: [_rule(scopeContent: false)],
      );
      expect(p.contentRules, isEmpty);
    });

    test('scopeTitle=false → 不进标题管线；scopeTitle=true → 进', () {
      final p = ContentProcessor.forBook(
        _book(),
        allRules: [
          _rule(scopeTitle: false, scopeContent: false),
          _rule(scopeTitle: true, scopeContent: false),
        ],
      );
      expect(p.titleRules, hasLength(1));
      expect(p.contentRules, isEmpty);
    });

    test('执行语义：命中规则的净化生效、被排除规则不生效', () async {
      final book = _book(name: '凡人修仙传');
      final chapter = BookChapter(url: 'c', title: '第一章', bookUrl: book.bookUrl);
      final p = ContentProcessor.forBook(book, allRules: [
        _rule(), // 无作用域限制，正文去「广告」
        _rule(
          pattern: '垃圾',
          excludeScope: '凡人修仙传',
        ), // 被排除，不去「垃圾」
      ]);
      final out = await p.process(
        book: book,
        chapter: chapter,
        content: '第一章\n正文广告与垃圾并存',
      );
      expect(out.text.contains('广告'), isFalse);
      expect(out.text.contains('垃圾'), isTrue);
    });
  });

  group('replace rule json round-trip (legado 字段名)', () {
    test('四作用域字段 round-trip', () {
      const json = '''
      [{
        "id": 1, "name": "去广告", "group": "净化",
        "pattern": "广告", "replacement": "", "isRegex": false,
        "scope": "书源A;凡人", "excludeScope": "试读",
        "scopeTitle": true, "scopeContent": false,
        "isEnabled": true, "timeoutMillisecond": 3000, "order": 0
      }]
      ''';
      final rules = ReplaceRule.listFromJson(json);
      expect(rules, hasLength(1));
      final r = rules.first;
      expect(r.scope, '书源A;凡人');
      expect(r.excludeScope, '试读');
      expect(r.scopeTitle, isTrue);
      expect(r.scopeContent, isFalse);
      final back = ReplaceRule.listFromJson(
        jsonEncode([r.toJson()]),
      );
      expect(back.first.scope, '书源A;凡人');
      expect(back.first.excludeScope, '试读');
      expect(back.first.scopeTitle, isTrue);
      expect(back.first.scopeContent, isFalse);
    });
  });
}
