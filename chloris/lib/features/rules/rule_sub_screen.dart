import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'replace_rules_controller.dart';
import 'rule_sub_service.dart';
import 'rule_sub_sync.dart';

/// 替换规则订阅管理页。
///
/// 功能：添加订阅 URL / 手动刷新单个 / 刷新全部 / 删除订阅并移除其规则 / 开关启用。
class RuleSubScreen extends ConsumerStatefulWidget {
  const RuleSubScreen({super.key});

  @override
  ConsumerState<RuleSubScreen> createState() => _RuleSubScreenState();
}

class _RuleSubScreenState extends ConsumerState<RuleSubScreen> {
  List<RuleSub> _subs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 确保底层替换规则已加载，订阅合并才基于正确基线。
    Future.microtask(
      () => ref.read(replaceRulesProvider.notifier).load(),
    );
    _reload();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _reload() async {
    final sync = ref.read(ruleSubSyncProvider);
    final subs = await sync.listSubscriptions();
    if (mounted) {
      setState(() {
        _subs = subs;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final urlC = TextEditingController();
    final nameC = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加替换规则订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlC,
              decoration: const InputDecoration(labelText: '订阅 URL'),
              autofocus: true,
            ),
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: '名称（可选）'),
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
            child: const Text('添加并拉取'),
          ),
        ],
      ),
    );
    final url = urlC.text.trim();
    if (result != true || url.isEmpty) return;
    setState(() => _loading = true);
    try {
      final sync = ref.read(ruleSubSyncProvider);
      final sub = await sync.addSubscription(
        url,
        name: nameC.text.trim().isEmpty ? null : nameC.text.trim(),
      );
      if (mounted) _toast('已添加订阅：${sub.name}');
      await _reload();
    } catch (e) {
      if (mounted) _toast('拉取失败：$e');
      await _reload();
    }
  }

  Future<void> _refreshOne(RuleSub sub) async {
    setState(() => _loading = true);
    try {
      final sync = ref.read(ruleSubSyncProvider);
      final n = await sync.refresh(sub.id);
      if (mounted) _toast('已刷新 $n 条（${sub.name}）');
    } catch (e) {
      if (mounted) _toast('刷新失败：$e');
    } finally {
      await _reload();
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      final sync = ref.read(ruleSubSyncProvider);
      final n = await sync.refreshAll();
      if (mounted) _toast('已全部刷新 $n 条');
    } catch (e) {
      if (mounted) _toast('刷新失败：$e');
    } finally {
      await _reload();
    }
  }

  Future<void> _remove(RuleSub sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('删除「${sub.name}」并移除其下所有替换规则？'),
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
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final sync = ref.read(ruleSubSyncProvider);
      await sync.removeSubscription(sub.id);
      if (mounted) _toast('已删除订阅：${sub.name}');
    } catch (e) {
      if (mounted) _toast('删除失败：$e');
    } finally {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('替换规则订阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新全部',
            onPressed: _loading ? null : _refreshAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _add,
        tooltip: '添加订阅',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subs.isEmpty
              ? const Center(child: Text('还没有订阅，点击右下角添加'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _subs.length,
                  itemBuilder: (context, i) {
                    final s = _subs[i];
                    final updated = s.lastUpdate > 0
                        ? DateTime.fromMillisecondsSinceEpoch(s.lastUpdate)
                        : null;
                    return Card(
                      child: ListTile(
                        leading: Switch(
                          value: s.enable,
                          onChanged: (v) async {
                            final sync = ref.read(ruleSubSyncProvider);
                            await sync.setEnabled(s.id, v);
                            await _reload();
                          },
                        ),
                        title: Text(s.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (updated != null)
                              Text(
                                '上次更新：${updated.toLocal()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: '刷新',
                              onPressed: () => _refreshOne(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '删除',
                              onPressed: () => _remove(s),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
