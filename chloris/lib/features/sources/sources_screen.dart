import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/meow.dart';
import 'qr_scanner_screen.dart';
import 'source_debug_screen.dart';
import 'source_edit_screen.dart';
import 'source_login_screen.dart';
import 'source_import.dart';
import 'source_library_provider.dart';
import '../../application/sources/source_unify.dart';
import '../../app/providers.dart';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  Future<void> _importSources(WidgetRef ref) => importSourcesFromFile(ref);

  Future<void> _importClipboard(BuildContext context, WidgetRef ref) =>
      importSourcesFromClipboard(context, ref);

  Future<void> _importUrl(BuildContext context, WidgetRef ref) =>
      importSourcesFromUrl(context, ref);

  Future<void> _validateSources(
    BuildContext context,
    WidgetRef ref,
    List<BookSource> sources,
  ) => validateShownSources(context, ref, sources);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(allSourcesProvider);
    final filtered = ref.watch(filteredSourcesProvider);
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载书源失败：' + e.toString())),
        data: (list) {
          final enabledCount = list.where((s) => s.enabled).length;
          final filter = ref.watch(sourceGroupFilterProvider);
          final groups = unifiedSourceGroups
              .where((g) => list.any((s) => displaySourceGroup(s) == g))
              .toList();
          final typeF = ref.watch(sourceTypeFilterProvider);
          final shown = filtered.valueOrNull ?? list;
          return MeowPage(
            eyebrow: '书源',
            title: '书源管理',
            showBackButton: true,
            subtitle:
                '共 ' +
                list.length.toString() +
                ' 条，启用 ' +
                enabledCount.toString(),
            actions: [
              MeowIconButton(
                icon: Icons.done_all,
                tooltip: '启用当前列表',
                onPressed: () {
                  for (final s in shown) {
                    ref
                        .read(sourceEnabledOverrideProvider.notifier)
                        .setEnabled(s.bookSourceUrl, true);
                  }
                },
              ),
              MeowIconButton(
                icon: Icons.health_and_safety_outlined,
                tooltip: '批量校验书源',
                onPressed: () => _validateSources(context, ref, shown),
              ),
              MeowIconButton(
                icon: Icons.remove_done,
                tooltip: '停用当前列表',
                onPressed: () {
                  for (final s in shown) {
                    ref
                        .read(sourceEnabledOverrideProvider.notifier)
                        .setEnabled(s.bookSourceUrl, false);
                  }
                },
              ),
              MeowIconButton(
                icon: Icons.copy_all,
                tooltip: '复制当前列表 JSON',
                onPressed: () async {
                  final json = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(shown.map((e) => e.toJson()).toList());
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '已复制 ' + shown.length.toString() + ' 条书源',
                        ),
                      ),
                    );
                  }
                },
              ),
              MeowIconButton(
                icon: Icons.file_download_outlined,
                tooltip: '导入书源 JSON',
                onPressed: () => _importSources(ref),
              ),
              MeowIconButton(
                icon: Icons.content_paste,
                tooltip: '从剪贴板导入 JSON',
                onPressed: () => _importClipboard(context, ref),
              ),
              MeowIconButton(
                icon: Icons.link,
                tooltip: '从 URL 导入',
                onPressed: () => _importUrl(context, ref),
              ),
              MeowIconButton(
                icon: Icons.qr_code_scanner,
                tooltip: '扫码导入书源',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                ),
              ),
            ],
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('全部'),
                          selected: filter == null,
                          onSelected: (_) => ref
                              .read(sourceGroupFilterProvider.notifier)
                              .setValue(null),
                        ),
                      ),
                      for (final g in groups)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(g),
                            selected: filter == g,
                            onSelected: (_) => ref
                                .read(sourceGroupFilterProvider.notifier)
                                .setValue(g),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('仅显示启用'),
                    selected: ref.watch(sourceOnlyEnabledProvider),
                    onSelected: (v) => ref
                        .read(sourceOnlyEnabledProvider.notifier)
                        .setValue(v),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in <(String, String)>[
                        ('', '全部类型'),
                        (BookSourceType.text.toString(), '文本'),
                        (BookSourceType.audio.toString(), '音频'),
                        (BookSourceType.image.toString(), '漫画'),
                        (BookSourceType.video.toString(), '视频'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(e.$2),
                            selected: (typeF ?? '') == e.$1,
                            onSelected: (_) => ref
                                .read(sourceTypeFilterProvider.notifier)
                                .setValue(e.$1.isEmpty ? null : e.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                MeowQueryField(
                  hint: '筛选书源名称 / URL',
                  onChanged: (v) =>
                      ref.read(sourceNameQueryProvider.notifier).state = v
                          .trim(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final s = shown[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SourceEditScreen(source: s),
                            ),
                          ),
                          onLongPress: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('删除书源？'),
                                content: Text(s.bookSourceName),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              ref
                                  .read(importedSourcesProvider.notifier)
                                  .remove(s.bookSourceUrl);
                              ref
                                  .read(sourceEnabledOverrideProvider.notifier)
                                  .setEnabled(s.bookSourceUrl, false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: s.enabled ? c.accent : c.muted,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              s.bookSourceName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: c.ink,
                                              ),
                                            ),
                                          ),
                                          if (s.bookSourceType !=
                                              BookSourceType.text)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              child: Text(
                                                BookSourceType.label(
                                                  s.bookSourceType,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: c.accent,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (s.bookSourceGroup ?? '未分组') +
                                            ' · ' +
                                            s.bookSourceUrl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: c.muted,
                                          fontFamily: 'Menlo',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (s.hasLoginUrl)
                                  IconButton(
                                    tooltip: '登录',
                                    icon: const Icon(Icons.login, size: 20),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SourceLoginScreen(source: s),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: '复制此源 JSON',
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () async {
                                    final json = const JsonEncoder.withIndent(
                                      '  ',
                                    ).convert(s.toJson());
                                    await Clipboard.setData(
                                      ClipboardData(text: json),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('已复制该书源 JSON'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: '调试',
                                  icon: const Icon(
                                    Icons.bug_report_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SourceDebugScreen(source: s),
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: s.enabled,
                                  onChanged: (v) {
                                    ref
                                        .read(
                                          sourceEnabledOverrideProvider
                                              .notifier,
                                        )
                                        .setEnabled(s.bookSourceUrl, v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
