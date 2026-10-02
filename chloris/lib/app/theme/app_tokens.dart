import 'package:flutter/animation.dart';

/// Layout / motion tokens. Screens must not invent ad-hoc spacing or radii.
///
/// Every value here is shared by all UI styles. Where a style needs a
/// different value (radius, column width, rail width) the screen reads it
/// from `AppStyleExtension` instead of branching on `AppUiStyle`.
abstract final class AppTokens {
  // ---- Spacing (4pt scale) ----------------------------------------------
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;

  // ---- Shape ------------------------------------------------------------
  /// Terminal style is fully square; Absolutely keeps a soft 8pt family.
  static const radius0 = 0.0;
  static const radius4 = 4.0;
  static const radius6 = 6.0;
  static const radius8 = 8.0;
  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radius28 = 28.0;

  // ---- Stroke -----------------------------------------------------------
  /// The single hairline width used for every divider, card and control
  /// outline in the Absolutely and terminal styles.
  static const hairline = 1.0;

  // ---- Motion -----------------------------------------------------------
  static const durationFast = Duration(milliseconds: 120);
  static const durationMed = Duration(milliseconds: 220);
  static const durationSlow = Duration(milliseconds: 340);

  /// Hand-drawn strokes are written at pen speed — slower than chrome motion.
  static const durationDraw = Duration(milliseconds: 720);

  /// Gap between consecutive items of a staggered list entrance.
  static const durationStagger = Duration(milliseconds: 40);

  /// Items beyond this index enter together, so long lists never queue up.
  static const staggerMaxItems = 8;

  /// "Motion is a page-turn, not a performance": decelerate in, accelerate
  /// out, and never overshoot.
  static const curveIn = Curves.easeOutCubic;
  static const curveOut = Curves.easeInCubic;
  static const curveEmphasis = Curves.easeInOutCubicEmphasized;

  // ---- Breakpoints ------------------------------------------------------
  static const bpRail = 720.0;
  static const bpExtended = 1100.0;
  static const maxReadWidth = 760.0;
  static const maxListWidth = 960.0;

  // Per-style measure. Absolutely is an editorial column; terminal uses the
  // full pane because monospace text is already narrow.
  static const absolutelyColumn = 720.0;
  static const absolutelyRail = 248.0;
  static const terminalColumn = 1180.0;
  static const terminalRail = 212.0;

  // ---- Component metrics ------------------------------------------------
  static const controlHeight = 40.0;
  static const controlHeightCompact = 34.0;
  static const iconButtonSize = 36.0;

  /// Minimum interactive hit target.  Visual icons may remain 36pt while the
  /// surrounding control stays large enough for touch and switch access.
  static const touchTarget = 48.0;
  static const topBarHeight = 26.0;

  static const tocItemExtent = 56.0;
  static const coverRatio = 2 / 3;
  static const listTileCompact = 56.0;
  static const listTileComfort = 72.0;
}
