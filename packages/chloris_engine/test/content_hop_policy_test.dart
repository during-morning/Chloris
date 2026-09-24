import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('canonicalPageUrl drops cache-busting keys and fragments', () {
    expect(
      ContentHopPolicy.canonicalPageUrl('https://Ex.COM/c/1/?t=9#page'),
      ContentHopPolicy.canonicalPageUrl('https://ex.com/c/1?rnd=1'),
    );
    expect(
      ContentHopPolicy.canonicalPageUrl('https://ex.com/c/1?page=2'),
      isNot(ContentHopPolicy.canonicalPageUrl('https://ex.com/c/1?page=3')),
    );
  });

  test('acceptNextUrls skips seen pages and the next chapter', () {
    final seen = <String>{
      ContentHopPolicy.canonicalPageUrl('https://ex.com/c/1'),
    };
    final urls = ContentHopPolicy.acceptNextUrls(
      currentUrl: 'https://ex.com/c/1',
      candidates: ['/c/1?t=2', '/c/2', '/c/3', '/c/next'],
      seen: seen,
      nextChapterUrl: '/c/next',
    );
    expect(urls, ['https://ex.com/c/2', 'https://ex.com/c/3']);
    expect(
      ContentHopPolicy.acceptNextUrls(
        currentUrl: 'https://ex.com/c/2',
        candidates: ['/c/3'],
        seen: seen,
        limit: 1,
      ),
      isEmpty,
    );
  });

  test('isRepeatContent ignores whitespace-only differences', () {
    expect(
      ContentHopPolicy.isRepeatContent('第一页 正文。', '第一页正文。'),
      isTrue,
    );
    expect(ContentHopPolicy.isRepeatContent('第二页。', '第一页正文。'), isFalse);
  });

  test('isNavigationOnly requires multiple chrome markers', () {
    expect(ContentHopPolicy.isNavigationOnly('返回目录'), isFalse);
    expect(
      ContentHopPolicy.isNavigationOnly('小说在线阅读 前往客户端 大家都在搜 返回 取消'),
      isTrue,
    );
    expect(
      ContentHopPolicy.isNavigationOnly(
        '小说在线阅读。他终于明白了这件事的真相，于是继续往前走。',
      ),
      isFalse,
    );
  });
}
