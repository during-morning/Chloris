import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/book_detail/open_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directRead 仅在目录缓存 ≥2 章时成立', () {
    expect(tocAllowsDirectRead(null), isFalse);
    expect(tocAllowsDirectRead(const []), isFalse);
    expect(
      tocAllowsDirectRead([BookChapter(url: 'https://x/1', title: '一')]),
      isFalse,
    );
    expect(
      tocAllowsDirectRead([
        BookChapter(url: 'https://x/1', title: '一'),
        BookChapter(url: 'https://x/2', title: '二'),
      ]),
      isTrue,
    );
  });
}
