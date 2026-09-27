import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Global UI language. Color families remain available to the classic style.
///
/// * [classic] — Material 3 seeded colour, 13 families, e-ink/flat variant.
/// * [absolutely]  — warm editorial ("Cowork"): paper canvas, serif display,
///               hairline rules, one clay accent reserved for primary actions.
/// * [terminal] — opencode-style console: pure monochrome, monospace
///               throughout, 1px boxes, zero radius.
enum AppUiStyle {
  classic,
  absolutely,
  terminal;

  String get id => name;
  String get label => switch (this) {
    AppUiStyle.classic => '经典',
    AppUiStyle.absolutely => 'Absolutely',
    AppUiStyle.terminal => '终端',
  };

  ThemeMode? get fixedThemeMode => switch (this) {
    AppUiStyle.classic => null,
    // Absolutely now offers both paper (light) and slate (dark) canvases, so the
    // user's theme mode applies; terminal stays pinned to dark.
    AppUiStyle.absolutely => null,
    AppUiStyle.terminal => ThemeMode.dark,
  };

  /// One-line description shown in 外观.
  String get blurb => switch (this) {
    AppUiStyle.classic => 'Material 3 · 13 套配色 · 墨水屏',
    AppUiStyle.absolutely => '暖纸编辑部 · 衬线标题 · 浅/深可调',
    AppUiStyle.terminal => '黑白单色 · 等宽 · 固定深色',
  };

  static AppUiStyle byId(String? value) => switch (value) {
    // 'claude' is the legacy persisted id; migrate targets silently accept
    // it and main.dart writes 'absolutely' back on first launch.
    'claude' => AppUiStyle.absolutely,
    'absolutely' => AppUiStyle.absolutely,
    'terminal' => AppUiStyle.terminal,
    _ => AppUiStyle.classic,
  };
}

/// Style-specific layout and icon tokens exposed through [ThemeData].
///
/// Screens read shape/measure from here instead of branching on [AppUiStyle],
/// so a new style only has to describe itself once.
@immutable
class AppStyleExtension extends ThemeExtension<AppStyleExtension> {
  const AppStyleExtension({
    required this.style,
    required this.pageRadius,
    required this.controlRadius,
    required this.chipRadius,
    required this.compact,
    required this.iconSize,
    required this.pagePadding,
    required this.railWidth,
    required this.contentMaxWidth,
    this.buttonRadius,
    this.filledIcons = true,
    this.readerFamily,
    this.headerRule = false,
  });

  final AppUiStyle style;

  /// Radius for cards, panels, sheets and dialogs.
  final double pageRadius;

  /// Radius for buttons, fields and other interactive controls.
  final double controlRadius;

  /// Radius for buttons only. Absolutely uses full capsules (official pill
  /// grammar) while fields and list tiles keep [controlRadius]. Falls back
  /// to [controlRadius] when null.
  final double? buttonRadius;

  /// Whether the active/selected state may switch to a filled glyph.
  /// Absolutely's official icon language is outline-only — activation is
  /// expressed through ink depth, never fill — so it sets this to false.
  final bool filledIcons;

  double get effectiveButtonRadius => buttonRadius ?? controlRadius;

  /// Radius for chips/tags. `999` means a full capsule.
  final double chipRadius;

  final bool compact;
  final double iconSize;
  final double pagePadding;

  /// Width of the extended navigation rail.
  final double railWidth;

  /// Widest comfortable content column for this style.
  final double contentMaxWidth;

  /// Default reader body family when the user has not chosen one.
  /// Absolutely reads like a book (serif); terminal reads like a console (mono).
  final String? readerFamily;

  /// Whether page chrome draws a hairline under the title block.
  final bool headerRule;

  bool get mono => style == AppUiStyle.terminal;
  bool get isCapsuleChip => chipRadius >= 100;

  @override
  AppStyleExtension copyWith({
    AppUiStyle? style,
    double? pageRadius,
    double? controlRadius,
    double? chipRadius,
    bool? compact,
    double? iconSize,
    double? pagePadding,
    double? railWidth,
    double? contentMaxWidth,
    double? buttonRadius,
    bool? filledIcons,
    String? readerFamily,
    bool? headerRule,
  }) => AppStyleExtension(
    style: style ?? this.style,
    pageRadius: pageRadius ?? this.pageRadius,
    controlRadius: controlRadius ?? this.controlRadius,
    chipRadius: chipRadius ?? this.chipRadius,
    compact: compact ?? this.compact,
    iconSize: iconSize ?? this.iconSize,
    pagePadding: pagePadding ?? this.pagePadding,
    railWidth: railWidth ?? this.railWidth,
    contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
    buttonRadius: buttonRadius ?? this.buttonRadius,
    filledIcons: filledIcons ?? this.filledIcons,
    readerFamily: readerFamily ?? this.readerFamily,
    headerRule: headerRule ?? this.headerRule,
  );

