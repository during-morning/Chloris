import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persist/kv_settings.dart';
import '../core/persist/settings_migrations.dart';

import '../features/book_detail/download_auto_resume.dart';
import '../features/settings/welcome_screen.dart';
import '../services/deeplink/deep_link_listener.dart';
import 'router.dart';
import 'theme/app_style_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'theme/style_host_stub.dart' if (dart.library.html) 'theme/style_host_web.dart';

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

  @override
  void initState() {
    super.initState();
    KvSettings.ready().then((p) {
      if (!mounted) return;
      setState(() => _accepted = p.getBool('welcomeAccepted') ?? false);
    });
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
    applyHostUiStyle(style.id);
    if (_accepted == true) {
      ref.watch(downloadAutoResumeProvider);
    }
    if (_accepted != true) {
      return MaterialApp(
        title: 'Chloris',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: effectiveMode,
        home: _accepted == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : WelcomeScreen(onAccepted: () => setState(() => _accepted = true)),
      );
    }
    return DeepLinkListener(
      child: MaterialApp.router(
        title: 'Chloris',
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
          final bold = ref.watch(boldTextProvider);
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduce || mq.disableAnimations,
              highContrast: hc || mq.highContrast,
              boldText: bold || mq.boldText,
            ),
            child: AppStyleShell(child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
