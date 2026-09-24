import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('s2t converts common simplified chars', () {
    expect(ChineseConvert.s2t('中国'), '中國');
    expect(ChineseConvert.s2t('阅读'), '閱讀');
    expect(ChineseConvert.s2t('Hello'), 'Hello');
  });
}