  @override
  AppStyleExtension lerp(ThemeExtension<AppStyleExtension>? other, double t) {
    if (other is! AppStyleExtension) return this;
    return AppStyleExtension(
      style: t < .5 ? style : other.style,
      pageRadius: lerpDouble(pageRadius, other.pageRadius, t)!,
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t)!,
      chipRadius: lerpDouble(chipRadius, other.chipRadius, t)!,
      compact: t < .5 ? compact : other.compact,
      iconSize: lerpDouble(iconSize, other.iconSize, t)!,
      pagePadding: lerpDouble(pagePadding, other.pagePadding, t)!,
      railWidth: lerpDouble(railWidth, other.railWidth, t)!,
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      buttonRadius: t < .5 ? buttonRadius : other.buttonRadius,
      filledIcons: t < .5 ? filledIcons : other.filledIcons,
      readerFamily: t < .5 ? readerFamily : other.readerFamily,
      headerRule: t < .5 ? headerRule : other.headerRule,
    );
  }
}

/// Named Material 3 seeds. Reader "跟随应用" uses the live ColorScheme.
class AppThemeFamily {
  const AppThemeFamily({
    required this.id,
    required this.label,
    required this.seed,
    this.paperBg = 0xFFF8FAF0,
    this.paperFg = 0xFF1A1C16,
    this.nightBg = 0xFF1A1C19,
    this.nightFg = 0xFFE4E2DE,
  });

  final String id;
  final String label;
  final Color seed;

  /// Reader paper (light) — same name as the app family.
  final int paperBg;
  final int paperFg;
  final int nightBg;
  final int nightFg;

  static const green = AppThemeFamily(
    id: 'green',
    label: '阅读绿',
    seed: Color(0xFF3F6B1D),
    paperBg: 0xFFEEF4DC,
    paperFg: 0xFF14210C,
    nightBg: 0xFF12180E,
    nightFg: 0xFFE4E6DA,
  );
  static const blue = AppThemeFamily(
    id: 'blue',
    label: '靛蓝',
    seed: Color(0xFF155A96),
    paperBg: 0xFFE8F0F8,
    paperFg: 0xFF0E1A28,
    nightBg: 0xFF0E1620,
    nightFg: 0xFFD7E3F0,
  );
  static const purple = AppThemeFamily(
    id: 'purple',
    label: '暮紫',
    seed: Color(0xFF5A3D9E),
    paperBg: 0xFFF3EDF8,
    paperFg: 0xFF1A1028,
    nightBg: 0xFF161020,
    nightFg: 0xFFE8DEF8,
  );
  static const red = AppThemeFamily(
    id: 'red',
    label: '朱红',
    seed: Color(0xFFA31B16),
    paperBg: 0xFFF8EBE8,
    paperFg: 0xFF2A100C,
    nightBg: 0xFF1C1010,
    nightFg: 0xFFF5DDD9,
  );
  static const orange = AppThemeFamily(
    id: 'orange',
    label: '琥珀',
    seed: Color(0xFF8A4B00),
    paperBg: 0xFFF8EFE4,
    paperFg: 0xFF2A1808,
    nightBg: 0xFF1C140C,
    nightFg: 0xFFF0E0C8,
  );
  static const teal = AppThemeFamily(
    id: 'teal',
    label: '青瓷',
    seed: Color(0xFF0A5C5C),
    paperBg: 0xFFE8F4F0,
    paperFg: 0xFF0C1E1C,
    nightBg: 0xFF0C1816,
    nightFg: 0xFFCCE8E4,
  );
  static const pink = AppThemeFamily(
    id: 'pink',
    label: '梅粉',
    seed: Color(0xFFA10058),
    paperBg: 0xFFF9E8EE,
    paperFg: 0xFF2A1018,
    nightBg: 0xFF1C1014,
    nightFg: 0xFFFFD9E4,
  );
  static const yellow = AppThemeFamily(
    id: 'yellow',
    label: '麦黄',
    seed: Color(0xFF7A5200),
    paperBg: 0xFFF8F3DC,
    paperFg: 0xFF2A1C08,
    nightBg: 0xFF1A1408,
    nightFg: 0xFFF5E6C0,
  );
  static const brown = AppThemeFamily(
    id: 'brown',
    label: '胡桃',
    seed: Color(0xFF6E3F1C),
    paperBg: 0xFFF4EBE3,
    paperFg: 0xFF24160C,
    nightBg: 0xFF18120C,
    nightFg: 0xFFE8D5C4,
  );
  static const cyan = AppThemeFamily(
    id: 'cyan',
    label: '晴空',
    seed: Color(0xFF006A7A),
    paperBg: 0xFFE6F3F6,
    paperFg: 0xFF0C1C20,
    nightBg: 0xFF0C181A,
    nightFg: 0xFFCDE7EC,
  );
  static const lime = AppThemeFamily(
    id: 'lime',
    label: '芽绿',
    seed: Color(0xFF4E6200),
    paperBg: 0xFFF2F6E0,
    paperFg: 0xFF161C08,
    nightBg: 0xFF12160A,
    nightFg: 0xFFD7E6C8,
  );
  static const indigo = AppThemeFamily(
    id: 'indigo',
    label: '靛蓝深',
    seed: Color(0xFF2F49E0),
    paperBg: 0xFFE8EAF8,
    paperFg: 0xFF101228,
    nightBg: 0xFF0E1224,
    nightFg: 0xFFDDE1FF,
  );
  static const gray = AppThemeFamily(
    id: 'gray',
    label: '石墨',
    seed: Color(0xFF3D3D3D),
    paperBg: 0xFFEEEEEE,
    paperFg: 0xFF111111,
    nightBg: 0xFF101010,
    nightFg: 0xFFE6E6E6,
  );

