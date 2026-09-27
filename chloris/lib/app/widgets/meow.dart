import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_motion.dart';
export 'meow_cover.dart';

enum MeowPageVariant { largeTitle, compact }

/// M3 page chrome: large title + actions. Kept name to avoid churn.
///
/// In the Absolutely and terminal styles the page is laid out as a measured
/// editorial/console column and the title block is closed by a hairline rule
/// ([AppStyleExtension.headerRule]). The classic style keeps the previous
/// full-bleed layout.
class MeowPage extends StatelessWidget {
  const MeowPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.actions,
    this.subtitle,
    this.variant = MeowPageVariant.largeTitle,
    this.showBackButton,
    this.fullBleedBody = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  final MeowPageVariant variant;

  /// Set this for management pages that can also be opened as a shell branch.
  /// Such a branch may report `canPop == false` even though the page has a
  /// clear return path when opened from Settings.
  final bool? showBackButton;

  /// Lets list-heavy pages use the entire route width on desktop/tablet while
  /// keeping the editorial header column measured.  The default retains the
  /// existing style-specific reading measure.
  final bool fullBleedBody;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.extension<AppStyleExtension>();
    final pagePadding = style?.pagePadding ?? AppTokens.space16;
    final ui = style?.style ?? AppUiStyle.classic;
    final mono = style?.mono ?? false;
    final rule = style?.headerRule ?? false;
    final measured = ui != AppUiStyle.classic;
    final maxWidth = style?.contentMaxWidth ?? AppTokens.maxListWidth;
    final canPop = showBackButton ?? Navigator.of(context).canPop();

