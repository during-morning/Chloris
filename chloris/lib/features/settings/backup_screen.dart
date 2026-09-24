import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/settings/settings_providers.dart';
import '../../application/settings/settings_use_cases.dart';
import '../../services/config_import_service.dart';
import '../rules/dict_rules_controller.dart';
import '../rules/replace_rules_controller.dart';
import '../rules/toc_rules_controller.dart';
import '../rss/rss_provider.dart';
import '../sources/source_library_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _password = TextEditingController();
  String? _msg;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _export() async {
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
    final zip = ref.read(createBackupUseCaseProvider)(
      snapshot,
      password: _password.text.trim().isEmpty ? null : _password.text.trim(),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            zip,
            mimeType: 'application/zip',
            name: 'chloris-backup.zip',
          ),
        ],
      ),
    );
    setState(() => _msg = '已导出备份');
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(() => _msg = '无法读取文件');
      return;
    }
    try {
      final data = ref.read(restoreBackupUseCaseProvider)(
        bytes,
        password: _password.text.trim().isEmpty ? null : _password.text.trim(),
      );
      ref.read(importedSourcesProvider.notifier).addAll(data.sources);
      ref.read(replaceRulesProvider.notifier).addAll(data.replaces);
      ref.read(tocRulesController.notifier).addAll(data.tocs);
      await ref.read(dictRulesController.notifier).load();
      ref.read(dictRulesController.notifier).addAll(data.dictRules);
      ref.read(importedRssSourcesProvider.notifier).addAll(data.rssSources);
      setState(
        () => _msg =
            '已恢复 源 ' +
            data.sources.length.toString() +
            ' / 净化 ' +
            data.replaces.length.toString() +
            ' / 订阅源 ' +
            data.rssSources.length.toString(),
      );
    } catch (e) {
      setState(() => _msg = '恢复失败：' + e.toString());
    }
  }

  Future<void> _importLegado() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(() => _msg = '无法读取文件');
      return;
    }
    try {
      final name = result.files.single.name.toLowerCase();
      if (name.endsWith('.json')) {
        final list = BookSource.listFromJson(jsonDecode(utf8.decode(bytes)));
        ref.read(importedSourcesProvider.notifier).addAll(list);
        setState(() => _msg = '已导入 legado 书源 ' + list.length.toString() + ' 条');
        return;
      }
      final data = const ConfigImportService().parse(bytes);
      ref.read(importedSourcesProvider.notifier).addAll(data.bookSources);
      ref.read(replaceRulesProvider.notifier).addAll(data.replaceRules);
      ref.read(tocRulesController.notifier).addAll(data.tocRules);
      await ref.read(dictRulesController.notifier).load();
      ref.read(dictRulesController.notifier).addAll(data.dictRules);
      ref.read(importedRssSourcesProvider.notifier).addAll(data.rssSources);
      setState(
        () => _msg =
            '已导入 legado 配置 源 ' +
            data.bookSources.length.toString() +
            ' / 净化 ' +
            data.replaceRules.length.toString() +
            ' / 订阅源 ' +
            data.rssSources.length.toString(),
      );
    } catch (e) {
      setState(() => _msg = 'legado 导入失败：' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('导出书源、净化规则、TXT 目录规则为 zip，可选 AES 密码。'),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: '可选密码（AES-256）'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.upload_file),
            label: const Text('导出备份'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _import,
            icon: const Icon(Icons.download),
            label: const Text('从 zip 恢复'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _importLegado,
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('导入 legado 配置包 / bookSource.json'),
          ),
          if (_msg != null) ...[const SizedBox(height: 16), Text(_msg!)],
        ],
      ),
    );
  }
}