  static const List<AppThemeFamily> all = [
    green,
    lime,
    teal,
    cyan,
    blue,
    indigo,
    purple,
    pink,
    red,
    orange,
    yellow,
    brown,
    gray,
  ];

  static AppThemeFamily byId(String? id) {
    switch (id) {
      case 'md-green':
        return green;
      case 'md-blue':
        return blue;
      case 'md-purple':
        return purple;
      case 'md-red':
        return red;
      case 'md-orange':
        return orange;
      case 'md-teal':
        return teal;
      case 'md-pink':
        return pink;
      case 'md-yellow':
        return yellow;
      case 'md-brown':
        return brown;
      case 'md-cyan':
        return cyan;
      case 'md-lime':
        return lime;
      case 'md-gray':
        return gray;
    }
    for (final f in all) {
      if (f.id == id) return f;
    }
    return green;
  }
}

/// Material 3 color/type/shape, plus a zero-motion eink/flat variant.
abstract final class AppTheme {
  static ThemeData light(
    AppThemeFamily family, {
    bool eink = false,
    AppUiStyle style = AppUiStyle.classic,
    bool highContrast = false,
  }) => _build(
    Brightness.light,
    family,
    eink: eink,
    style: style,
    highContrast: highContrast,
  );

  static ThemeData dark(
    AppThemeFamily family, {
    bool eink = false,
    AppUiStyle style = AppUiStyle.classic,
    bool highContrast = false,
  }) => _build(
    Brightness.dark,
    family,
    eink: eink,
    style: style,
    highContrast: highContrast,
  );