    // Header sits in a Column, so it has unbounded height: constrain the
    // width only and let it shrink-wrap vertically.
    //
    // Editorial pages keep their measured header. Full-bleed pages expand the
    // header too, so trailing actions stay at the far edge of the content area.
    Widget headerBox(Widget w) {
      if (!measured || fullBleedBody) return w;
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: w,
        ),
      );
    }

    // Body sits inside an Expanded, so height is bounded and can be passed
    // straight through to keep tight constraints for ListView/Column children.
    Widget bodyBox(Widget w) {
      if (!measured) return w;
      return LayoutBuilder(
        builder: (context, c) {
          if (fullBleedBody) {
            return SizedBox(width: c.maxWidth, height: c.maxHeight, child: w);
          }
          final width = c.maxWidth < maxWidth ? c.maxWidth : maxWidth;
          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: c.maxHeight, child: w),
          );
        },
      );
    }

    if (variant == MeowPageVariant.compact) {
      final compactHeader = AppEntrance(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            AppTokens.space8,
            pagePadding,
            AppTokens.space8,
          ),
          child: headerBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (canPop)
                      _BackButton(ui: ui, style: style)
                    else if (mono)
                      const _TerminalPrompt(),
                    Expanded(
                      child: Text(
                        mono ? '[ $title ]' : title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (actions != null && actions!.isNotEmpty)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          // Keep the compact masthead one row tall at
                          // narrow widths. Wrapping every toolbar button
                          // vertically can consume the whole viewport in
                          // a short window; horizontal scrolling preserves
                          // access to every action without flex overflow.
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < actions!.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: i == 0 ? 0 : AppTokens.space8,
                                    ),
                                    child: actions![i],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (rule) ...[
                  const SizedBox(height: AppTokens.space8),
                  const MeowRule(),
                ],
              ],
            ),
          ),
        ),
      );
      final compactBody = AppEntrance(
        delay: const Duration(milliseconds: 45),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pagePadding),
          child: bodyBox(child),
        ),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight && constraints.maxHeight < 120) {
            // Below the masthead's minimum useful height, make the whole page
            // scroll. A nested body viewport alone cannot bring its controls
            // into view when the page chrome already occupies the viewport.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    compactHeader,
                    SizedBox(height: 160, child: compactBody),
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              compactHeader,
              Expanded(child: compactBody),
            ],
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        AppTokens.space8,
        pagePadding,
        AppTokens.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppEntrance(
            child: headerBox(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canPop)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _BackButton(ui: ui, style: style),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            canPop ? AppTokens.space12 : 0,
                            AppTokens.space8,
                            8,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eyebrow.isNotEmpty)
                                Text(
                                  mono
                                      ? '> ${eyebrow.toLowerCase()}'
                                      // Absolutely keeps the eyebrow in natural
                                      // case — no wide-tracked uppercase.
                                      : ui == AppUiStyle.absolutely
                                      ? eyebrow
                                      : eyebrow.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: mono
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              if (eyebrow.isNotEmpty)
                                const SizedBox(height: AppTokens.space6),
                              Text(
                                mono ? '[ $title ]' : title,
                                style: theme.textTheme.headlineMedium,
                              ),
                              if (subtitle != null) ...[
                                SizedBox(
                                  height: ui == AppUiStyle.absolutely
                                      ? AppTokens.space8
                                      : AppTokens.space6,
                                ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: ui == AppUiStyle.absolutely
                                        ? 460
                                        : 560,
                                  ),
                                  child: Text(
                                    subtitle!,
                                    // Absolutely: editorial subtitles are serif.
                                    style: ui == AppUiStyle.absolutely
                                        ? AppTheme.absolutelySubtitle(theme)
                                        : theme.textTheme.bodyMedium?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (actions != null && actions!.isNotEmpty)
                        Flexible(
                          fit: FlexFit.loose,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: actions!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: rule ? AppTokens.space20 : AppTokens.space16,
                  ),
                  if (rule) ...[
                    const MeowRule(),
                    const SizedBox(height: AppTokens.space20),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: AppEntrance(
              delay: const Duration(milliseconds: 55),
              child: bodyBox(child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back affordance. Absolutely gets a bordered square, terminal a bracketed
/// chevron, classic the plain filled icon button.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.ui, this.style});

  final AppUiStyle ui;
  final AppStyleExtension? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    void pop() => Navigator.of(context).maybePop();
    if (ui == AppUiStyle.terminal) {
      return TextButton(
        onPressed: pop,
        child: Text('<', style: Theme.of(context).textTheme.titleMedium),
      );
    }
    if (ui == AppUiStyle.absolutely) {
      return IconButton.outlined(
        tooltip: '返回',
        onPressed: pop,
        icon: const AppIcon(AppIcons.back, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style?.controlRadius ?? 8),
          ),
          minimumSize: const Size(AppTokens.touchTarget, AppTokens.touchTarget),
        ),
      );
    }
    return IconButton(
      tooltip: '返回',
      onPressed: pop,
      icon: const AppIcon(AppIcons.back),
    );
  }
}

class _TerminalPrompt extends StatelessWidget {
  const _TerminalPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTokens.space8),
      child: Text('>', style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 1px hairline rule in the active style. Absolutely uses a warm hairline,
/// terminal a grey line — both are the same widget.
class MeowRule extends StatelessWidget {
  const MeowRule({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final absolutely =
        theme.extension<AppStyleExtension>()?.style == AppUiStyle.absolutely;
    // Absolutely: the masthead rule — a short ink dash closing the title,
    // the rest continuing as hairline. Print-column grammar.
    if (!absolutely) {
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: Container(height: AppTokens.hairline, color: cs.outlineVariant),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        children: [
          Container(width: 64, height: 2, color: cs.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: AppTokens.hairline,
              color: cs.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small all-caps group label used above sections of controls.
class MeowLabel extends StatelessWidget {
  const MeowLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<AppStyleExtension>();
    final mono = style?.mono ?? false;
    final absolutely = style?.style == AppUiStyle.absolutely;
    final cs = Theme.of(context).colorScheme;
    final label = Text(
      mono
          ? '# ${text.toLowerCase()}'
          // Absolutely keeps group labels in natural case — quiet, editorial.
          : absolutely
          ? text
          : text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: absolutely
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : mono
            ? cs.onSurface
            : cs.onSurfaceVariant,
      ),
    );
    if (trailing == null) return label;
    return Row(children: [label, const Spacer(), trailing!]);
  }
}

class MeowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MeowAppBar({super.key, required this.title, this.actions, this.bottom});

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), actions: actions, bottom: bottom);
  }
}

class MeowSearchBar extends StatelessWidget {
  const MeowSearchBar({
    super.key,
    this.hint = '搜索',
    this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return MeowQueryField(
      controller: controller,
      onChanged: onChanged,
      hint: hint,
    );
  }
}

/// True while a CJK / IME composition session is open.
bool imeComposing(TextEditingValue value) =>
    value.composing.isValid && !value.composing.isCollapsed;

/// Search/filter input with the same flat treatment as the app search bar.
///
/// Selection stays on so Safari / iPad can place the caret and finish pinyin.
/// Parent [onChanged] is deferred until composition commits, otherwise each
/// Latin keystroke leaks into the field as `wwo我dd'ee的`.
class MeowQueryField extends StatefulWidget {
  const MeowQueryField({
    super.key,
    this.hint = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.leading = AppIcons.search,
    this.trailing,
    this.textInputAction = TextInputAction.search,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final IconData? leading;
  final List<Widget>? trailing;
  final TextInputAction textInputAction;

  @override
  State<MeowQueryField> createState() => _MeowQueryFieldState();
}

class _MeowQueryFieldState extends State<MeowQueryField> {
  TextEditingController? _owned;

  TextEditingController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = TextEditingController();
    }
  }

  @override
  void didUpdateWidget(MeowQueryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null && widget.controller != null) {
      _owned?.dispose();
      _owned = null;
    } else if (oldWidget.controller != null && widget.controller == null) {
      _owned = TextEditingController(text: oldWidget.controller?.text);
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (imeComposing(_controller.value)) return;
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<AppStyleExtension>();
    final ui = ext?.style ?? AppUiStyle.classic;
    // Absolutely's search fields are full pills — the official query grammar.
    final radius = ui == AppUiStyle.absolutely
        ? 999.0
        : (ext?.controlRadius ?? 28);
    final classic = ui == AppUiStyle.classic;
    final focusColor = ui == AppUiStyle.absolutely ? cs.onSurface : cs.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(
        color: classic ? cs.outlineVariant.withValues(alpha: 0.72) : cs.outline,
      ),
    );
    return ScrollConfiguration(
      behavior: const _FieldNoDragScroll(),
      child: TextField(
        controller: _controller,
        enableInteractiveSelection: true,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: widget.textInputAction,
        keyboardType: TextInputType.text,
        // Single-line fields otherwise pan their own text on Web/Safari.
        scrollPhysics: const NeverScrollableScrollPhysics(),
        onChanged: _onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: widget.leading == null
              ? null
              : AppIcon(
                  widget.leading,
                  color: classic ? null : cs.onSurfaceVariant,
                  size: classic ? null : 18,
                ),
          suffixIcon: widget.trailing == null || widget.trailing!.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: widget.trailing!),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerLowest,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: focusColor, width: classic ? 2 : 1.2),
          ),
        ),
      ),
    );
  }
}

