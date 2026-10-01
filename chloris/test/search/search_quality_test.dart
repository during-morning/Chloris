import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/core/search/incremental_merge.dart';
import 'package:chloris/features/search/search_provider.dart';
import 'package:chloris/core/search/search_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

SearchBook _book(
  String name,
  String url, {
  String author = '作者',
  String? intro,
}) => SearchBook(name: name, author: author, bookUrl: url, intro: intro);

void main() {
  test('搜索关键词归一化处理空白、标点与常见繁体', () {
    expect(normalizeSearchText(' 臺 灣，萬卷！ '), '台湾万卷');
    expect(normalizeSearchText('A-B : C'), 'abc');
  });

  test('搜索结果过滤空书、占位书和不合法链接', () {
    expect(
      isUsableSearchBook(_book('有效书名', 'https://example.com/book/1')),
      isTrue,
    );
    expect(
      isUsableSearchBook(_book('未知书籍', 'https://example.com/book/2')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('验证码提示', 'https://example.com/book/3')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('道', 'https://example.com/book/4')),
      isTrue,
    );
    expect(isUsableSearchBook(_book('有效书名', 'not a url')), isFalse);
    expect(
      isUsableSearchBook(_book('查询书', 'https://example.com/?id=123')),
      isTrue,
    );
  });

  test('过滤章节名式垃圾结果和站点名', () {
    expect(
      isUsableSearchBook(_book('第一章', 'https://example.com/c/1')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('第一页', 'https://example.com/c/2')),
      isFalse,
    );
    expect(isUsableSearchBook(_book('UC小说', 'https://example.com/')), isFalse);
    expect(
      isUsableSearchBook(_book('最多收藏', 'https://example.com/sort/fav')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('综合排序', 'https://example.com/list?order=score')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('全部显示', 'https://example.com/all')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('最多援力', 'https://example.com/rank/help')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('归档', 'https://example.com/archive')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('分类', 'https://example.com/category')),
      isFalse,
    );
    expect(isUsableSearchBook(_book('标签', 'https://example.com/tag')), isFalse);
    expect(
      isUsableSearchBook(_book('汉语词典', 'https://example.com/dict/1')),
      isFalse,
    );
    expect(
      isUsableSearchBook(_book('在线字典', 'https://example.com/zidian')),
      isFalse,
    );
  });

  test('按关键词打分，不在可用性阶段丢掉书名', () {
    expect(
      isUsableSearchBook(
        _book('完全无关的占位书', 'https://example.com/book/9', intro: '广告'),
        query: '斗破苍穹',
      ),
      isTrue,
    );
    expect(
      isUsableSearchBook(
        _book('斗破苍穹', 'https://example.com/book/dpcq'),
        query: '斗破苍穹',
      ),
      isTrue,
    );
    expect(
      searchMatchScore(_book('斗破苍穹', 'https://x/a'), '斗破'),
      greaterThanOrEqualTo(700),
    );
    expect(
      searchMatchScore(_book('完全无关的占位书', 'https://x/a'), '斗破苍穹'),
      lessThan(300),
    );
  });

  test('合并同书多源并按匹配分排序', () {
    final srcA = BookSource(
      bookSourceUrl: 'https://a.com',
      bookSourceName: 'A',
    );
    final srcB = BookSource(
      bookSourceUrl: 'https://b.com',
      bookSourceName: 'B',
    );
    final rows = [
      SourceSearchResult(
        source: srcA,
        books: [
          SearchBook(
            name: '仙逆',
            author: '耳根',
            bookUrl: 'https://a.com/1',
            origin: srcA.bookSourceUrl,
            originName: srcA.bookSourceName,
          ),
        ],
      ),
      SourceSearchResult(
        source: srcB,
        books: [
          SearchBook(
            name: '仙 逆',
            author: '耳根',
            bookUrl: 'https://b.com/1',
            origin: srcB.bookSourceUrl,
            originName: srcB.bookSourceName,
          ),
          SearchBook(
            name: '无关',
            author: '乙',
            bookUrl: 'https://b.com/2',
            origin: srcB.bookSourceUrl,
            originName: srcB.bookSourceName,
          ),
        ],
      ),
    ];
    final merged = mergeSearchRows(rows, '仙逆');
    expect(merged.where((e) => e.$2.name.contains('仙')).length, 1);
    expect(
      merged.first.$2.origins,
      containsAll(['https://a.com', 'https://b.com']),
    );
    expect(searchMatchScore(merged.first.$2, '仙逆'), greaterThanOrEqualTo(850));
    expect(merged.any((e) => e.$2.name == '无关'), isTrue);
    expect(merged.last.$2.name, '无关');
  });

  test('合并身份使用与查询一致的繁简/空白规范化', () {
    final rows = [
      SourceSearchResult(
        source: BookSource(bookSourceUrl: 'https://a.example'),
        books: [
          SearchBook(
            name: '臺 灣夜市',
            author: '作家',
            bookUrl: 'https://a.example/1',
            origin: 'https://a.example',
          ),
        ],
      ),
      SourceSearchResult(
        source: BookSource(bookSourceUrl: 'https://b.example'),
        books: [
          SearchBook(
            name: '台湾夜市',
            author: '作家',
            bookUrl: 'https://b.example/1',
            origin: 'https://b.example',
          ),
        ],
      ),
    ];
    final merged = mergeSearchRows(rows, '台湾夜市');
    expect(merged, hasLength(1));
    expect(
      merged.single.$2.origins,
      containsAll(['https://a.example', 'https://b.example']),
    );
  });

  test('精确搜索过滤器对齐 Legado BookList 的书名作者分类命中', () {
    final filter = preciseSearchFilter('斗破苍穹', precise: true)!;
    expect(filter('斗破苍穹', '天蚕土豆', null), isTrue);
    expect(filter('一本玄幻作品', '作者', '斗破苍穹'), isTrue);
    expect(filter('无关长篇', '路人', '都市'), isFalse);
    expect(preciseSearchFilter('斗破苍穹'), isNull);
  });

  test('精确模式保留分类命中，即使书名作者不含关键词', () {
    final book = _book('一本玄幻作品', 'https://example.com/book/kind', author: '作者')
      ..kind = '斗破苍穹';
    final rows = [
      SourceSearchResult(
        source: BookSource(bookSourceUrl: 'https://example.com'),
        books: [book],
      ),
    ];
    expect(mergeSearchRows(rows, '斗破苍穹', precise: true), hasLength(1));
  });

  test('精确模式按 Legado 丢掉 other，非精确保留可用结果', () {
    expect(searchMatchRatio(_book('斗破苍穹', 'https://x/a'), '斗破苍穹'), 1);
    expect(searchMatchBucket(_book('斗破苍穹', 'https://x/a'), '斗破苍穹'), 0);
    expect(
      searchMatchBucket(_book('无关长篇', 'https://x/b', author: '乙'), '斗破苍穹'),
      3,
    );
    final rows = [
      SourceSearchResult(
        source: BookSource(bookSourceUrl: 'https://a.com', bookSourceName: 'A'),
        books: [
          SearchBook(
            name: '斗破苍穹',
            author: '天蚕土豆',
            bookUrl: 'https://a.com/1',
            origin: 'https://a.com',
          ),
          SearchBook(
            name: '归档',
            author: '',
            bookUrl: 'https://a.com/arc',
            origin: 'https://a.com',
          ),
          SearchBook(
            name: '无关长篇',
            author: '乙',
            bookUrl: 'https://a.com/other',
            origin: 'https://a.com',
          ),
        ],
      ),
    ];
    final loose = mergeSearchRows(rows, '斗破苍穹');
    expect(loose.any((e) => e.$2.name == '斗破苍穹'), isTrue);
    expect(loose.any((e) => e.$2.name == '归档'), isFalse);
    expect(loose.any((e) => e.$2.name == '无关长篇'), isTrue);
    final precise = mergeSearchRows(rows, '斗破苍穹', precise: true);
    expect(precise.any((e) => e.$2.name == '斗破苍穹'), isTrue);
    expect(precise.any((e) => e.$2.name == '无关长篇'), isFalse);
  });

  test('增量合并与全量 mergeSearchRows 书目一致', () {
    final rows = <SourceSearchResult>[
      for (var i = 0; i < 6; i++)
        SourceSearchResult(
          source: BookSource(
            bookSourceUrl: 'https://m$i.com',
            bookSourceName: 'M$i',
          ),
          books: [
            SearchBook(
              name: '斗破苍穹',
              author: '天蚕土豆',
              bookUrl: 'https://m$i.com/dpcq',
              origin: 'https://m$i.com',
              originName: 'M$i',
            ),
            SearchBook(
              name: '斗破苍穹续',
              author: '天蚕土豆',
              bookUrl: 'https://m$i.com/dpcqx',
              origin: 'https://m$i.com',
              originName: 'M$i',
            ),
          ],
        ),
    ];
    final inc = IncrementalSearchMerge('斗破苍穹');
    for (final r in rows) {
      inc.add(r);
    }
    final full = mergeSearchRows(
      rows,
      '斗破苍穹',
    ).map((e) => e.$2.bookUrl).toList();
    final step = inc.snapshot().map((e) => e.$2.bookUrl).toList();
    expect(step, full);
  });

  test('fast sources sort first, slow sources stay in the queue', () {
    final slow = BookSource(
      bookSourceUrl: 'https://slow.com',
      bookSourceName: 'slow',
      searchUrl: 'https://slow.com/search',
      respondTime: 8000,
      customOrder: 0,
    );
    final fast = BookSource(
      bookSourceUrl: 'https://fast.com',
      bookSourceName: 'fast',
      searchUrl: 'https://fast.com/search',
      respondTime: 200,
      customOrder: 9,
    );
    final unknown = BookSource(
      bookSourceUrl: 'https://new.com',
      bookSourceName: 'new',
      searchUrl: 'https://new.com/search',
      respondTime: unsetRespondTimeMs,
      customOrder: 1,
    );
    final js = BookSource(
      bookSourceUrl: 'https://js.com',
      bookSourceName: 'js',
      searchUrl: '@js:java.ajax',
      respondTime: 100,
    );
    final ordered = orderSearchSources([slow, unknown, js, fast]);
    expect(ordered.map((s) => s.bookSourceName).toList(), [
      'fast',
      'slow',
      'new',
      'js',
    ]);
    expect(ordered.length, 4);
  });

  test('单字查询不过滤 40% 匹配，按源 weight/respondTime 排序', () {
    expect(isBasicSingleCharQuery('我'), isTrue);
    expect(isBasicSingleCharQuery(' 的 '), isTrue);
    expect(isBasicSingleCharQuery('仙逆'), isFalse);
    expect(searchMatchRatio(_book('斗破苍穹', 'https://x/a'), '我'), lessThan(0.4));

    final heavySlow = BookSource(
      bookSourceUrl: 'https://heavy.com',
      bookSourceName: 'heavy',
      weight: 50,
      respondTime: 8000,
    );
    final lightFast = BookSource(
      bookSourceUrl: 'https://fast.com',
      bookSourceName: 'fast',
      weight: 0,
      respondTime: 120,
    );
    final lightSlow = BookSource(
      bookSourceUrl: 'https://slow.com',
      bookSourceName: 'slow',
      weight: 0,
      respondTime: 9000,
    );
    final rows = [
      SourceSearchResult(
        source: lightSlow,
        books: [
          SearchBook(
            name: '斗破苍穹',
            author: '天蚕土豆',
            bookUrl: 'https://slow.com/dpcq',
            origin: lightSlow.bookSourceUrl,
            originName: lightSlow.bookSourceName,
          ),
        ],
      ),
      SourceSearchResult(
        source: heavySlow,
        books: [
          SearchBook(
            name: '无关长篇',
            author: '甲',
            bookUrl: 'https://heavy.com/1',
            origin: heavySlow.bookSourceUrl,
            originName: heavySlow.bookSourceName,
          ),
        ],
      ),
      SourceSearchResult(
        source: lightFast,
        books: [
          SearchBook(
            name: '另一本',
            author: '乙',
            bookUrl: 'https://fast.com/2',
            origin: lightFast.bookSourceUrl,
            originName: lightFast.bookSourceName,
          ),
          SearchBook(
            name: '汉语词典',
            author: '',
            bookUrl: 'https://fast.com/dict',
            origin: lightFast.bookSourceUrl,
            originName: lightFast.bookSourceName,
          ),
        ],
      ),
    ];
    final merged = mergeSearchRows(rows, '我');
    expect(merged.length, 3);
    expect(merged.any((e) => e.$2.name == '汉语词典'), isFalse);
    expect(merged.first.$1.bookSourceUrl, heavySlow.bookSourceUrl);
    expect(merged[1].$1.bookSourceUrl, lightFast.bookSourceUrl);
    expect(merged.last.$1.bookSourceUrl, lightSlow.bookSourceUrl);
    expect(merged.any((e) => e.$2.name == '斗破苍穹'), isTrue);

    final long = mergeSearchRows(rows, '斗破苍穹');
    expect(long.any((e) => e.$2.name == '斗破苍穹'), isTrue);
    expect(long.any((e) => e.$2.name == '无关长篇'), isTrue);
    final precise = mergeSearchRows(rows, '斗破苍穹', precise: true);
    expect(precise.any((e) => e.$2.name == '斗破苍穹'), isTrue);
    expect(precise.any((e) => e.$2.name == '无关长篇'), isFalse);
  });

  test('respondTime blends samples and search cache hits the same query', () {
    expect(blendRespondTime(unsetRespondTimeMs, 400), 400);
    expect(blendRespondTime(400, 800), 500);
    expect(blendRespondTime(400, 800, failed: true), 700);
    final cache = SearchHitCache(maxEntries: 2);
    cache.put('斗破', 1, 'https://a.com', [
      SearchBook(name: '斗破苍穹', author: '天蚕土豆', bookUrl: 'https://a.com/1'),
    ]);
    expect(cache.take('斗破', 1, 'https://a.com')!.first.name, '斗破苍穹');
    expect(cache.take('仙逆', 1, 'https://a.com'), isNull);
    cache.put('x', 1, 'https://b.com', []);
    cache.put('y', 1, 'https://c.com', []);
    expect(cache.take('斗破', 1, 'https://a.com'), isNull);
    expect(cache.length, 2);
  });

  test('搜索缓存区分同源不同规则上下文', () {
    final cache = SearchHitCache(maxEntries: 8);
    final hit = [
      SearchBook(name: '上下文书', author: '甲', bookUrl: 'https://ctx.example/1'),
    ];
    cache.put('q', 1, 'https://ctx.example', hit, context: 'rule-v1');
    expect(
      cache.take('q', 1, 'https://ctx.example', context: 'rule-v2'),
      isNull,
    );
    expect(
      cache.take('q', 1, 'https://ctx.example', context: 'rule-v1'),
      isNotNull,
    );
    final source = BookSource(
      bookSourceUrl: 'https://ctx.example',
      searchUrl: 'https://ctx.example/search?q={{key}}',
      ruleSearch: SearchRule(bookList: 'class.item'),
    );
    final first = searchCacheContext(source);
    source.ruleSearch!.bookList = 'class.other';
    expect(searchCacheContext(source), isNot(first));
  });
}
