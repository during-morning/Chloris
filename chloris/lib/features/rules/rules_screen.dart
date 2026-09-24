import 'package:flutter/material.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/config_import_service.dart';
import '../sources/source_library_provider.dart';
import 'replace_rules_controller.dart';
import 'dict_rules_controller.dart';
import 'toc_rules_controller.dart';
import 'rule_sub_screen.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('规则管理'),
          actions: [
            IconButton(
              icon: const Icon(Icons.cloud_download_outlined),
              tooltip: '替换规则订阅管理',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RuleSubScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: '导入一键配置包',
              onPressed: () => _importConfig(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '净化'),
              Tab(text: '字典'),
              Tab(text: '目录'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReplaceTab(),
            _DictTab(),
            const _PlainList(title: 'TXT 目录规则'),
          ],
        ),
      ),
    );
  }
}

class _ReplaceTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReplaceTab> createState() => _ReplaceTabState();
}

class _ReplaceTabState extends ConsumerState<_ReplaceTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(replaceRulesProvider.notifier).load());
  }

  Future<ReplaceRule?> _editDialog(ReplaceRule? existing) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final patternController = TextEditingController(
      text: existing?.pattern ?? '',
    );
    final replController = TextEditingController(
      text: existing?.replacement ?? '',
    );
    var enabled = existing?.isEnabled ?? true;
    return showDialog<ReplaceRule>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增净化规则' : '编辑净化规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: patternController,
                  decoration: const InputDecoration(labelText: '匹配(正则)'),
                ),
                TextField(
                  controller: replController,
                  decoration: const InputDecoration(labelText: '替换为'),
                ),
                SwitchListTile(
                  title: const Text('启用'),
                  value: enabled,
                  onChanged: (v) => setState(() => enabled = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                ReplaceRule(
                  id: existing?.id,
                  name: nameController.text.trim().isEmpty
                      ? '未命名'
                      : nameController.text.trim(),
                  pattern: patternController.text,
                  replacement: replController.text,
                  isEnabled: enabled,
                  isRegex: true,
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(replaceRulesProvider);
    if (rules.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }
    final notifier = ref.read(replaceRulesProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('新增规则'),
              onPressed: () async {
                final r = await _editDialog(null);
                if (r != null) notifier.add(r);
              },
            ),
          ),
        ),
        ...List.generate(rules.length, (i) {
          final r = rules[i];
          return Card(
            child: ListTile(
              leading: Switch(
                value: r.isEnabled,
                onChanged: (v) => notifier.update(i, r..isEnabled = v),
              ),
              title: Text(r.name),
              subtitle: Text(
                r.pattern,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final updated = await _editDialog(r);
                  if (updated != null) notifier.update(i, updated);
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DictTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DictTab> createState() => _DictTabState();
}

class _DictTabState extends ConsumerState<_DictTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dictRulesController.notifier).load());
  }

  Future<void> _edit(int index, Map<String, dynamic> current) async {
    final nameC = TextEditingController(
      text: current['name']?.toString() ?? '',
    );
    final urlC = TextEditingController(
      text: current['urlRule']?.toString() ?? '',
    );
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑字典规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: urlC,
              decoration: const InputDecoration(labelText: 'URL 规则'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              ...current,
              'name': nameC.text.trim(),
              'urlRule': urlC.text,
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (updated != null) {
      ref.read(dictRulesController.notifier).update(index, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(dictRulesController);
    if (rules.isEmpty) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: rules.length,
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.translate),
        title: Text(rules[i]['name']?.toString() ?? ''),
        subtitle: Text(
          rules[i]['urlRule']?.toString() ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _edit(i, rules[i]),
        ),
      ),
    );
  }
}

class _PlainList extends ConsumerStatefulWidget {
  const _PlainList({required this.title});

  final String title;

  @override
  ConsumerState<_PlainList> createState() => _PlainListState();
}

class _PlainListState extends ConsumerState<_PlainList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(tocRulesController.notifier).load());
  }

  Future<void> _edit(int index, TxtTocRule current) async {
    final nameC = TextEditingController(text: current.name);
    final ruleC = TextEditingController(text: current.rule);
    final updated = await showDialog<TxtTocRule>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑目录规则'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: ruleC,
              decoration: const InputDecoration(labelText: '正则'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              TxtTocRule(
                name: nameC.text.trim(),
                rule: ruleC.text,
                enable: current.enable,
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (updated != null) {
      ref.read(tocRulesController.notifier).update(index, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(tocRulesController);
    if (rules.isEmpty) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: rules.length,
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.format_list_bulleted),
        title: Text(rules[i].name),
        subtitle: Text(
          rules[i].rule,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _edit(i, rules[i]),
        ),
      ),
    );
  }
}

Future<void> _importConfig(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final b = result.files.single.bytes;
  if (b == null) return;
  final cfg = const ConfigImportService().parse(b);
  if (cfg.bookSources.isNotEmpty) {
    ref.read(importedSourcesProvider.notifier).addAll(cfg.bookSources);
  }
  if (cfg.replaceRules.isNotEmpty) {
    final rn = ref.read(replaceRulesProvider.notifier);
    await rn.load();
    rn.addAll(cfg.replaceRules);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已导入：书源 ${cfg.bookSources.length}、净化 ${cfg.replaceRules.length}、RSS ${cfg.rssSources.length}',
        ),
      ),
    );
  }
}
