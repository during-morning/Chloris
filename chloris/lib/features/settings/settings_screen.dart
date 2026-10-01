import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/settings/settings_providers.dart';
import '../../app/l10n/locale_provider.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/widgets/meow.dart';
import '../../services/persist/vault_sync.dart';
import 'about_screen.dart';
import '../reader/reading_settings_sheet.dart';
import '../../services/notification_service.dart';
import 'welcome_screen.dart';
import '../rules/rules_screen.dart';
import '../sources/sources_screen.dart';
import '../rss/rss_screen.dart';
import 'package:go_router/go_router.dart';
import 'all_bookmarks_screen.dart';
import 'backup_screen.dart';
import 'webdav_screen.dart';
import 'file_manage_screen.dart';
import 'read_record_screen.dart';
import 'cache_manage_screen.dart';
import 'web_service_screen.dart';
import 'cookie_manage_screen.dart';
import 'debug_log_screen.dart';

part 'settings_ua_tile.dart';
part 'settings_home.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _themeLabel(ThemeMode m) => switch (m) {
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
    ThemeMode.system => '跟随系统',
  };

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);
    final familyId = ref.read(themeFamilyIdProvider);
    final eink = ref.read(einkThemeProvider);
    final style = ref.read(uiStyleProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('外观', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('界面风格', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in AppUiStyle.values)
                    ChoiceChip(
                      avatar: _StyleDot(style: item),
                      label: Text(
                        item.label,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      selected: style == item,
                      onSelected: (_) async {
                        await applyUiStyle(ref, item);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(style.blurb, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ])
                    ChoiceChip(
                      label: Text(
                        _themeLabel(m),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      // Absolutely now offers paper (light) and slate (dark)
                      // canvases, so the mode chips unlock there too.
                      selected: current == m && style.fixedThemeMode == null,
                      avatar: style.fixedThemeMode == null
                          ? null
                          : const AppIcon(AppIcons.lock, size: 14),
                      onSelected: style.fixedThemeMode == null
                          ? (_) async {
                              ref.read(themeModeProvider.notifier).state = m;
                              await ref
                                  .read(settingsWriteUseCaseProvider)
                                  .setString('themeMode', m.name);
                              await syncVaultFromPrefs();
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (style == AppUiStyle.classic) ...[
                const MeowLabel('配色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in AppThemeFamily.all)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: f.seed),
                        label: Text(
                          f.label,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurface,
                          ),
                        ),
                        selected: familyId == f.id && !eink,
                        onSelected: (_) async {
                          ref.read(einkThemeProvider.notifier).state = false;
                          ref.read(themeFamilyIdProvider.notifier).state = f.id;
                          final writer = ref.read(settingsWriteUseCaseProvider);
                          await writer.setString('themeFamily', f.id);
                          await writer.setBool('einkTheme', false);
                          await syncVaultFromPrefs();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ChoiceChip(
                      label: Text(
                        '扁平 / 墨水屏',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      selected: eink,
                      onSelected: (_) async {
                        ref.read(einkThemeProvider.notifier).state = true;
                        await ref
                            .read(settingsWriteUseCaseProvider)
                            .setBool('einkTheme', true);
                        await syncVaultFromPrefs();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ] else
                Text(
                  style == AppUiStyle.absolutely
                      ? 'Absolutely 固定暖色浅色画布，标题使用衬线，图标为黑白两级。'
                      : '终端固定黑白单色，全等宽字体、1px 线框、零圆角。',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLang(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择语言'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'zh'),
            child: const Text('中文'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en'),
            child: const Text('English'),
          ),
        ],
      ),
    );
    if (choice != null) {
      ref.read(localeProvider.notifier).state = choice;
      await ref.read(settingsWriteUseCaseProvider).setString('locale', choice);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _SettingsHome();
  }
}

class _StyleDot extends StatelessWidget {
  const _StyleDot({required this.style});

  final AppUiStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      AppUiStyle.classic => CircleAvatar(
        radius: 9,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      // Cream swatch with the clay accent rule.
      AppUiStyle.absolutely => Container(
        width: 30,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F5),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFE4E0D5)),
        ),
        child: Container(width: 14, height: 3, color: const Color(0xFFC2603C)),
      ),
      // Black terminal cell with a white prompt.
      AppUiStyle.terminal => Container(
        width: 30,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: const Color(0xFF4A4A4A)),
        ),
        child: const Text(
          '>_',
          style: TextStyle(
            color: Color(0xFFF2F2F2),
            fontSize: 9,
            height: 1,
            fontFamily: AppTheme.terminalMono,
          ),
        ),
      ),
    };
  }
}
