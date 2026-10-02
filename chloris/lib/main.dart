import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/persist/kv_settings.dart';
import 'core/persist/app_db.dart';
import 'core/startup_metrics.dart';
import 'core/persist/settings_migrations.dart';
import 'engine/prefs_kv_port.dart';

import 'dart:async';
import 'dart:convert';

import 'app/app.dart';
import 'app/illustration/sketch.dart';
import 'app/widgets/startup_shell.dart';
import 'app/l10n/locale_provider.dart';
import 'app/theme/theme_provider.dart';
import 'app/theme/app_theme.dart';
import 'services/persist/credentials.dart';
import 'services/persist/vault_sync.dart';
import 'features/sources/source_library_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Render an explicit bootstrap state while storage and platform adapters
  // initialise. Without this first frame Safari shows a blank document until
  // every startup future completes (or hangs on an unavailable capability).
  runApp(const StartupShell());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupMetrics.mark('first_frame');
  });
  // Open SQLite after the first frame so it is ready by the time shelf/cache
  // providers need it, without delaying the bootstrap UI.
  unawaited(AppDb.open());
  // Parse the hand-drawn illustration set off the critical path so empty
  // states and navigation glyphs paint on their first frame.
  unawaited(SketchArt.preloadAll().catchError((_) {}));
  FlutterError.onError = (details) {
    DebugLog.error('flutter', details.exceptionAsString());
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DebugLog.error('zone', error.toString());
    return true;
  };
  var lastJank = DateTime.fromMillisecondsSinceEpoch(0);
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final ms = t.totalSpan.inMilliseconds;
      if (ms < 250) continue;
      final now = DateTime.now();
      if (now.difference(lastJank).inSeconds < 8) continue;
      lastJank = now;
      DebugLog.error('jank', 'frame ' + ms.toString() + 'ms');
    }
  });
  Timer? debugFlush;
  DebugLog.sink = (tag, message, {int state = 0}) {
    debugFlush?.cancel();
    debugFlush = Timer(const Duration(seconds: 2), () {
      KvSettings.ready().then((p) {
        final slice = DebugLog.buffer.length > 80
            ? DebugLog.buffer.sublist(DebugLog.buffer.length - 80)
            : DebugLog.buffer;
        p.setString(
          'debugLog',
          jsonEncode(
            slice
                .map(
                  (e) => {
                    'time': e.time.toIso8601String(),
                    'tag': e.tag,
                    'message': e.message,
                    'state': e.state,
                  },
                )
                .toList(),
          ),
        );
      });
    });
  };
  // The vault hydration and the legacy credential migration are independent:
  // hydrate mirrors the encrypted vault into KvSettings, while migrateFromPrefs
  // reads plaintext SharedPreferences and writes them into the vault. Neither
  // reads from the other, so run them together.
  // Start the settings handle at the same time.  `KvSettings.ready()` owns
  // the idempotent schema gate, so this removes one full SharedPreferences /
  // migration round trip from cold start while preserving the ordering below
  // (all reads still happen after both vault jobs have completed).
  final prefsFuture = KvSettings.ready();
  await Future.wait([
    hydratePrefsFromVault(),
    CredentialStore.migrateFromPrefs(),
  ]);
  // Run the schema boundary before any provider or feature reads settings.
  // This keeps startup and feature writes on the same migration path.
  final prefs = await prefsFuture;
  // 书源级 java.put/java.get 变量的持久层：此后所有 BookSource 实例
  // （fromJson 或手动构造）自动带持久存储，重启后变量仍在。
  BookSource.defaultVarStore = PrefsKvPort(prefs);
  final rawLog = prefs.getString('debugLog');
  if (rawLog != null && rawLog.isNotEmpty) {
    try {
      final list = jsonDecode(rawLog);
      if (list is List) {
        DebugLog.restore([
          for (final e in list)
            if (e is Map)
              DebugEvent(
                time:
                    DateTime.tryParse(e['time']?.toString() ?? '') ??
                    DateTime.now(),
                tag: e['tag']?.toString() ?? '',
                message: e['message']?.toString() ?? '',
                state: e['state'] is int ? e['state'] as int : -1,
              ),
        ]);
      }
    } catch (_) {}
  }
  final rawTheme = prefs.getString('themeMode');
  final mode = switch (rawTheme) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.system,
  };
  final rawUiStyle = prefs.getString('uiStyle');
  final uiStyle = rawUiStyle == null || rawUiStyle.isEmpty
      ? AppUiStyle.absolutely
      : AppUiStyle.byId(rawUiStyle);
  // One-shot migration: the Absolutely theme used to be persisted under the
  // id 'claude'. byId still accepts it; write the new id back so the legacy
  // value disappears from storage after the first launch.
  if (rawUiStyle == 'claude') {
    unawaited(
      prefs
          .setString('uiStyle', 'absolutely')
          .then((_) => syncVaultFromPrefs()),
    );
  }
  final lang = prefs.getString('locale') ?? 'zh';
  final textScale = prefs.getDouble('uiTextScale') ?? 1.0;
  final reduceMotion = prefs.getBool('reduceMotion') ?? false;
  final forceMotion = prefs.getBool('forceMotion') ?? false;
  final highContrast = prefs.getBool('highContrast') ?? false;
  final boldText = prefs.getBool('boldText') ?? false;
  final debugVerbose = prefs.getBool('debugVerbose') ?? false;
  final httpTimeoutSec = prefs.getInt('httpTimeoutSec') ?? 15;
  final searchTimeoutSec = prefs.getInt('searchTimeoutSec') ?? 12;
  final tocTimeoutSec = prefs.getInt('tocTimeoutSec') ?? 18;
  var contentTimeoutSec = prefs.getInt('contentTimeoutSec') ?? 30;
  if (contentTimeoutSec == 10) {
    contentTimeoutSec = 30;
    await prefs.setInt('contentTimeoutSec', 30);
  }
  var searchPool = prefs.getInt('searchPool') ?? 32;
  if (searchPool == 12) {
    searchPool = 32;
    await prefs.setInt('searchPool', 32);
  }
  searchPool = searchPool.clamp(4, kIsWeb ? 64 : 128).toInt();
  var downloadPool = prefs.getInt('downloadPool') ?? 8;
  if (downloadPool == 3) {
    downloadPool = 8;
    await prefs.setInt('downloadPool', 8);
  }
  downloadPool = downloadPool.clamp(2, kIsWeb ? 16 : 128).toInt();
  final searchHostCap = (prefs.getInt('searchHostCap') ?? 2)
      .clamp(0, kIsWeb ? 64 : 128)
      .toInt();
  final downloadHostCap = (prefs.getInt('downloadHostCap') ?? 3)
      .clamp(1, kIsWeb ? 16 : 128)
      .toInt();
  final userAgent = prefs.getString('userAgent') ?? '';
  EngineLimits.apply(
    debugVerbose: debugVerbose,
    httpTimeoutSec: httpTimeoutSec,
    searchTimeoutSec: searchTimeoutSec,
    tocTimeoutSec: tocTimeoutSec,
    contentTimeoutSec: contentTimeoutSec,
    searchPool: searchPool,
    searchHostCap: searchHostCap,
    searchEarlyStopHits: prefs.getInt('searchEarlyStopHits') ?? 8,
    searchEarlyStopScore: 650,
    downloadPool: downloadPool,
    downloadHostCap: downloadHostCap,
    userAgent: userAgent,
  );
  final overlay = <String, bool>{};
  final rawEnabled = prefs.getString('sourceEnabled');
  if (rawEnabled != null && rawEnabled.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawEnabled);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (v is bool) overlay[k.toString()] = v;
        });
      }
    } catch (_) {}
  }
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => mode),
        themeFamilyIdProvider.overrideWith(
          (ref) => prefs.getString('themeFamily') ?? 'green',
        ),
        einkThemeProvider.overrideWith(
          (ref) => prefs.getBool('einkTheme') ?? false,
        ),
        localeProvider.overrideWith((ref) => lang),
        uiTextScaleProvider.overrideWith((ref) => textScale),
        reduceMotionProvider.overrideWith((ref) => reduceMotion),
        forceMotionProvider.overrideWith((ref) => forceMotion),
        highContrastProvider.overrideWith((ref) => highContrast),
        boldTextProvider.overrideWith((ref) => boldText),
        debugVerboseProvider.overrideWith((ref) => debugVerbose),
        httpTimeoutSecProvider.overrideWith((ref) => httpTimeoutSec),
        searchTimeoutSecProvider.overrideWith((ref) => searchTimeoutSec),
        searchPoolProvider.overrideWith((ref) => searchPool),
        downloadPoolProvider.overrideWith((ref) => downloadPool),
        searchHostCapProvider.overrideWith((ref) => searchHostCap),
        downloadHostCapProvider.overrideWith((ref) => downloadHostCap),
        userAgentProvider.overrideWith((ref) => userAgent),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        sourceEnabledOverrideProvider.overrideWith(
          () => SourceEnabledOverrideNotifier(seed: overlay),
        ),
      ],
      child: const ChlorisApp(),
    ),
  );
}