class _FieldNoDragScroll extends ScrollBehavior {
  const _FieldNoDragScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{};

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const NeverScrollableScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class MeowPrimaryButton extends StatelessWidget {
  const MeowPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
    }
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class MeowGhostButton extends StatelessWidget {
  const MeowGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
    }
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

/// Square icon control. [active] never introduces a hue: Absolutely fills with
/// the raised warm surface, terminal inverts to a solid white cell, classic
/// keeps the tonal container.
class MeowIconButton extends StatelessWidget {
  const MeowIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<AppStyleExtension>();
    final ui = ext?.style ?? AppUiStyle.classic;
    final Widget btn;
    if (ui == AppUiStyle.classic) {
      btn = active
          ? IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon))
          : IconButton.outlined(onPressed: onPressed, icon: Icon(icon));
    } else if (ui == AppUiStyle.terminal) {
      btn = IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: ext?.iconSize),
        style: IconButton.styleFrom(
          backgroundColor: active ? cs.onSurface : Colors.transparent,
          foregroundColor: active ? cs.onInverseSurface : cs.onSurface,
          side: BorderSide(color: active ? cs.onSurface : cs.outlineVariant),
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(AppTokens.touchTarget, AppTokens.touchTarget),
          padding: EdgeInsets.zero,
        ),
      );
    } else {
      // Absolutely: toggle buttons are ink pills when active — the same
      // "ink takes the selected state" grammar as switches and checkboxes.
      btn = IconButton(
        onPressed: onPressed,
        icon: AppIcon(
          icon,
          size: ext?.iconSize,
          color: active ? cs.surface : cs.onSurfaceVariant,
        ),
        style: IconButton.styleFrom(
          backgroundColor: active ? cs.onSurface : Colors.transparent,
          shape: active
              ? const StadiumBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ext?.controlRadius ?? 8),
                  side: BorderSide(color: cs.outlineVariant),
                ),
          minimumSize: const Size(AppTokens.touchTarget, AppTokens.touchTarget),
          padding: EdgeInsets.zero,
        ),
      );
    }
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class MeowChip extends StatelessWidget {
  const MeowChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// 左侧小图标：用于区分形近的筛选标签（如「在读」/「在线」）。
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      // FilterChip's default label color can fall back to the platform theme
      // when a custom ChipThemeData is active. Keep the text tied to the same
      // contrast pair as the chip surface so dark themes never render labels
      // as near-black text on a dark pill.
      label: Text(
        label,
        style: TextStyle(
          color: active ? colors.onSurface : colors.onSurfaceVariant,
        ),
      ),
      avatar: icon,
      selected: active,
      onSelected: onTap == null ? null : (_) => onTap!(),
    );
  }
}

