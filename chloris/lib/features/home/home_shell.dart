import '../media/music_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/persist/kv_settings.dart';

import '../../app/illustration/sketch.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/l10n/locale_provider.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 书库 / 寻找 / 探索 / 我的。
  ///
  /// 书源、RSS 与音频播放器仍保留独立路由和页面状态，但从「我的」进入，
  /// 避免主导航被管理型页面占满。
  static const _branch = <int>[0, 1, 2, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(ref.watch(localeProvider));
    final labels = [s.library, s.search, s.explore, s.settings];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<AppStyleExtension>();
    final ui = ext?.style ?? AppUiStyle.classic;
    final tab = _tabIndex(navigationShell.currentIndex);
    final showMiniPlayer = navigationShell.currentIndex != 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppTokens.bpRail;
        final extended = constraints.maxWidth >= AppTokens.bpExtended;
        final reduce = MediaQuery.disableAnimationsOf(context);
        // Keep a single shell mounted: AnimatedSwitcher would duplicate the
        // branch Navigator global keys while outgoing and incoming shells overlap.
        // Absolutely turns the tab like a page: a deeper fade plus a short
        // rise. Other styles keep the light cross-fade.
        final absolutely = ui == AppUiStyle.absolutely;
        final body = TweenAnimationBuilder<double>(
          key: ValueKey('transition-${navigationShell.currentIndex}'),
          tween: Tween(begin: reduce ? 1 : (absolutely ? 0 : .75), end: 1),
          duration: reduce
              ? Duration.zero
              : absolutely
              ? AppTokens.durationSlow
              : AppTokens.durationMed,
          curve: AppTokens.curveIn,
          builder: (context, value, child) {
            final faded = Opacity(
              opacity: absolutely ? .55 + .45 * value : value,
              child: child,
            );
            // Always keep the Transform in the tree so the shell subtree is
            // never reparented mid-animation.
            return Transform.translate(
              offset: Offset(0, absolutely ? 10 * (1 - value) : 0),
              child: faded,
            );
          },
          child: navigationShell,
        );
        void go(int tabIndex) {
          final branch = _branch[tabIndex.clamp(0, _branch.length - 1)];
          navigationShell.goBranch(branch);
          // Persist the visible tab index. Older builds stored the internal
          // branch index; redirect clamps those values to「我的」safely.
          KvSettings.ready().then(
            (p) => p.setString(
              'homeDestination',
              const ['/library', '/search', '/explore', '/settings'][tabIndex],
            ),
          );
        }

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  minWidth: 76,
                  minExtendedWidth: ext?.railWidth ?? AppTokens.absolutelyRail,
                  selectedIndex: tab,
                  onDestinationSelected: go,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                    child: extended
                        ? Row(
                            children: [
                              _BrandMark(ui: ui),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Chloris',
                                  overflow: TextOverflow.ellipsis,
                                  style: ui == AppUiStyle.absolutely
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          )
                        : _BrandMark(ui: ui),
                  ),
                  trailing: extended
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppTokens.space8),
                          child: _RailFooter(ui: ui),
                        )
                      : null,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationRailDestination(
                        icon: _navIcon(
                          ext,
                          i,
                          active: false,
                          color: cs.onSurfaceVariant,
                        ),
                        selectedIcon: _navIcon(
                          ext,
                          i,
                          active: true,
                          color: cs.onSurface,
                        ),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: cs.outlineVariant),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: body),
                      if (showMiniPlayer) const MusicMiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMiniPlayer) const MusicMiniPlayer(),
              NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: go,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: _navIcon(ext, i, active: false),
                      selectedIcon: _navIcon(ext, i, active: true),
                      label: labels[i],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Absolutely inks its navigation by hand: the selected glyph is written
  /// in when its tab is chosen. Other styles keep the icon-font pairs.
  static Widget _navIcon(
    AppStyleExtension? ext,
    int i, {
    required bool active,
    Color? color,
  }) {
    if (ext?.style == AppUiStyle.absolutely) {
      return SketchIcon(
        SketchArt.nav[i],
        size: ext!.iconSize,
        color: color,
        animate: active,
      );
    }
    return AppIcons.navPairs[i].styledAt(ext, active: active, color: color);
  }

  int _tabIndex(int branch) {
    final i = _branch.indexOf(branch);
    // Branches without a tab (sources, RSS, audio) are reached from「我的」.
    return i < 0 ? _branch.length - 1 : i;
  }
}

/// Wordmark tile. Absolutely shows the app icon inside a hairline square,
/// terminal shows a console prompt, classic keeps the round avatar.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.ui});

  final AppUiStyle ui;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (ui == AppUiStyle.terminal) {
      return Text(
        '>',
        style: theme.textTheme.titleLarge?.copyWith(color: cs.onSurface),
      );
    }
    if (ui == AppUiStyle.absolutely) {
      // Official sidebar: the mark sits bare on the paper — no frame, no box.
      return Image.asset(
        'assets/brand/icon.png',
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      );
    }
    return const CircleAvatar(
      backgroundImage: AssetImage('assets/brand/icon.png'),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.ui});

  final AppUiStyle ui;

  @override
  Widget build(BuildContext context) {
    if (ui == AppUiStyle.classic) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: cs.outlineVariant),
          const SizedBox(height: AppTokens.space8),
          Text(
            ui == AppUiStyle.terminal ? 'v0.1.0' : '本地优先的阅读器',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
