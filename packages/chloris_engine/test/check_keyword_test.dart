// getCheckKeyword 对齐测试 —— legado BookSource.kt:212-220：
// checkKeyWord 非空白且不含 http / :: / ++ / -- 时优先于默认词。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

BookSource _src({String? checkKeyWord}) => BookSource(
      bookSourceUrl: 'https://ex.com',
      bookSourceName: '测试源',
      ruleSearch: SearchRule(
        bookList: 'class.item',
        name: 'text',
        bookUrl: 'href',
        checkKeyWord: checkKeyWord,
      ),
      ruleToc: TocRule(chapterList: 'class.list'),
      ruleContent: ContentRule(content: 'id.content'),
    );

void main() {
  test('checkKeyWord 有效时优先于默认词', () {
    expect(_src(checkKeyWord: '我的探针').getCheckKeyword('默认'), '我的探针');
  });

  test('空白 checkKeyWord 回退默认词', () {
    expect(_src(checkKeyWord: '   ').getCheckKeyword('默认'), '默认');
    expect(_src(checkKeyWord: null).getCheckKeyword('默认'), '默认');
  });

  test('含 http / :: / ++ / -- 的 checkKeyWord 视为无效（legado 同判）', () {
    expect(_src(checkKeyWord: 'https://probe.example.com').getCheckKeyword('默认'), '默认');
    expect(_src(checkKeyWord: 'a::b').getCheckKeyword('默认'), '默认');
    expect(_src(checkKeyWord: 'a++b').getCheckKeyword('默认'), '默认');
    expect(_src(checkKeyWord: 'a--b').getCheckKeyword('默认'), '默认');
  });
}
