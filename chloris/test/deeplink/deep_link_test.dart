import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/services/deeplink/deep_link_service.dart';

void main() {
  test('解析书源导入深链', () {
    final req = parseLegadoImport('legado://import/bookSource?src=https://example.com/s.json');
    expect(req, isNotNull);
    expect(req!.type, ImportType.bookSource);
    expect(req.src, 'https://example.com/s.json');
  });

  test('解析换肤/排版深链', () {
    expect(parseLegadoImport('legado://import/theme?src=aaa')!.type, ImportType.theme);
    expect(parseLegadoImport('legado://import/readConfig?src=bbb')!.type, ImportType.readConfig);
  });

  test('非法 scheme 返回 null', () {
    expect(parseLegadoImport('https://example.com'), isNull);
  });
}
