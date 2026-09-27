import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/meow.dart';
import '../../app/widgets/sharp_network_image.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../application/rss/rss_models.dart';
import 'rss_provider.dart';
import '../reader/html_content.dart';

part 'rss_pages.dart';

class RssScreen extends ConsumerWidget {
  const RssScreen({super.key});

  Future<void> _addSource(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加订阅源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'RSS / Atom URL',
                hintText: 'https://…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    final u = url.text.trim();
    if (ok != true || u.isEmpty) return;
    ref.read(importedRssSourcesProvider.notifier).addAll([
      RssSource(
        sourceUrl: u,
        sourceName: name.text.trim().isEmpty ? u : name.text.trim(),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(allRssSourcesProvider);
    final c = AppColors.of(context);
    final actions = <Widget>[
      IconButton(
        tooltip: '复制订阅源 JSON',
        icon: const Icon(Icons.copy),
        onPressed: () async {
          final list = sources.asData?.value ?? const <RssSource>[];
          final json = const JsonEncoder.withIndent(
            '  ',
          ).convert(list.map((e) => e.toJson()).toList());
          await Clipboard.setData(ClipboardData(text: json));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已复制 ' + list.length.toString() + ' 条订阅源'),
              ),
            );
          }
        },
      ),
      IconButton(
        tooltip: '从 URL 导入 JSON',
        icon: const Icon(Icons.link),
        onPressed: () async {
          final ctrl = TextEditingController();
          final url = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('从 URL 导入订阅源'),
              content: TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: 'https://…json'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('导入'),
                ),
              ],
            ),
          );
          if (url == null || url.isEmpty) return;
          try {
            final n = await importRssSourcesFromUrl(ref, url);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已导入 ' + n.toString() + ' 条')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('导入失败：' + e.toString())));
            }
          }
        },
      ),
      IconButton(
        tooltip: '从剪贴板导入 JSON',
        icon: const Icon(Icons.content_paste),
        onPressed: () async {
          final data = await Clipboard.getData('text/plain');
          final raw = data?.text;
          if (raw == null || raw.trim().isEmpty) return;
          try {
            final list = RssSource.listFromJson(jsonDecode(raw));
            if (list.isEmpty) return;
            ref.read(importedRssSourcesProvider.notifier).addAll(list);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已导入 ' + list.length.toString() + ' 条订阅源'),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('导入失败：' + e.toString())));
            }
          }
        },
      ),
      IconButton(
        tooltip: '添加订阅源',
        icon: const Icon(Icons.add),
        onPressed: () => _addSource(context, ref),
      ),
      IconButton(
        tooltip: '收藏',
        icon: const Icon(Icons.star_outline),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RssFavoritesPage()),
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: '订阅',
        title: '订阅',
        showBackButton: true,
        actions: actions,
        child: sources.when(
          loading: () => const MeowLoading(),
          error: (e, _) => MeowError(message: '加载订阅源失败：$e'),
          data: (list) {
            final q = ref.watch(rssNameQueryProvider).toLowerCase();
            final enabled = list.where((s) {
              if (!s.enabled) return false;
              if (q.isEmpty) return true;
              return s.sourceName.toLowerCase().contains(q) ||
                  s.sourceUrl.toLowerCase().contains(q);
            }).toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: MeowQueryField(
                    hint: '筛选订阅源',
                    onChanged: (v) =>
                        ref.read(rssNameQueryProvider.notifier).state = v
                            .trim(),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: enabled.length,
                    itemBuilder: (context, i) {
                      final source = enabled[i];
                      return GestureDetector(
                        onLongPress: () async {
                          final imported = ref.read(importedRssSourcesProvider);
                          final isImported = imported.any(
                            (s) => s.sourceUrl == source.sourceUrl,
                          );
                          if (!isImported) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('内置订阅源不能移除')),
                            );
                            return;
                          }
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('移除订阅源？'),
                              content: Text(source.sourceName),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('移除'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            ref
                                .read(importedRssSourcesProvider.notifier)
                                .remove(source.sourceUrl);
                          }
                        },
                        child: ExpansionTile(
                          leading:
                              source.sourceIcon != null &&
                                  source.sourceIcon!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SharpNetworkImage(
                                    url: source.sourceIcon!,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.rss_feed),
                                  ),
                                )
                              : const Icon(Icons.rss_feed),
                          title: Text(source.sourceName),
                          subtitle: Text(
                            source.sourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.style_outlined),
                                title: const Text('文章样式'),
                                trailing: DropdownButton<int>(
                                  value: source.articleStyle.clamp(0, 2).toInt(),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('标准')),
                                    DropdownMenuItem(value: 1, child: Text('舒展')),
                                    DropdownMenuItem(value: 2, child: Text('紧凑')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    final imported = ref.read(importedRssSourcesProvider);
                                    if (!imported.any((s) => s.sourceUrl == source.sourceUrl)) return;
                                    ref.read(importedRssSourcesProvider.notifier).updateStyle(source.sourceUrl, value);
                                  },
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      ref.invalidate(rssArticlesProvider(source)),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('刷新文章'),
                                ),
                              ),
                              _Articles(source: source),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
