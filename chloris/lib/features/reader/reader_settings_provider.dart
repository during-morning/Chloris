import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/persist/kv_settings.dart';

import '../../services/persist/vault_sync.dart';

import 'reader_palette.dart';

// 让 reader_screen（及其 part：chrome 层）无需改动即可引用 TTS 朗读控制器。
export 'tts_service.dart';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 19,
    this.lineHeight = 1.7,
    this.paragraphSpacing = 8,
    this.pageAnim = 1,
    this.background = 0xFFF7F7F5,
    this.foreground = 0xFF171717,
    this.paletteId = 'follow',
    this.chineseConvert = false,
    this.enableReplace = true,
    this.clickReverse = false,
    this.autoSeconds = 8,
    this.pagePadding = 24,
    this.brightness = 1.0,
    this.autoHideMenu = true,
    this.letterSpacing = 0,
    this.fontFamily = '',
    this.clickLeftRatio = 0.333,
    this.doublePage = 'auto',
    this.paragraphIndent = 2,
    this.keepScreenOn = false,
    this.orientation = 'auto',
  });

  final int fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final int pageAnim;
  final int background;
  final int foreground;
  final String paletteId;
  final bool chineseConvert;
  final bool enableReplace;
  final bool clickReverse;
  final int autoSeconds;
  final int pagePadding;
  final double brightness;
  final bool autoHideMenu;
  final double letterSpacing;
  final String fontFamily;
  final double clickLeftRatio;
  final String doublePage;

  /// 首行缩进字符数（对齐 legado ReadBookConfig.paragraphIndent，0 = 不缩进）。
  final int paragraphIndent;

  /// 阅读时屏幕常亮（对齐 legado keepScreenOn）。
  final bool keepScreenOn;

  /// 阅读时方向锁定：auto / portrait / landscape。
  final String orientation;

  ReaderPalette get palette => ReaderPalette.byId(paletteId);

  ReaderSettings copyWith({
    int? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    int? pageAnim,
    int? background,
    int? foreground,
    String? paletteId,
    bool? chineseConvert,
    bool? enableReplace,
    bool? clickReverse,
    int? autoSeconds,
    int? pagePadding,
    double? brightness,
    bool? autoHideMenu,
    double? letterSpacing,
    String? fontFamily,
    double? clickLeftRatio,
    String? doublePage,
    int? paragraphIndent,
    bool? keepScreenOn,
    String? orientation,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
        pageAnim: pageAnim ?? this.pageAnim,
        background: background ?? this.background,
        foreground: foreground ?? this.foreground,
        paletteId: paletteId ?? this.paletteId,
        chineseConvert: chineseConvert ?? this.chineseConvert,
        enableReplace: enableReplace ?? this.enableReplace,
        clickReverse: clickReverse ?? this.clickReverse,
        autoSeconds: autoSeconds ?? this.autoSeconds,
        pagePadding: pagePadding ?? this.pagePadding,
        brightness: brightness ?? this.brightness,
        autoHideMenu: autoHideMenu ?? this.autoHideMenu,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        fontFamily: fontFamily ?? this.fontFamily,
        clickLeftRatio: clickLeftRatio ?? this.clickLeftRatio,
        doublePage: doublePage ?? this.doublePage,
        paragraphIndent: paragraphIndent ?? this.paragraphIndent,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        orientation: orientation ?? this.orientation,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'pageAnim': pageAnim,
        'background': background,
        'foreground': foreground,
        'paletteId': paletteId,
        'chineseConvert': chineseConvert,
        'enableReplace': enableReplace,
        'clickReverse': clickReverse,
        'autoSeconds': autoSeconds,
        'pagePadding': pagePadding,
        'brightness': brightness,
        'autoHideMenu': autoHideMenu,
        'letterSpacing': letterSpacing,
        'fontFamily': fontFamily,
        'clickLeftRatio': clickLeftRatio,
        'doublePage': doublePage,
        'paragraphIndent': paragraphIndent,
        'keepScreenOn': keepScreenOn,
        'orientation': orientation,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    final bg = (json['background'] as num?)?.toInt() ?? 0xFFF7F7F5;
    final fg = (json['foreground'] as num?)?.toInt() ?? 0xFF171717;
    final rawId = json['paletteId']?.toString();
    final pal = (rawId != null && rawId.isNotEmpty)
        ? ReaderPalette.byId(rawId)
        : ReaderPalette.fromLegacy(bg, fg);
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toInt() ?? 19,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 8,
      pageAnim: (json['pageAnim'] as num?)?.toInt() ?? 1,
      background: pal.followApp ? bg : pal.background,
      foreground: pal.followApp ? fg : pal.foreground,
      paletteId: pal.id,
      chineseConvert: json['chineseConvert'] == true,
      enableReplace: json['enableReplace'] != false,
      clickReverse: json['clickReverse'] == true,
      autoSeconds: (json['autoSeconds'] as num?)?.toInt() ?? 8,
      pagePadding: (json['pagePadding'] as num?)?.toInt() ?? 24,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      autoHideMenu: json['autoHideMenu'] != false,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
      fontFamily: json['fontFamily']?.toString() ?? '',
      clickLeftRatio: (json['clickLeftRatio'] as num?)?.toDouble() ?? 0.333,
      doublePage: json['doublePage']?.toString() ?? 'auto',
      paragraphIndent: (json['paragraphIndent'] as num?)?.toInt() ?? 2,
      keepScreenOn: json['keepScreenOn'] == true,
      orientation: json['orientation']?.toString() ?? 'auto',
    );
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
  ReaderSettingsNotifier.new,
);

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  final Set<String> customFonts = <String>{};
  @override
  ReaderSettings build() {
    Future.microtask(_load);
    return const ReaderSettings();
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final fonts = p.getStringList('readerFonts') ?? const <String>[];
    customFonts.addAll(fonts);
    final raw = p.getString('readerSettings');
    if (raw == null || raw.isEmpty) return;
    try {
      state = ReaderSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {}
  }

  void update(ReaderSettings value) {
    state = value;
    KvSettings.ready().then((p) async {
      await p.setString('readerSettings', jsonEncode(value.toJson()));
      await syncVaultFromPrefs();
    });
  }

  void setPalette(ReaderPalette pal) {
    update(state.copyWith(
      paletteId: pal.id,
      background: pal.background,
      foreground: pal.foreground,
    ));
  }
}
