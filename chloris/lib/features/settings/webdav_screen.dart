import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/settings/settings_providers.dart';
import '../../application/settings/settings_use_cases.dart';
import '../../core/persist/kv_settings.dart';
import '../../services/persist/credentials.dart';

import '../rules/dict_rules_controller.dart';
import '../rules/replace_rules_controller.dart';
import '../rules/toc_rules_controller.dart';
import '../rss/rss_provider.dart';
import '../sources/source_library_provider.dart';

class WebDavScreen extends ConsumerStatefulWidget {
  const WebDavScreen({super.key});

  @override
  ConsumerState<WebDavScreen> createState() => _WebDavScreenState();
}

class _WebDavScreenState extends ConsumerState<WebDavScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _path = TextEditingController(text: '/chloris-backup.zip');
  String _status = '';
  List<String> _listing = const [];
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    KvSettings.ready().then((p) {
      _url.text = p.getString('webdavUrl') ?? '';
      _user.text = p.getString('webdavUser') ?? '';
      _path.text = p.getString('webdavPath') ?? '/chloris-backup.zip';
      if (mounted) setState(() {});
    });
    // The password is not a plain setting: it lives in the encrypted
    // credential vault, not beside the URL and username in the preferences.
    CredentialStore.webdavPassword().then((value) {
      if (mounted && value.isNotEmpty) setState(() => _pass.text = value);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _path.dispose();
    super.dispose();
  }

  WebDavConfig _config() => WebDavConfig(
    baseUrl: _url.text.trim(),
    username: _user.text.trim(),
    password: _pass.text,
  );

  Future<void> _save() async {
    final p = await KvSettings.ready();
    await p.setString('webdavUrl', _url.text.trim());
    await p.setString('webdavUser', _user.text.trim());
    await p.setString('webdavPath', _path.text.trim());
    await CredentialStore.setWebdavPassword(_pass.text);
    setState(() => _status = '已保存');
  }

  Future<void> _test() async {
    setState(() => _status = '连接中…');
    try {
      final list = await ref.read(webDavUseCasesProvider).list(_config(), '/');
      setState(() {
        _listing = list;
        _status = '列出 ' + list.length.toString() + ' 项';
      });
    } catch (e) {
      setState(() => _status = '失败：' + e.toString());
    }
  }

  Future<void> _upload() async {
    final sources = await ref.read(allSourcesProvider.future);
    await ref.read(replaceRulesProvider.notifier).load();
    await ref.read(tocRulesController.notifier).load();
    await ref.read(dictRulesController.notifier).load();
    final snapshot = BackupSnapshot(
      sources: sources,
      replaces: ref.read(replaceRulesProvider),
      tocs: ref.read(tocRulesController),
      rssSources: ref.read(importedRssSourcesProvider),
      dictRules: ref.read(dictRulesController),
    );
    final zip = ref.read(createBackupUseCaseProvider)(snapshot);
    setState(() => _status = '上传中…');
    try {
      final path = _path.text.trim().isEmpty
          ? '/chloris-backup.zip'
          : _path.text.trim();
      final ok = await ref
          .read(webDavUseCasesProvider)
          .upload(_config(), path, zip);
      setState(() => _status = ok ? '已上传 ' + path : '上传失败');
    } catch (e) {
      setState(() => _status = '上传失败：' + e.toString());
    }
  }

  Future<void> _download() async {
    setState(() => _status = '下载中…');
    try {
      final path = _path.text.trim().isEmpty
          ? '/chloris-backup.zip'
          : _path.text.trim();
      final bytes = await ref
          .read(webDavUseCasesProvider)
          .download(_config(), path);
      if (bytes == null) {
        setState(() => _status = '没有 ' + path);
        return;
      }
      final data = ref.read(restoreBackupUseCaseProvider)(bytes);
      ref.read(importedSourcesProvider.notifier).addAll(data.sources);
      ref.read(replaceRulesProvider.notifier).addAll(data.replaces);
      ref.read(tocRulesController.notifier).addAll(data.tocs);
      await ref.read(dictRulesController.notifier).load();
      ref.read(dictRulesController.notifier).addAll(data.dictRules);
      ref.read(importedRssSourcesProvider.notifier).addAll(data.rssSources);
      setState(() => _status = '已从 WebDAV 恢复');
    } catch (e) {
      setState(() => _status = '恢复失败：' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('WebDAV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            decoration: const InputDecoration(labelText: '服务器 URL'),
          ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(labelText: '用户名'),
          ),
          TextField(
            controller: _pass,
            obscureText: !_showPass,
            decoration: InputDecoration(
              labelText: '密码',
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          TextField(
            controller: _path,
            decoration: const InputDecoration(
              labelText: '备份路径',
              hintText: '/chloris-backup.zip',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _save, child: const Text('保存')),
              OutlinedButton(onPressed: _test, child: const Text('测试列出')),
              OutlinedButton(onPressed: _upload, child: const Text('上传备份')),
              OutlinedButton(onPressed: _download, child: const Text('下载恢复')),
              OutlinedButton(
                onPressed: () async {
                  final path = _path.text.trim().isEmpty
                      ? '/chloris-backup.zip'
                      : _path.text.trim();
                  setState(() => _status = '删除中…');
                  try {
                    final ok = await ref
                        .read(webDavUseCasesProvider)
                        .remove(_config(), path);
                    setState(() => _status = ok ? '已删除 ' + path : '删除失败');
                  } catch (e) {
                    setState(() => _status = '删除失败：' + e.toString());
                  }
                },
                child: const Text('删除远程备份'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_status),
          for (final h in _listing)
            ListTile(
              dense: true,
              title: Text(h),
              onTap: () {
                _path.text = h.startsWith('/') ? h : '/' + h;
                setState(() {});
              },
            ),
        ],
      ),
    );
  }
}
