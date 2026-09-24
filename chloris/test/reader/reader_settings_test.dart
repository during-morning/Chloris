import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/reader/reader_settings_provider.dart';

void main() {
  test('自定义字体设置可序列化并恢复', () {
    const settings = ReaderSettings(fontFamily: 'Noto Sans SC');
    final restored = ReaderSettings.fromJson(settings.toJson());
    expect(restored.fontFamily, 'Noto Sans SC');
  });

  test('默认打开替换净化，并记住双页视图', () {
    expect(const ReaderSettings().enableReplace, isTrue);
    final restored = ReaderSettings.fromJson({
      'doublePage': 'on',
    });
    expect(restored.enableReplace, isTrue);
    expect(restored.doublePage, 'on');
  });
}