class MeowEmpty extends StatelessWidget {
  const MeowEmpty({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.mark = '◌',
    this.compact = false,
  });

  final String title;
  final String body;
  final Widget? action;
  final String mark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final styleExt = theme.extension<AppStyleExtension>();
    final ui = styleExt?.style ?? AppUiStyle.classic;
    final mono = ui == AppUiStyle.terminal;
    final absolutely = ui == AppUiStyle.absolutely;
    // Monochrome: the empty state is the secondary ink level, never an accent.
    // Absolutely's hero grammar inverts that: the thin-line icon sits at full ink.
    final tone = absolutely
        ? cs.onSurface
        : ui == AppUiStyle.classic
        ? cs.primary
        : cs.onSurfaceVariant;
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 680 : 460),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mono)
            Text(
              mark,
              style: theme.textTheme.displaySmall?.copyWith(color: tone),
            )
          else
            AppIcon(
              AppIcons.library,
              size: compact
                  ? (absolutely ? 36 : 48)
                  : (absolutely ? 44 : (ui == AppUiStyle.classic ? 64 : 56)),
              color: tone,
            ),
          SizedBox(
            height: compact
                ? AppTokens.space12
                : absolutely
                ? AppTokens.space20
                : AppTokens.space16,
          ),
          Text(
            mono ? '[ $title ]' : title,
            // Absolutely: display serif, never bold — the official error /
            // capabilities page hero.
            style: compact
                ? theme.textTheme.titleLarge
                : absolutely
                ? theme.textTheme.displaySmall
                : theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: compact
                ? AppTokens.space6
                : absolutely
                ? AppTokens.space12
                : AppTokens.space8,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 560 : 420),
            child: Text(
              body,
              textAlign: TextAlign.center,
              // Absolutely: the subtitle is serif too — muted and airy.
              style: absolutely
                  ? AppTheme.absolutelySubtitle(theme)
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
            ),
          ),
          if (action != null) ...[
            SizedBox(
              height: compact
                  ? AppTokens.space12
                  : absolutely
                  ? AppTokens.space24
                  : AppTokens.space20,
            ),
            action!,
          ],
        ],
      ),
    );
    final positioned = compact
        ? Align(
            alignment: const Alignment(0, -0.16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space20,
              ),
              child: content,
            ),
          )
        : Center(child: content);
    if (!compact) return AppEntrance(child: positioned);

    return AppEntrance(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A compact page can be resized to any height. Keep the regular hero
          // while it fits comfortably; switch to a denser summary on short
          // windows, and always put the result in a viewport so even a window
          // shorter than the controls can scroll instead of overflowing.
          final hasRoomForHero =
              constraints.hasBoundedHeight && constraints.maxHeight >= 320;
          final viewportHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : 0.0;
          final child = hasRoomForHero
              ? positioned
              : _compactSummary(
                  context,
                  theme: theme,
                  mono: mono,
                  tone: tone,
                  absolutely: absolutely,
                  colorScheme: cs,
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (viewportHeight - AppTokens.space16).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }

  Widget _compactSummary(
    BuildContext context, {
    required ThemeData theme,
    required bool mono,
    required Color tone,
    required bool absolutely,
    required ColorScheme colorScheme,
  }) {
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (mono)
              Text(
                mark,
                style: theme.textTheme.titleLarge?.copyWith(color: tone),
              )
            else
              AppIcon(AppIcons.library, size: 26, color: tone),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mono ? '[ $title ]' : title,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: absolutely
                        ? AppTheme.absolutelySubtitle(
                            theme,
                          ).copyWith(fontSize: 12)
                        : theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[
          const SizedBox(height: AppTokens.space8),
          action!,
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: summary,
        ),
      ),
    );
  }
}

class MeowLoading extends StatelessWidget {
  const MeowLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final mono =
        Theme.of(context).extension<AppStyleExtension>()?.mono ?? false;
    return AppEntrance(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mono)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: AppTokens.space12),
              Text(
                mono ? '> ${label!}' : label!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MeowError extends StatelessWidget {
  const MeowError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mono = theme.extension<AppStyleExtension>()?.mono ?? false;
    return AppEntrance(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mono)
                Text(
                  '!',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: cs.onSurface,
                  ),
                )
              else
                AppIcon(AppIcons.error, size: mono ? 44 : 48, color: cs.error),
              const SizedBox(height: AppTokens.space12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: AppTokens.space16),
                FilledButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MeowToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
