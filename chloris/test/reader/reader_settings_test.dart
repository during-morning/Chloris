import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/reader/reader_palette.dart';
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

  test('自定义配色的背景/文字色在反序列化后保留', () {
    final restored = ReaderSettings.fromJson({
      'paletteId': 'custom',
      'background': 0xFF000000,
      'foreground': 0xFFABCDEF,
    });
    expect(restored.paletteId, 'custom');
    expect(restored.background, 0xFF000000);
    expect(restored.foreground, 0xFFABCDEF);
  });

  test('具名色板仍以自身颜色为准，不吃存储值', () {
    final restored = ReaderSettings.fromJson({
      'paletteId': 'sepia',
      'background': 0xFF000000,
      'foreground': 0xFFABCDEF,
    });
    expect(restored.paletteId, 'sepia');
    expect(restored.background, ReaderPalette.sepia.background);
    expect(restored.foreground, ReaderPalette.sepia.foreground);
  });
}
