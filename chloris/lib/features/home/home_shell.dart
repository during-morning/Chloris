import '../media/music_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/persist/kv_settings.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/l10n/locale_provider.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 书库 / 寻找 / 探索 / 音乐 / 我的。
  ///
  /// 书源与 RSS 仍保留独立路由和页面状态，但从「我的」进入，避免
  /// 主导航被管理型页面占满。
  static const _branch = <int>[0, 1, 2, 6, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(ref.watch(localeProvider));
    final labels = [s.library, s.search, s.explore, '音乐', s.settings];
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
        final body = TweenAnimationBuilder<double>(
          key: ValueKey('transition-${navigationShell.currentIndex}'),
          tween: Tween(begin: reduce ? 1 : .75, end: 1),
          duration: reduce ? Duration.zero : AppTokens.durationMed,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
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
              const [
                '/library',
                '/search',
                '/explore',
                '/music',
                '/settings',
              ][tabIndex],
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
                        icon: AppIcons.navPairs[i].styledAt(
                          ext,
                          active: false,
                          color: cs.onSurfaceVariant,
                        ),
                        selectedIcon: AppIcons.navPairs[i].styledAt(
                          ext,
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
                      icon: AppIcons.navPairs[i].styledAt(ext, active: false),
                      selectedIcon: AppIcons.navPairs[i].styledAt(
                        ext,
                        active: true,
                      ),
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

  int _tabIndex(int branch) {
    final i = _branch.indexOf(branch);
    return i < 0 ? 4 : i;
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
