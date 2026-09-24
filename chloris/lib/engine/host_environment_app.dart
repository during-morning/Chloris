import 'dart:async';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/persist/kv_settings.dart';

/// Host environment backed by the app's own settings.
///
/// [HostEnvironment] is synchronous because a rule script reads these values
/// inline, while `KvSettings` is asynchronous. The settings are therefore
/// snapshotted at construction and refreshed on demand — call [refresh] after a
/// settings screen writes, or the rule surface keeps serving stale values.
class AppHostEnvironment implements HostEnvironment {
  AppHostEnvironment() {
    unawaited(refresh());
  }

  final HostEnvironment _fallback = const DefaultHostEnvironment();

  String _userAgent = DefaultHostEnvironment.defaultUserAgent;
  Map<String, Object?> _bookConfig = const {};
  Map<String, Object?> _themeConfig = const {};
  int _themeMode = 0;

  /// Re-reads the settings snapshot.
  Future<void> refresh() async {
    try {
      final s = await KvSettings.ready();
      final ua = s.getString('userAgent');
      _userAgent =
          (ua == null || ua.isEmpty)
              ? DefaultHostEnvironment.defaultUserAgent
              : ua;
      _themeMode = switch (s.getString('themeMode')) {
        'light' => 1,
        'dark' => 2,
        _ => 0,
      };
      _bookConfig = _decodeMap(s.getString('readerSettings'));
      _themeConfig = {
        'family': s.getString('themeFamily'),
        'eink': s.getBool('einkTheme') ?? false,
        'style': s.getString('uiStyle'),
        'mode': _themeMode,
      };
    } catch (_) {
      // Settings are unavailable (early startup, tests). Keep the defaults
      // rather than failing a rule that merely reads a config value.
    }
  }

  static Map<String, Object?> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{};
    } catch (_) {
      return const {};
    }
  }

  @override
  String userAgent() => _userAgent;

  @override
  Map<String, Object?> readBookConfig() => _bookConfig;

  @override
  Map<String, Object?> themeConfig() => _themeConfig;

  @override
  int themeMode() => _themeMode;

  @override
  Future<bool> openUrl(String url, {String? mimeType}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openVideo(String url, String title, {bool float = false}) =>
      _fallback.openVideo(url, title, float: float);

  @override
  Future<String> startBrowser(
    String url, {
    String title = '',
    bool refetchAfterSuccess = false,
  }) => _fallback.startBrowser(
    url,
    title: title,
    refetchAfterSuccess: refetchAfterSuccess,
  );

  @override
  Future<String> verificationCode(String imageUrl) =>
      _fallback.verificationCode(imageUrl);
}
