import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Reading paper. Default [follow] uses the current [AppThemeFamily]
/// paper/night pair so library and reader share one name and color.
class ReaderPalette {
  const ReaderPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.foreground,
    this.followApp = false,
  });

  final String id;
  final String label;
  final int background;
  final int foreground;
  final bool followApp;

  /// Whether the stored bg/fg are this paper's own data rather than a stale
  /// copy of its static colors. `follow` resolves against the live scheme and
  /// `custom` is the user's picked pair — reloading must keep their values.
  bool get usesStoredColors => followApp || id == 'custom';

  /// Follow paper takes the live family name; scene papers keep [label].
  String labelFor(AppThemeFamily family) => followApp ? family.label : label;

  Color bgColor(
    ColorScheme scheme, {
    int? overrideBg,
    AppThemeFamily? family,
    bool eink = false,
  }) {
    if (id == 'custom' && overrideBg != null) return Color(overrideBg);
    if (eink) return scheme.surface;
    if (followApp) return scheme.surface;
    return Color(background);
  }

  Color fgColor(
    ColorScheme scheme, {
    int? overrideFg,
    AppThemeFamily? family,
    bool eink = false,
  }) {
    if (id == 'custom' && overrideFg != null) return Color(overrideFg);
    if (eink) return scheme.onSurface;
    if (followApp) return scheme.onSurface;
    return Color(foreground);
  }

  static const follow = ReaderPalette(
    id: 'follow',
    label: '跟随应用',
    background: 0xFFF8FAF0,
    foreground: 0xFF1A1C16,
    followApp: true,
  );
  static const sepia = ReaderPalette(
    id: 'sepia',
    label: '羊皮',
    background: 0xFFF3E5C3,
    foreground: 0xFF3B2F1A,
  );
  static const eye = ReaderPalette(
    id: 'eye',
    label: '护眼',
    background: 0xFFC7EDCC,
    foreground: 0xFF143214,
  );
  static const night = ReaderPalette(
    id: 'night',
    label: '夜间',
    background: 0xFF1A1C19,
    foreground: 0xFFE4E2DE,
  );

  /// Console paper: pure black, matching the terminal chrome.
  static const mono = ReaderPalette(
    id: 'mono',
    label: '纯黑',
    background: 0xFF000000,
    foreground: 0xFFF2F2F2,
  );

  /// Warm ivory paper, matching the Absolutely canvas (#F0EEE6).
  ///
  /// Deliberately *not* id `paper`: that id is already persisted by older
  /// builds to mean "follow the app paper", so it must keep resolving to
  /// [follow].
  static const canvas = ReaderPalette(
    id: 'canvas',
    label: '纸白',
    background: 0xFFF0EEE6,
    foreground: 0xFF191919,
  );

  static const custom = ReaderPalette(
    id: 'custom',
    label: '自定义',
    background: 0xFFF7F7F5,
    foreground: 0xFF171717,
  );

  /// Scene papers only. App families live in 外观 / the color dots.
  static const List<ReaderPalette> all = [follow, sepia, eye, night];

  /// Papers offered by a UI style. Absolutely is an editorial palette (no
  /// high-saturation eye-green), terminal is monochrome.
  static List<ReaderPalette> forStyle(AppUiStyle style) => switch (style) {
    AppUiStyle.absolutely => const [follow, canvas, sepia, night],
    AppUiStyle.terminal => const [follow, mono, night],
    AppUiStyle.classic => all,
  };

  static ReaderPalette byId(String? id) {
    switch (id) {
      case 'sepia':
      case 'cream':
        return sepia;
      case 'eye':
        return eye;
      case 'night':
      case 'ink':
        return night;
      case 'mono':
        return mono;
      case 'canvas':
        return canvas;
      case 'custom':
        return custom;
      default:
        return follow;
    }
  }

  static ReaderPalette fromLegacy(int background, int foreground) {
    if (background == sepia.background) return sepia;
    if (background == eye.background) return eye;
    if (background == night.background) return night;
    if (background == mono.background) return mono;
    return follow;
  }
}
