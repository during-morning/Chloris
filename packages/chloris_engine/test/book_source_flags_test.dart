import 'dart:convert';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('hasLoginUrl / hasSearch / hasExploreUrl', () {
    final s = BookSource(
      bookSourceUrl: 'https://a.com',
      searchUrl: 'https://a.com/s?q={{key}}',
      loginUrl: 'https://a.com/login',
      exploreUrl: '全部::https://a.com/list',
    );
    expect(s.hasLoginUrl, isTrue);
    expect(s.hasSearch, isTrue);
    expect(s.hasExploreUrl, isTrue);
    expect(s.exploreKinds, isNotEmpty);
  });
  test('empty flags', () {
    final s = BookSource(bookSourceUrl: 'https://a.com');
    expect(s.hasLoginUrl, isFalse);
    expect(s.hasSearch, isFalse);
    expect(s.hasExploreUrl, isFalse);
  });

  test('hasCompleteRules needs search+toc+content', () {
    final incomplete = BookSource(
      bookSourceUrl: 'https://a.com',
      searchUrl: 'https://a.com/s',
      ruleSearch: SearchRule(bookList: '.item'),
    );
    expect(incomplete.hasCompleteRules, isFalse);
    final complete = BookSource(
      bookSourceUrl: 'https://a.com',
      searchUrl: 'https://a.com/s',
      ruleSearch: SearchRule(bookList: '.item'),
      ruleToc: TocRule(chapterList: '.c'),
      ruleContent: ContentRule(content: '#c'),
    );
    expect(complete.hasCompleteRules, isTrue);
  });

  test('loginUi is persisted and respected', () {
    final s = BookSource(
      bookSourceUrl: 'https://a.com',
      loginUi: '{"fields":[{"name":"user","type":"text"}]}',
    );
    expect(s.loginUi, isNotNull);
    final fields = jsonDecode(s.loginUi!)['fields'] as List;
    final f = fields[0] as Map<String, dynamic>;
    expect(f['name'], 'user');
  });
}