  static ThemeData _build(
    Brightness brightness,
    AppThemeFamily family, {
    required bool eink,
    required AppUiStyle style,
    bool highContrast = false,
  }) {
    if (style == AppUiStyle.absolutely) {
      return _absolutelyTheme(brightness, highContrast: highContrast);
    }
    if (style == AppUiStyle.terminal) {
      return _terminalTheme(highContrast: highContrast);
    }
    final scheme = eink
        ? _einkScheme(brightness)
        : _classicScheme(family, brightness, highContrast: highContrast);
    final isWeb = kIsWeb;
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    // Do not apply CJK fontFamilyFallback on the whole TextTheme: CanvasKit
    // then uses PingFang/Noto for Material Icon PUA codepoints (box-with-X).
    // The classic style therefore stays fallback-free; the bundled pan-CJK
    // face still covers Chinese with it because Skia falls back across every
    // font registered with the engine. The Absolutely and terminal styles do
    // carry an explicit stack, and are verified not to disturb icon glyphs.
    final textTheme = brightness == Brightness.dark
        ? typography.white
        : typography.black;
    final radius = eink ? 0.0 : 12.0;
    final controlRadius = eink ? 0.0 : 28.0;
    final stadium = eink
        ? const RoundedRectangleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: !eink,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: eink
          ? NoSplash.splashFactory
          : (isWeb ? InkRipple.splashFactory : InkSparkle.splashFactory),
      highlightColor: eink ? Colors.transparent : null,
      splashColor: eink ? Colors.transparent : null,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      typography: typography,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 23),
      primaryIconTheme: IconThemeData(color: scheme.onSurface, size: 23),
      extensions: [
        AppStyleExtension(
          style: AppUiStyle.classic,
          pageRadius: radius,
          controlRadius: controlRadius,
          chipRadius: eink ? 0 : 8,
          compact: false,
          iconSize: 23,
          pagePadding: 16,
          railWidth: AppTokens.absolutelyRail,
          contentMaxWidth: AppTokens.maxListWidth,
        ),
      ],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: eink
            ? {
                for (final p in TargetPlatform.values)
                  p: const _InstantPageTransitionsBuilder(),
              }
            : const {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
              },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: eink ? 0 : 3,
        surfaceTintColor: eink ? Colors.transparent : scheme.surfaceTint,
        centerTitle: false,
        shape: eink
            ? Border(bottom: BorderSide(color: scheme.outline, width: 1))
            : null,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: eink ? Colors.transparent : scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(
          color: eink ? scheme.onSurface : scheme.onSecondaryContainer,
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        useIndicator: !eink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: eink ? Colors.transparent : scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (eink ? scheme.onSurface : scheme.onSecondaryContainer)
                : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: stadium,
          side: eink ? BorderSide(color: scheme.outline) : null,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: stadium,
          side: BorderSide(color: scheme.outline, width: eink ? 1.5 : 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppTokens.touchTarget),
          shape: stadium,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(
          side: BorderSide(
            color: eink ? scheme.outline : scheme.outlineVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(eink ? 0 : 8),
          side: BorderSide(color: scheme.outline),
        ),
        selectedColor: eink ? scheme.surface : scheme.secondaryContainer,
        side: BorderSide(color: scheme.outline),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: !eink,
        fillColor: eink ? scheme.surface : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      // SearchBar defaults to elevation 6, which produces a heavy, offset
      // shadow in CanvasKit/Web and makes the control look detached from the
      // page surface. Keep the M3 pill shape with a flat surface and a clear
      // outline so the field remains readable without the artificial drop
      // shadow.
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double?>(0),
        backgroundColor: WidgetStatePropertyAll<Color>(
          eink ? scheme.surface : scheme.surfaceContainerLow,
        ),
        shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        side: WidgetStatePropertyAll<BorderSide?>(
          BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.72)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: eink ? BorderSide(color: scheme.outline) : BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(eink ? 0 : 8),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: eink ? scheme.surface : scheme.primaryContainer,
        foregroundColor: eink ? scheme.onSurface : scheme.onPrimaryContainer,
        elevation: eink ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(eink ? 0 : 16),
          side: eink ? BorderSide(color: scheme.outline) : BorderSide.none,
        ),
      ),
    );
  }

  static ColorScheme _einkScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    return ColorScheme(
      brightness: brightness,
      primary: dark ? white : black,
      onPrimary: dark ? black : white,
      primaryContainer: dark ? const Color(0xFF111111) : white,
      onPrimaryContainer: dark ? white : black,
      secondary: dark ? white : black,
      onSecondary: dark ? black : white,
      secondaryContainer: dark ? const Color(0xFF111111) : white,
      onSecondaryContainer: dark ? white : black,
      tertiary: dark ? white : black,
      onTertiary: dark ? black : white,
      tertiaryContainer: dark ? const Color(0xFF111111) : white,
      onTertiaryContainer: dark ? white : black,
      error: dark ? white : black,
      onError: dark ? black : white,
      errorContainer: dark ? const Color(0xFF111111) : white,
      onErrorContainer: dark ? white : black,
      surface: dark ? black : white,
      onSurface: dark ? white : black,
      onSurfaceVariant: dark
          ? const Color(0xFFDDDDDD)
          : const Color(0xFF222222),
      outline: dark ? white : black,
      outlineVariant: dark ? const Color(0xFF888888) : const Color(0xFF000000),
      shadow: black,
      scrim: black,
      inverseSurface: dark ? white : black,
      onInverseSurface: dark ? black : white,
      inversePrimary: dark ? black : white,
      surfaceTint: Colors.transparent,
    );
  }

  static ColorScheme _classicScheme(
    AppThemeFamily family,
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final seeded = ColorScheme.fromSeed(
      seedColor: family.seed,
      brightness: brightness,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    if (highContrast) return seeded;
    final paper = brightness == Brightness.dark
        ? family.nightBg
        : family.paperBg;
    final ink = brightness == Brightness.dark ? family.nightFg : family.paperFg;
    // Blend a light paper tint onto Material's surface so the app stays
    // readable on iPad / desktop instead of flooding the screen with dye.
    final wash = Color.lerp(seeded.surface, Color(paper), 0.42)!;
    return seeded.copyWith(surface: wash, onSurface: Color(ink));
  }

  // =====================================================================
  // Absolutely — warm editorial ("Cowork")
  // =====================================================================

  /// Editorial display face. [PTSerif] ships with the app so the style looks
  /// the same on every platform — including CanvasKit, which cannot resolve
  /// platform fonts. The rest of the stack is for hosts that have the
  /// original faces installed.
  /// Pan-CJK faces bundled with the app. Without them the web build renders
  /// Chinese as tofu whenever the engine cannot reach fonts.gstatic.com.
  static const cjkSansFallback = 'NotoSansSC';
  static const cjkSerifFallback = 'NotoSerifSC';

  static const absolutelySerif = 'PTSerif';
  static const absolutelySerifFallback = <String>[
    'Source Serif 4',
    'Georgia',
    'Iowan Old Style',
    'Times New Roman',
    'NotoSerifSC',
    'Songti SC',
    'Noto Serif SC',
    cjkSansFallback,
    'serif',
  ];

  /// UI face for chrome, labels and buttons.
  static const absolutelySans = 'SourceSansPro';

  /// Editorial subtitle: the official look keeps subtitles serif — muted,
  /// airy (1.45), a step above body size. Use for hero blocks and section
  /// intros.
  static TextStyle absolutelySubtitle(ThemeData theme) => TextStyle(
    fontFamily: absolutelySerif,
    fontFamilyFallback: absolutelySerifFallback,
    fontSize: 17,
    height: 1.45,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    color: theme.colorScheme.onSurfaceVariant,
  );
  static const absolutelySansFallback = <String>[
    'Inter',
    '-apple-system',
    'SF Pro Text',
    'Segoe UI',
    cjkSansFallback,
    'PingFang SC',
    'sans-serif',
  ];

  /// Font fallback stack for reader body text in [style]. Empty for the
  /// classic style, which keeps the platform default.
  static List<String> readerFallbackFor(AppUiStyle style) => switch (style) {
    AppUiStyle.absolutely => absolutelySerifFallback,
    AppUiStyle.terminal => terminalMonoFallback,
    AppUiStyle.classic => const <String>[],
  };

  // Official Absolutely brand palette.
  // Light: ivory paper (oat) #F0EEE6 family, near-black ink #191919, warm
  // grey secondary text, hairlines; the single clay accent #D97757 is
  // reserved for primary actions and a handful of emphasis moments.
  // A lavender auxiliary (#7B76C2 family) covers badge/tag semantics — the
  // official "NEW" pill colour.
  // Dark: warm slate #1F1E1D (never pure black) with cream text.
  static const _paper = Color(0xFFF0EEE6);
  static const _paperDeep = Color(0xFFE9E6DC);
  static const _raised = Color(0xFFFAF9F5);
  static const _ink = Color(0xFF191919);
  static const _inkMuted = Color(0xFF6E6A61);
  static const _line = Color(0xFFE3DFD4);
  static const _lineStrong = Color(0xFFC7C1B2);
  static const _clay = Color(0xFFD97757);
  static const _claySoft = Color(0xFFF7E7DE);
  static const _lavender = Color(0xFF7B76C2);
  static const _lavenderSoft = Color(0xFFDEDCF6);

  static ColorScheme _absolutelyScheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    var scheme = dark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFFE08A66),
            onPrimary: Color(0xFF3A1A0E),
            primaryContainer: Color(0xFF4E2617),
            onPrimaryContainer: Color(0xFFF8D9C9),
            secondary: Color(0xFFC8BFB0),
            onSecondary: Color(0xFF2A251D),
            secondaryContainer: Color(0xFF3A362F),
            onSecondaryContainer: Color(0xFFE7E1D6),
            tertiary: Color(0xFFA5A1E0),
            onTertiary: Color(0xFF232150),
            tertiaryContainer: Color(0xFF3A3757),
            onTertiaryContainer: Color(0xFFE2E0F8),
            error: Color(0xFFF09A8C),
            onError: Color(0xFF4A1710),
            errorContainer: Color(0xFF5A231A),
            onErrorContainer: Color(0xFFF8DDD7),
            surface: Color(0xFF1F1E1D),
            onSurface: Color(0xFFF4F2EC),
            surfaceDim: Color(0xFF191817),
            surfaceBright: Color(0xFF3A3836),
            surfaceContainerLowest: Color(0xFF151413),
            surfaceContainerLow: Color(0xFF242322),
            surfaceContainer: Color(0xFF292826),
            surfaceContainerHigh: Color(0xFF302F2C),
            surfaceContainerHighest: Color(0xFF383632),
            onSurfaceVariant: Color(0xFFB5AFA2),
            outline: Color(0xFF6A655C),
            outlineVariant: Color(0xFF3C3A36),
            shadow: Color(0xFF000000),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFFF4F2EC),
            onInverseSurface: Color(0xFF1F1E1D),
            inversePrimary: _clay,
            surfaceTint: Color(0x00000000),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: _clay,
            onPrimary: Color(0xFFFFFFFF),
            primaryContainer: _claySoft,
            onPrimaryContainer: Color(0xFF4A2314),
            secondary: Color(0xFF7D7367),
            onSecondary: Color(0xFFFFFFFF),
            secondaryContainer: Color(0xFFEDE7DC),
            onSecondaryContainer: Color(0xFF2A251D),
            tertiary: _lavender,
            onTertiary: Color(0xFFFFFFFF),
            tertiaryContainer: _lavenderSoft,
            onTertiaryContainer: Color(0xFF2D2A5E),
            error: Color(0xFFB3392B),
            onError: Color(0xFFFFFFFF),
            errorContainer: Color(0xFFF7E0DB),
            onErrorContainer: Color(0xFF4A1710),
            surface: _paper,
            onSurface: _ink,
            surfaceDim: Color(0xFFE8E5DC),
            surfaceBright: Color(0xFFFAF9F5),
            surfaceContainerLowest: _raised,
            surfaceContainerLow: Color(0xFFF5F3EC),
            surfaceContainer: _paperDeep,
            surfaceContainerHigh: Color(0xFFE5E1D6),
            surfaceContainerHighest: Color(0xFFDFDACE),
            onSurfaceVariant: _inkMuted,
            outline: _lineStrong,
            outlineVariant: _line,
            shadow: Color(0xFF191919),
            scrim: Color(0xFF000000),
            inverseSurface: Color(0xFF262624),
            onInverseSurface: Color(0xFFF5F4EF),
            inversePrimary: _clay,
            surfaceTint: Color(0x00000000),
          );
    if (highContrast) {
      scheme = scheme.copyWith(
        onSurface: dark ? Colors.white : Colors.black,
        onSurfaceVariant: dark
            ? const Color(0xFFF2EFE8)
            : const Color(0xFF3A362F),
        outline: dark ? const Color(0xFFC6C0B2) : const Color(0xFF6E6A61),
        outlineVariant: dark
            ? const Color(0xFF6A655C)
            : const Color(0xFFB8B2A3),
        primary: dark ? const Color(0xFFFFB08F) : const Color(0xFF9C4526),
      );
    }
    return scheme;
  }

  static ThemeData _absolutelyTheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = _absolutelyScheme(brightness, highContrast: highContrast);
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final base = (dark ? typography.white : typography.black).apply(
      fontFamily: absolutelySans,
      fontFamilyFallback: absolutelySansFallback,
      displayColor: scheme.onSurface,
      bodyColor: scheme.onSurface,
    );
    TextStyle? serif(
      TextStyle? s, {
      double? size,
      double? tracking,
      double? h,
    }) => s?.copyWith(
      fontFamily: absolutelySerif,
      fontFamilyFallback: absolutelySerifFallback,
      fontSize: size,
      letterSpacing: tracking,
      height: h,
      color: scheme.onSurface,
    );
    final textTheme = base.copyWith(
      // Display / headline: serif, never bold (w400-w500), tracking tightens
      // as size grows — the official display grammar.
      displayLarge: serif(
        base.displayLarge,
        size: 44,
        tracking: -1.8,
        h: 1.1,
      )?.copyWith(fontWeight: FontWeight.w400),
      displayMedium: serif(
        base.displayMedium,
        size: 36,
        tracking: -1.3,
        h: 1.12,
      )?.copyWith(fontWeight: FontWeight.w400),
      displaySmall: serif(
        base.displaySmall,
        size: 30,
        tracking: -0.9,
        h: 1.15,
      )?.copyWith(fontWeight: FontWeight.w400),
      headlineMedium: serif(
        base.headlineMedium,
        size: 26,
        tracking: -0.6,
        h: 1.2,
      )?.copyWith(fontWeight: FontWeight.w500),
      headlineSmall: serif(
        base.headlineSmall,
        size: 22,
        tracking: -0.4,
        h: 1.25,
      )?.copyWith(fontWeight: FontWeight.w500),
      titleLarge: serif(
        base.titleLarge,
        size: 19,
        tracking: -0.2,
        h: 1.3,
      )?.copyWith(fontWeight: FontWeight.w500),
      // Sans UI tier. w500 renders as regular (the bundled face ships 400 and
      // 600); boldness comes from the w600 labels on buttons only.
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.35,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.6, letterSpacing: 0.1),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.55, letterSpacing: 0.1),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      // Eyebrows / small labels: no industrial wide-tracked uppercase — the
      // official look is a quiet small sans, slightly spaced.
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );

    const page = 16.0;
    const control = 8.0;
    const chip = 999.0;
    // Official button grammar: fully round pills, ink-black for the primary
    // action, hairline outline for the secondary. Clay stays reserved.
    const pill = StadiumBorder();
    final pageShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(page),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(control),
    );
    final chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(chip),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final flatCardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(page),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      typography: typography,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // Icons are monochrome: ink for the active level, warm grey for the
      // secondary level. No icon ever takes the clay accent.
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      primaryIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      extensions: const [
        AppStyleExtension(
          style: AppUiStyle.absolutely,
          pageRadius: page,
          controlRadius: control,
          chipRadius: chip,
          buttonRadius: 999,
          filledIcons: false,
          compact: false,
          iconSize: 22,
          pagePadding: 32,
          railWidth: AppTokens.absolutelyRail,
          contentMaxWidth: AppTokens.absolutelyColumn,
          readerFamily: absolutelySerif,
          headerRule: true,
        ),
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        // Official sidebar: a quiet pill, no border, one step above paper.
        indicatorColor: scheme.surfaceContainerHigh,
        indicatorShape: const StadiumBorder(),
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: textTheme.labelLarge!.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.surfaceContainerHigh,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            letterSpacing: 0.2,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // The ink pill: official primary action. Clay (#D97757) is not
          // spent here — screens reserve it for the one decisive CTA via
          // an explicit style override.
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.surface,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          disabledForegroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(48, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: pill,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: pill,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(44, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        // Quiet raised panel: one step above the paper, no border, no shadow.
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: flatCardShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        // Selection is an ink surface. Lavender remains reserved for semantic
        // badges; using it here made the dark filter chip visibly purple.
        selectedColor: scheme.surfaceContainerHigh,
        secondarySelectedColor: scheme.surfaceContainerHigh,
        side: BorderSide(color: scheme.outlineVariant),
        shape: chipShape,
        showCheckmark: false,
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return (textTheme.labelLarge ?? const TextStyle()).copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        secondaryLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          return (textTheme.labelLarge ?? const TextStyle()).copyWith(
            color: scheme.onSurface,
          );
        }),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(control),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double?>(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(control),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: pageShape,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(page)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyMedium,
        shape: pageShape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        // The ink pill toast.
        shape: const StadiumBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: controlShape,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        // Ink takes over every selection state; clay stays reserved.
        activeTrackColor: scheme.onSurface,
        inactiveTrackColor: scheme.surfaceContainerHigh,
        thumbColor: scheme.onSurface,
        overlayColor: scheme.onSurface.withValues(alpha: 0.10),
        trackHeight: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.surface;
          return scheme.surfaceContainerLowest;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.surface),
        side: BorderSide(color: scheme.outline, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      // Editorial tabs: ink labels, hairline ink indicator — no coloured wash.
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorColor: scheme.onSurface,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
      ),
      // The one place clay bleeds into everyday chrome: the text caret and
      // selection wash — the official coral cursor.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.18),
        selectionHandleColor: scheme.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // The FAB is the "one decisive action" — the home of clay.
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => scheme.onSurface.withValues(
            alpha: s.contains(WidgetState.hovered) ? 0.32 : 0.18,
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // Terminal — opencode-style monochrome console
  // =====================================================================

  /// Everything is monospace. [IBMPlexMono] ships with the app; `monospace`
  /// stays last so a generic family still resolves if all else fails.
  static const terminalMono = 'IBMPlexMono';
  static const terminalMonoFallback = <String>[
    'IBM Plex Mono',
    'SF Mono',
    'Menlo',
    'Consolas',
    'DejaVu Sans Mono',
    cjkSansFallback,
    'monospace',
  ];

  static const _tBlack = Color(0xFF000000);
  static const _tCanvas = Color(0xFF0A0A0A);
  static const _tPanel = Color(0xFF141414);
  static const _tPanelHigh = Color(0xFF1A1A1A);
  static const _tField = Color(0xFF0F0F0F);
  static const _tInk = Color(0xFFF2F2F2);
  static const _tInkDim = Color(0xFF9B9B9B);
  static const _tLine = Color(0xFF2A2A2A);
  static const _tLineStrong = Color(0xFF4A4A4A);

  static ThemeData _terminalTheme({bool highContrast = false}) {
    var scheme = const ColorScheme(
      brightness: Brightness.dark,
      // Monochrome: "primary" is pure white, so filled controls read as an
      // inverted terminal cell rather than a brand colour.
      primary: _tInk,
      onPrimary: _tBlack,
      primaryContainer: _tPanelHigh,
      onPrimaryContainer: _tInk,
      secondary: Color(0xFFC8C8C8),
      onSecondary: _tBlack,
      secondaryContainer: Color(0xFFFFFFFF),
      onSecondaryContainer: _tBlack,
      tertiary: Color(0xFFB4B4B4),
      onTertiary: _tBlack,
      tertiaryContainer: _tPanelHigh,
      onTertiaryContainer: _tInk,
      error: _tInk,
      onError: _tBlack,
      errorContainer: _tPanelHigh,
      onErrorContainer: _tInk,
      surface: _tCanvas,
      onSurface: _tInk,
      surfaceDim: Color(0xFF050505),
      surfaceBright: Color(0xFF303030),
      surfaceContainerLowest: _tBlack,
      surfaceContainerLow: _tField,
      surfaceContainer: _tPanel,
      surfaceContainerHigh: _tPanelHigh,
      surfaceContainerHighest: Color(0xFF212121),
      onSurfaceVariant: _tInkDim,
      outline: _tLineStrong,
      outlineVariant: _tLine,
      shadow: _tBlack,
      scrim: _tBlack,
      inverseSurface: _tInk,
      onInverseSurface: _tBlack,
      inversePrimary: _tBlack,
      surfaceTint: Color(0x00000000),
    );
    if (highContrast) {
      scheme = scheme.copyWith(
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFD6D6D6),
        outline: const Color(0xFFB0B0B0),
        outlineVariant: const Color(0xFF6A6A6A),
      );
    }
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final base = typography.white.apply(
      fontFamily: terminalMono,
      fontFamilyFallback: terminalMonoFallback,
      displayColor: scheme.onSurface,
      bodyColor: scheme.onSurface,
    );
    TextStyle? mono(
      TextStyle? s, {
      double? size,
      double? tracking,
      double? h,
    }) => s?.copyWith(
      fontFamily: terminalMono,
      fontFamilyFallback: terminalMonoFallback,
      fontSize: size,
      letterSpacing: tracking,
      height: h,
    );
    final textTheme = base.copyWith(
      displayLarge: mono(base.displayLarge, size: 30, tracking: -0.4, h: 1.15),
      displayMedium: mono(base.displayMedium, size: 26, tracking: -0.2, h: 1.2),
      displaySmall: mono(base.displaySmall, size: 23, tracking: 0, h: 1.2),
      headlineMedium: mono(
        base.headlineMedium,
        size: 20,
        tracking: 0.2,
        h: 1.25,
      ),
      headlineSmall: mono(base.headlineSmall, size: 18, tracking: 0.2, h: 1.3),
      titleLarge: mono(base.titleLarge, size: 16, tracking: 0.3, h: 1.3),
      titleMedium: mono(base.titleMedium, size: 14, tracking: 0.3, h: 1.35),
      titleSmall: mono(base.titleSmall, size: 13, tracking: 0.3, h: 1.35),
      bodyLarge: mono(base.bodyLarge, size: 14, tracking: 0.1, h: 1.55),
      bodyMedium: mono(base.bodyMedium, size: 13, tracking: 0.1, h: 1.5),
      bodySmall: mono(base.bodySmall, size: 11.5, tracking: 0.2, h: 1.45),
      labelLarge: mono(base.labelLarge, size: 12, tracking: 0.9, h: 1.2),
      labelMedium: mono(base.labelMedium, size: 11, tracking: 1.1, h: 1.2),
      labelSmall: mono(base.labelSmall, size: 10, tracking: 1.5, h: 1.2),
    );

    const radius = 0.0;
    final box = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final boxStrong = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: scheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      visualDensity: VisualDensity.compact,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.05),
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      typography: typography,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 19),
      primaryIconTheme: IconThemeData(color: scheme.onSurface, size: 19),
      extensions: const [
        AppStyleExtension(
          style: AppUiStyle.terminal,
          pageRadius: radius,
          controlRadius: radius,
          chipRadius: radius,
          compact: true,
          iconSize: 19,
          pagePadding: 16,
          railWidth: AppTokens.terminalRail,
          contentMaxWidth: AppTokens.terminalColumn,
          readerFamily: terminalMono,
          headerRule: true,
        ),
      ],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: const _InstantPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        // Selection is a 1px white frame: the terminal's only emphasis.
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.onSurface),
        ),
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: scheme.onSurface, size: 19),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 19,
        ),
        selectedLabelTextStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.onSurface),
        ),
        elevation: 0,
        height: 56,
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            size: 19,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.onInverseSurface,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          disabledForegroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(44, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: boxStrong,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(44, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: boxStrong,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(44, AppTokens.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: box,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(AppTokens.touchTarget, AppTokens.touchTarget),
          iconSize: 18,
          shape: box,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: box,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.onSurface,
        secondarySelectedColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: box,
        showCheckmark: false,
        labelStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.onSurface),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double?>(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: boxStrong,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyMedium,
        shape: boxStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        actionTextColor: scheme.onSurface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: boxStrong,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        // 行分隔改成**整行宽的底部发丝线**，而不是每行一个方框。
        // 原因：带副标题的行天然更高，方框的竖边就会长短不一
        // （用户反馈「描边有的长有的短」）。底边线宽度全部相同，观感一致。
        shape: const BottomHairlineBorder(),
        dense: true,
        minVerticalPadding: 4,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.onSurface,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.onSurface,
        overlayColor: Colors.white.withValues(alpha: 0.08),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onInverseSurface;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outlineVariant),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.onSurface;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onInverseSurface),
        side: BorderSide(color: scheme.outline),
        shape: const RoundedRectangleBorder(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurface,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: boxStrong,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.onSurface),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: Radius.zero,
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => scheme.onSurface.withValues(
            alpha: s.contains(WidgetState.hovered) ? 0.4 : 0.22,
          ),
        ),
      ),
    );
  }
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Convenience mapping onto [ColorScheme] so screens stay M3-only.
class AppColors {
  AppColors._(this.scheme);

