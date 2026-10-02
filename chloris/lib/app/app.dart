import '../features/media/music_workspace.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persist/kv_settings.dart';
import '../core/persist/settings_migrations.dart';

import '../features/book_detail/download_auto_resume.dart';
import '../features/settings/welcome_screen.dart';
import '../services/deeplink/deep_link_listener.dart';
import 'router.dart';
import 'widgets/startup_shell.dart';
import 'theme/app_style_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'theme/style_host_stub.dart'
    if (dart.library.html) 'theme/style_host_web.dart';

class _ChlorisScrollBehavior extends MaterialScrollBehavior {
  const _ChlorisScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class _FollowScrollBehavior extends MaterialScrollBehavior {
  const _FollowScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class ChlorisApp extends ConsumerStatefulWidget {
  const ChlorisApp({super.key});

  @override
  ConsumerState<ChlorisApp> createState() => _ChlorisAppState();
}

class _ChlorisAppState extends ConsumerState<ChlorisApp> {
  bool? _accepted;
  ProviderSubscription<AppUiStyle>? _styleSub;

  @override
  void initState() {
    super.initState();
    // The DOM data-ui-style attribute is a host-side mirror of the provider:
    // apply it once for the restored value, then on every change — never from
    // inside build(), which would re-run the JS interop on each rebuild.
    applyHostUiStyle(ref.read(uiStyleProvider).id);
    _styleSub = ref.listenManual(uiStyleProvider, (_, next) {
      applyHostUiStyle(next.id);
    });
    KvSettings.ready().then((p) {
      if (!mounted) return;
      // Keep the guide available from Settings, but do not interrupt a fresh
      // install with a required onboarding screen on first launch.
      setState(() => _accepted = p.getBool('welcomeAccepted') ?? true);
    });
  }

  @override
  void dispose() {
    _styleSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final family = AppThemeFamily.byId(ref.watch(themeFamilyIdProvider));
    final style = ref.watch(uiStyleProvider);
    final eink = style == AppUiStyle.classic && ref.watch(einkThemeProvider);
    final hc = ref.watch(highContrastProvider);
    final light = AppTheme.light(
      family,
      eink: eink,
      style: style,
      highContrast: hc,
    );
    final dark = AppTheme.dark(
      family,
      eink: eink,
      style: style,
      highContrast: hc,
    );
    final effectiveMode = style.fixedThemeMode ?? mode;
    if (_accepted == true) {
      ref.watch(downloadAutoResumeProvider);
    }
    if (_accepted == null) return const StartupShell();
    if (_accepted != true) {
      return MaterialApp(
        title: 'Cholris',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: effectiveMode,
        home: WelcomeScreen(onAccepted: () => setState(() => _accepted = true)),
      );
    }
    return DeepLinkListener(
      child: MaterialApp.router(
        title: 'Cholris',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: effectiveMode,
        themeAnimationDuration: eink || ref.watch(reduceMotionProvider)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        scrollBehavior: eink || style == AppUiStyle.terminal
            ? const _ChlorisScrollBehavior()
            : const _FollowScrollBehavior(),
        routerConfig: appRouter,
        builder: (context, child) {
          final scale = ref.watch(uiTextScaleProvider).clamp(0.85, 1.4);
          final reduce = ref.watch(reduceMotionProvider);
          final force = ref.watch(forceMotionProvider);
          final bold = ref.watch(boldTextProvider);
          final mq = MediaQuery.of(context);
          // Preserve the operating-system scale and multiply the app's
          // accessibility setting on top.  Replacing the inherited scaler
          // outright used to silently discard iOS/Android large-text mode.
          final systemScale = mq.textScaler.scale(1.0);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(systemScale * scale),
              disableAnimations: reduce || (!force && mq.disableAnimations),
              highContrast: hc || mq.highContrast,
              boldText: bold || mq.boldText,
            ),
            child: AppStyleShell(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  appRouter.routeInformationProvider,
                  readerMusicControlsVisible,
                ]),
                builder: (context, _) {
                  final path =
                      appRouter.routeInformationProvider.value.uri.path;
                  final home = const [
                    '/library',
                    '/search',
                    '/explore',
                    '/music',
                    '/settings',
                    '/sources',
                    '/rss',
                  ].contains(path);
                  final show =
                      !home &&
                      (path != '/reader' || readerMusicControlsVisible.value);
                  return Column(
                    children: [
                      Expanded(child: child ?? const SizedBox.shrink()),
                      if (show) const MusicMiniPlayer(),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
