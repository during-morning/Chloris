import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/theme_provider.dart';
import '../../app/widgets/meow.dart';
import 'reader_keys.dart';
import 'reader_palette.dart';
import 'reader_settings_provider.dart';

Future<void> showReadingSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ReaderSettingsSheet(),
  );
}

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readerSettingsProvider);
    final n = ref.read(readerSettingsProvider.notifier);
    final pal = s.palette;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<AppStyleExtension>();
    final ui = ext?.style ?? AppUiStyle.classic;
    final isClassic = ui == AppUiStyle.classic;
    final mono = ext?.mono ?? false;
    final family = AppThemeFamily.byId(ref.watch(themeFamilyIdProvider));
    final eink = isClassic && ref.watch(einkThemeProvider);
    final bg = pal.bgColor(
      cs,
      overrideBg: s.background,
      family: family,
      eink: eink,
    );
    final fg = pal.fgColor(
      cs,
      overrideFg: s.foreground,
      family: family,
      eink: eink,
    );
    final previewFamily = s.fontFamily.isNotEmpty
        ? s.fontFamily
        : ext?.readerFamily;
    final papers = ReaderPalette.forStyle(ui);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space20,
          0,
          AppTokens.space20,
          AppTokens.space32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('阅读设置', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppTokens.space16),
            // Live paper + type preview.
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(ext?.pageRadius ?? 12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                '落霞与孤鹜齐飞',
                style: TextStyle(
                  color: fg,
                  fontSize: s.fontSize.toDouble(),
                  height: s.lineHeight,
                  letterSpacing: s.letterSpacing,
                  fontFamily: previewFamily,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space20),
            MeowLabel(isClassic ? '纸张' : '纸张 · 随风格'),
            const SizedBox(height: AppTokens.space10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in papers)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: t.followApp
                          ? cs.onSurface
                          : Color(t.background),
                    ),
                    label: Text(t.followApp ? '跟随应用' : t.label),
                    selected: !eink && s.paletteId == t.id,
                    onSelected: (_) async {
                      if (eink) await applyThemeFamily(ref, family.id);
                      n.setPalette(t);
                    },
                  ),
              ],
            ),
            // The 13 Material families and the e-ink variant only make sense
            // for the classic style; Absolutely and terminal are fixed palettes.
            if (isClassic) ...[
              const SizedBox(height: AppTokens.space20),
              const MeowLabel('配色'),
              const SizedBox(height: AppTokens.space10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in AppThemeFamily.all)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: f.seed),
                      label: Text(f.label),
                      selected:
                          !eink && family.id == f.id && s.palette.followApp,
                      onSelected: (_) async {
                        n.setPalette(ReaderPalette.follow);
                        await applyThemeFamily(ref, f.id);
                      },
                    ),
                  ChoiceChip(
                    label: const Text('墨水屏'),
                    selected: eink,
                    onSelected: (_) async {
                      n.setPalette(ReaderPalette.follow);
                      await applyThemeFamily(ref, family.id, eink: true);
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTokens.space20),
            const MeowLabel('自定义'),
            const SizedBox(height: AppTokens.space10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final next = await _pickTone(context, s.background, '背景色');
                    if (next == null) return;
                    n.update(s.copyWith(background: next, paletteId: 'custom'));
                  },
                  child: const Text('背景色'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final next = await _pickTone(context, s.foreground, '文字色');
                    if (next == null) return;
                    n.update(s.copyWith(foreground: next, paletteId: 'custom'));
                  },
                  child: const Text('文字色'),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space20),
            MeowLabel('字体${mono ? ' · 等宽' : ''}'),
            const SizedBox(height: AppTokens.space8),
            DropdownButton<String>(
              isExpanded: true,
              value: s.fontFamily.isEmpty ? '' : s.fontFamily,
              items: const [
                DropdownMenuItem(value: '', child: Text('跟随风格')),
                DropdownMenuItem(
                  value: AppTheme.absolutelySerif,
                  child: Text('PT Serif · 衬线'),
                ),
                DropdownMenuItem(
                  value: AppTheme.absolutelySans,
                  child: Text('Source Sans Pro'),
                ),
                DropdownMenuItem(
                  value: AppTheme.terminalMono,
                  child: Text('IBM Plex Mono · 等宽'),
                ),
                DropdownMenuItem(
                  value: AppTheme.cjkSansFallback,
                  child: Text('Noto Sans SC · 黑体'),
                ),
                DropdownMenuItem(
                  value: AppTheme.cjkSerifFallback,
                  child: Text('Noto Serif SC · 宋体'),
                ),
                DropdownMenuItem(
                  value: 'PingFang SC',
                  child: Text('PingFang SC（系统）'),
                ),
                DropdownMenuItem(value: 'serif', child: Text('系统衬线')),
              ],
              onChanged: (v) => n.update(s.copyWith(fontFamily: v ?? '')),
            ),
            const SizedBox(height: AppTokens.space12),
            _ReaderSlider(
              label: '字号',
              value: s.fontSize.toString(),
              slider: Slider(
                value: s.fontSize.toDouble(),
                min: 14,
                max: 32,
                divisions: 18,
                onChanged: (v) => n.update(s.copyWith(fontSize: v.round())),
              ),
            ),
            _ReaderSlider(
              label: '行距',
              value: s.lineHeight.toStringAsFixed(1),
              slider: Slider(
                value: s.lineHeight,
                min: 1.3,
                max: 2.4,
                divisions: 11,
                onChanged: (v) => n.update(s.copyWith(lineHeight: v)),
              ),
            ),
            _ReaderSlider(
              label: '字距',
              value: s.letterSpacing.toStringAsFixed(1),
              slider: Slider(
                value: s.letterSpacing.clamp(0, 4),
                min: 0,
                max: 4,
                divisions: 8,
                onChanged: (v) => n.update(s.copyWith(letterSpacing: v)),
              ),
            ),
            _ReaderSlider(
              label: '段距',
              value: s.paragraphSpacing.toStringAsFixed(0),
              slider: Slider(
                value: s.paragraphSpacing,
                min: 0,
                max: 24,
                divisions: 12,
                onChanged: (v) => n.update(s.copyWith(paragraphSpacing: v)),
              ),
            ),
            _ReaderSlider(
              label: '页边距',
              value: s.pagePadding.toString(),
              slider: Slider(
                value: s.pagePadding.toDouble(),
                min: 12,
                max: 48,
                divisions: 12,
                onChanged: (v) => n.update(s.copyWith(pagePadding: v.round())),
              ),
            ),
            _ReaderSlider(
              label: '亮度',
              value: '${(s.brightness * 100).round()}%',
              slider: Slider(
                value: s.brightness.clamp(0.3, 1.0),
                min: 0.3,
                max: 1.0,
                divisions: 14,
                onChanged: (v) => n.update(s.copyWith(brightness: v)),
              ),
            ),
            _ReaderSlider(
              label: '自动翻页',
              value: '${s.autoSeconds} 秒',
              slider: Slider(
                value: s.autoSeconds.toDouble(),
                min: 3,
                max: 30,
                divisions: 27,
                onChanged: (v) => n.update(s.copyWith(autoSeconds: v.round())),
              ),
            ),
            _ReaderSlider(
              label: '首行缩进',
              value: '${s.paragraphIndent} 字',
              slider: Slider(
                value: s.paragraphIndent.toDouble(),
                min: 0,
                max: 6,
                divisions: 6,
                onChanged: (v) =>
                    n.update(s.copyWith(paragraphIndent: v.round())),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            const MeowRule(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用替换净化'),
              subtitle: const Text('打开书籍时默认开启，自动套用净化规则'),
              value: s.enableReplace,
              onChanged: (v) => n.update(s.copyWith(enableReplace: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('屏幕常亮'),
              subtitle: const Text('阅读时不自动锁屏'),
              value: s.keepScreenOn,
              onChanged: (v) => n.update(s.copyWith(keepScreenOn: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('方向锁定'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('跟随')),
                  ButtonSegment(value: 'portrait', label: Text('竖屏')),
                  ButtonSegment(value: 'landscape', label: Text('横屏')),
                ],
                selected: {s.orientation},
                onSelectionChanged: (sel) =>
                    n.update(s.copyWith(orientation: sel.first)),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('菜单自动收起'),
              subtitle: const Text('弹出约 4 秒后隐藏'),
              value: s.autoHideMenu,
              onChanged: (v) => n.update(s.copyWith(autoHideMenu: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('繁体显示'),
              value: s.chineseConvert,
              onChanged: (v) => n.update(s.copyWith(chineseConvert: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('左右点击翻转'),
              value: s.clickReverse,
              onChanged: (v) => n.update(s.copyWith(clickReverse: v)),
            ),
            const MeowRule(),
            const SizedBox(height: AppTokens.space16),
            const MeowLabel('翻页'),
            for (final anim in PageAnim.choices)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: Text(PageAnim.label(anim)),
                value: anim,
                groupValue: PageAnim.normalize(s.pageAnim),
                onChanged: (v) {
                  if (v != null) n.update(s.copyWith(pageAnim: v));
                },
              ),
            const SizedBox(height: AppTokens.space8),
            const MeowLabel('双页视图'),
            for (final mode in DoublePageMode.values)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(mode.label),
                value: mode.id,
                groupValue: s.doublePage,
                onChanged: (v) {
                  if (v != null) n.update(s.copyWith(doublePage: v));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Label + value row above a slider, so the reading controls read as a
/// settings table rather than a wall of loose text.
class _ReaderSlider extends StatelessWidget {
  const _ReaderSlider({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppTokens.space8),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: slider,
          ),
        ),
      ],
    );
  }
}

Future<int?> _pickTone(BuildContext context, int current, String label) async {
  const presets = <int>[
    0xFFF7F7F5,
    0xFFFFFFFF,
    0xFFFAF9F5,
    0xFFF6E7D8,
    0xFFF3E5C3,
    0xFFE8E6E3,
    0xFFC7EDCC,
    0xFF121212,
    0xFF0A0A0A,
    0xFF000000,
    0xFF1F1E1D,
  ];
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in presets)
            InkWell(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == current
                        ? Theme.of(ctx).colorScheme.primary
                        : Theme.of(ctx).colorScheme.outlineVariant,
                    width: c == current ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
