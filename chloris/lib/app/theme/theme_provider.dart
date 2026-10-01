import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persist/kv_settings.dart';
import '../../services/persist/vault_sync.dart';
import 'app_theme.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

Future<void> applyThemeMode(WidgetRef ref, ThemeMode next) async {
  ref.read(themeModeProvider.notifier).state = next;
  final prefs = await KvSettings.ready();
  await prefs.setString('themeMode', next.name);
  await syncVaultFromPrefs();
}

Future<void> applyThemeFamily(
  WidgetRef ref,
  String id, {
  bool eink = false,
}) async {
  ref.read(themeFamilyIdProvider.notifier).state = id;
  ref.read(einkThemeProvider.notifier).state = eink;
  final prefs = await KvSettings.ready();
  await prefs.setString('themeFamily', id);
  await prefs.setBool('einkTheme', eink);
  await syncVaultFromPrefs();
}

Future<void> applyUiStyle(WidgetRef ref, AppUiStyle style) async {
  ref.read(uiStyleProvider.notifier).state = style;
  final prefs = await KvSettings.ready();
  await prefs.setString('uiStyle', style.id);
  await syncVaultFromPrefs();
}

ThemeMode flipThemeMode(ThemeMode current) =>
    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
final themeFamilyIdProvider = StateProvider<String>((ref) => 'green');
final einkThemeProvider = StateProvider<bool>((ref) => false);
final uiStyleProvider = StateProvider<AppUiStyle>(
  (ref) => AppUiStyle.absolutely,
);

/// 界面文字缩放（无障碍）。阅读正文仍用阅读设置字号。
final uiTextScaleProvider = StateProvider<double>((ref) => 1.0);
final reduceMotionProvider = StateProvider<bool>((ref) => false);
final highContrastProvider = StateProvider<bool>((ref) => false);
final boldTextProvider = StateProvider<bool>((ref) => false);
final debugVerboseProvider = StateProvider<bool>((ref) => false);
final httpTimeoutSecProvider = StateProvider<int>((ref) => 15);
final searchTimeoutSecProvider = StateProvider<int>((ref) => 12);
final searchPoolProvider = StateProvider<int>((ref) => 32);
final downloadPoolProvider = StateProvider<int>((ref) => 8);
final searchHostCapProvider = StateProvider<int>((ref) => 2);
final downloadHostCapProvider = StateProvider<int>((ref) => 3);
final userAgentProvider = StateProvider<String>((ref) => '');