  final ColorScheme scheme;

  Color get paper => scheme.surface;
  Color get ink => scheme.onSurface;
  Color get muted => scheme.onSurfaceVariant;
  Color get panel => scheme.surface;
  Color get panelMuted => scheme.surface;
  Color get line => scheme.outlineVariant;
  Color get lineStrong => scheme.outline;
  Color get accent => scheme.primary;
  Color get accentPale => scheme.primaryContainer;
  Color get danger => scheme.error;
  Color get warning => scheme.tertiary;
  Color get warningContainer => scheme.tertiaryContainer;
  Color get success => scheme.primary;
  Color get info => scheme.secondary;
  bool get isDark => scheme.brightness == Brightness.dark;

  /// Monochrome icon levels. Icons never take an accent hue: the primary
  /// level is ink (black on the light Absolutely paper, white on the dark
  /// terminal), the secondary level is the muted ink.
  Color get icon => scheme.onSurface;
  Color get iconMuted => scheme.onSurfaceVariant;
  Color get iconDisabled => scheme.onSurfaceVariant.withValues(alpha: 0.4);

  static AppColors of(BuildContext context) =>
      AppColors._(Theme.of(context).colorScheme);
}

/// 终端主题的行分隔：只画**整行宽**的底部发丝线，不画方框。
///
/// 为什么不是 `RoundedRectangleBorder(side: …)`：那个会画满四条边，于是每行
/// 变成一个盒子，而带副标题的行天然更高 —— 盒子的竖边就长短不一（这正是
/// 「描边有的长有的短」的来源）。底边线与行宽同宽、位置一致，所有行都一样。
class BottomHairlineBorder extends OutlinedBorder {
  const BottomHairlineBorder({super.side});

  @override
  BottomHairlineBorder copyWith({BorderSide? side}) =>
      BottomHairlineBorder(side: side ?? this.side);

  @override
  BottomHairlineBorder scale(double t) =>
      BottomHairlineBorder(side: side.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is BottomHairlineBorder ? this : null;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is BottomHairlineBorder ? this : null;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final y = rect.bottom - side.width / 2;
    canvas.drawLine(
      Offset(rect.left, y),
      Offset(rect.right, y),
      Paint()
        ..color = side.color
        ..strokeWidth = side.width,
    );
  }

  @override
  bool get preferPaintInterior => false;

  @override
  String toString() => 'BottomHairlineBorder';
}
