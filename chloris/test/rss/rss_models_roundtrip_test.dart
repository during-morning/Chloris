import 'dart:convert';

import 'package:chloris/application/rss/rss_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A subscription source as Legado-E stores it, with every one of its 44
/// columns populated. Importing this used to keep only 22 of them.
const _fullLegadoRssSource = <String, dynamic>{
  'sourceUrl': 'https://feed.test/rss',
  'sourceName': '测试订阅',
  'sourceIcon': 'https://feed.test/icon.png',
  'sourceGroup': '科技,资讯',
  'sourceComment': '备注',
  'variableComment': '变量说明',
  'enabled': true,
  'enabledCookieJar': false,
  'jsLib': 'function x(){return 1}',
  'concurrentRate': '2/1000',
  'header': '{"User-Agent":"UA"}',
  'loginUrl': 'https://feed.test/login',
  'loginUi': '[{"name":"user","type":"text"}]',
  'loginCheckJs': 'java.log("check")',
  'coverDecodeJs': 'java.log("cover")',
  'sortUrl': '分类A::https://feed.test/a',
  'singleUrl': false,
  'articleStyle': 2,
  'ruleArticles': '.item',
  'ruleNextPage': '.next@href',
  'ruleTitle': '.title@text',
  'rulePubDate': '.date@text',
  'ruleDescription': '.desc@text',
  'ruleImage': 'img@src',
  'ruleLink': 'a@href',
  'ruleContent': '.content@html',
  'contentWhitelist': 'p,img',
  'contentBlacklist': 'script',
  'shouldOverrideUrlLoading': true,
  'style': 'body{color:red}',
  'enableJs': true,
  'loadWithBaseUrl': true,
  'injectJs': 'java.log("inject")',
  'preloadJs': 'java.log("preload")',
  'startHtml': '<html>',
  'startStyle': 'div{}',
  'startJs': 'java.log("start")',
  'showWebLog': 1,
  'lastUpdateTime': 1700000000000,
  'customOrder': 7,
  'type': 1,
  'preload': 1,
  'cacheFirst': 1,
  'searchUrl': 'https://feed.test/search?q={{key}}',
};

void main() {
  test('every Legado rssSources column survives a round trip', () {
    final parsed = RssSource.fromJson(
      Map<String, dynamic>.from(_fullLegadoRssSource),
    );
    final back = parsed.toJson();

    // No key may be dropped, and no value may change.
    expect(back.keys.toSet(), _fullLegadoRssSource.keys.toSet());
    for (final e in _fullLegadoRssSource.entries) {
      expect(
        back[e.key],
        e.value,
        reason: 'field lost or altered on round trip: ${e.key}',
      );
    }
  });

  test('the fields an earlier revision dropped are now modelled', () {
    final s = RssSource.fromJson(
      Map<String, dynamic>.from(_fullLegadoRssSource),
    );
    // These are the ones that used to vanish on import, silently disabling
    // login, custom headers, JS libraries and content filtering.
    expect(s.loginUi, isNotNull);
    expect(s.loginCheckJs, isNotNull);
    expect(s.header, isNotNull);
    expect(s.jsLib, isNotNull);
    expect(s.contentWhitelist, 'p,img');
    expect(s.contentBlacklist, 'script');
    expect(s.injectJs, isNotNull);
    expect(s.preloadJs, isNotNull);
    expect(s.startHtml, isNotNull);
    expect(s.cacheFirst, 1);
    expect(s.searchUrl, isNotNull);
    expect(s.shouldOverrideUrlLoading, isTrue);
  });

  test('unknown future fields are preserved verbatim', () {
    final json = {
      'sourceUrl': 'https://feed.test/rss',
      'sourceName': 'x',
      'someFutureField': {
        'nested': [1, 2, 3],
      },
      'anotherOne': 'keep me',
    };
    final back = RssSource.fromJson(json).toJson();
    expect(back['someFutureField'], {
      'nested': [1, 2, 3],
    });
    expect(back['anotherOne'], 'keep me');
  });

  test('a round trip through JSON text is stable', () {
    final once = RssSource.fromJson(
      Map<String, dynamic>.from(_fullLegadoRssSource),
    ).toJson();
    final twice = RssSource.fromJson(
      jsonDecode(jsonEncode(once)) as Map<String, dynamic>,
    ).toJson();
    expect(jsonEncode(twice), jsonEncode(once));
  });

  group('RssArticle', () {
    test('carries read state, progress and grouping', () {
      final a = RssArticle.fromJson({
        'title': '标题',
        'link': 'https://feed.test/1',
        'read': true,
        'durPos': 42,
        'group': '分组B',
        'sort': '科技',
        'type': 2,
        'order': 9,
        'variable': 'v',
      });
      expect(a.read, isTrue);
      expect(a.durPos, 42);
      expect(a.group, '分组B');

      final back = a.toJson();
      expect(back['read'], isTrue);
      expect(back['durPos'], 42);
      expect(back['group'], '分组B');
      expect(back['sort'], '科技');
      expect(back['type'], 2);
      expect(back['order'], 9);
    });

    test('copyWith keeps identity and only changes what is asked', () {
      final a = RssArticle.fromJson({
        'title': 't',
        'link': 'l',
        'group': 'g',
        'durPos': 5,
        'variable': 'v',
      });
      final b = a.copyWith(read: true, durPos: 99);
      expect(b.read, isTrue);
      expect(b.durPos, 99);
      expect(b.title, 't');
      expect(b.group, 'g');
      expect(b.variable, 'v');
      expect(a.read, isFalse);
      expect(a.durPos, 5);
    });

    test('defaults match the Legado column defaults', () {
      final a = RssArticle.fromJson({'title': 't', 'link': 'l'});
      expect(a.group, '默认分组');
      expect(a.read, isFalse);
      expect(a.durPos, 0);
    });

    test('unknown fields survive', () {
      final back = RssArticle.fromJson({
        'title': 't',
        'link': 'l',
        'futureField': 1,
      }).toJson();
      expect(back['futureField'], 1);
    });
  });
}
