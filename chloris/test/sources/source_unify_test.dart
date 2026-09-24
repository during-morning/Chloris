import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/application/sources/source_unify.dart';
import 'package:flutter_test/flutter_test.dart';

BookSource _src({
  required String url,
  String name = '源',
  String? group,
  int type = 0,
  String? search,
  bool enabled = true,
  int weight = 0,
  int respondTime = 1000,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    bookSourceGroup: group,
    bookSourceType: type,
    enabled: enabled,
    searchUrl: search ?? 'https://example.com/search?q={{key}}',
    ruleSearch: SearchRule(bookList: '.item', name: 'a', bookUrl: 'a@href'),
    ruleToc: TocRule(chapterList: '.c', chapterName: 'a', chapterUrl: 'a@href'),
    ruleContent: ContentRule(content: '#c'),
    weight: weight,
    respondTime: respondTime,
  );
}

void main() {
  test('统一分区：类型和分组名归到固定集合', () {
    expect(unifySourceGroup(_src(url: 'https://a.com', group: '小说 书源')), '小说');
    expect(
      unifySourceGroup(_src(url: 'https://b.com', group: '轻小说 书源')),
      '轻小说',
    );
    expect(
      unifySourceGroup(_src(url: 'https://c.com', group: '漫画 书源', type: 2)),
      '漫画',
    );
    expect(
      unifySourceGroup(_src(url: 'https://d.com', group: '听书 书源', type: 1)),
      '听书',
    );
    expect(
      unifySourceGroup(_src(url: 'https://e.com', group: '正版小说 书源')),
      '正版',
    );
    expect(unifySourceGroup(_src(url: 'https://f.com', group: '💰 正版')), '正版');
    expect(unifySourceGroup(_src(url: 'https://g.com', group: '影视 书源')), '影视');
    expect(unifySourceGroup(_src(url: 'https://h.com', group: '📚 出版')), '出版');
    expect(unifiedSourceGroups, containsAll(['小说', '漫画', '听书', '其他']));
  });

  test('合并去重：同 URL 留更完整，丢弃成人源和本地文件源', () {
    final weak = _src(
      url: 'https://dup.com/s',
      name: '弱',
      group: '小说',
      search: '',
    );
    weak.ruleSearch = SearchRule();
    final strong = _src(url: 'https://dup.com/s', name: '强', group: '✔️校验,小说');
    final adult = _src(url: 'https://nsfw.com', name: '黄', group: '🔞 特殊');
    final file = _src(url: 'https://file.com', name: '档', type: 3);
    final merged = mergeBookSources([
      (weak, 5),
      (strong, 8),
      (adult, 40),
      (file, 10),
    ]);
    expect(merged, hasLength(1));
    expect(merged.first.bookSourceName, '强');
    expect(merged.first.bookSourceGroup, '小说');
  });

  test('URL 归一化去 www 与尾斜杠，词典源丢弃', () {
    expect(
      canonicalizeSourceUrl('https://www.Site.com/path/'),
      'https://site.com/path',
    );
    final dict = _src(url: 'https://dict.cn', name: '海词精选', group: '小说');
    final merged = mergeBookSources([(dict, 40)]);
    expect(merged, isEmpty);
  });

  test('分区配额裁剪并启用', () {
    final many = [
      for (var i = 0; i < 5; i++)
        _src(
          url: 'https://n$i.com/s',
          name: 'N$i',
          group: '小说',
          weight: 100 - i,
        ),
    ];
    final picked = applyGroupQuotas(many, caps: const {'小说': 2});
    expect(picked, hasLength(2));
    expect(picked.map((s) => s.bookSourceName), ['N0', 'N1']);
    expect(picked.every((s) => s.enabled), isTrue);
  });

  test('同主机最多两条，快的完整源优先', () {
    final a1 = _src(
      url: 'https://www.site.com/1',
      name: 'A1',
      weight: 80,
      respondTime: 400,
    );
    final a2 = _src(
      url: 'https://site.com/2',
      name: 'A2',
      weight: 90,
      respondTime: 200,
    );
    final a3 = _src(
      url: 'https://site.com/3',
      name: 'A3',
      weight: 70,
      respondTime: 100,
    );
    final b = _src(
      url: 'https://other.com/1',
      name: 'B',
      group: '漫画 书源',
      type: 2,
      weight: 40,
    );
    a1.bookSourceGroup = unifySourceGroup(a1);
    a2.bookSourceGroup = unifySourceGroup(a2);
    a3.bookSourceGroup = unifySourceGroup(a3);
    b.bookSourceGroup = unifySourceGroup(b);
    final picked = pickBestPerHost([a1, a2, a3, b], perHost: 2);
    expect(picked.map((s) => s.bookSourceName), ['A2', 'A1', 'B']);
    expect(picked.every((s) => s.enabled), isTrue);
  });
}
