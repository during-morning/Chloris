import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'source_library_provider.dart';
import 'source_validator.dart';

Future<void> importSourcesFromFile(WidgetRef ref) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final bytes = result.files.single.bytes;
  if (bytes == null) return;
  final decoded = jsonDecode(utf8.decode(bytes));
  final list = BookSource.listFromJson(decoded);
  if (list.isEmpty) return;
  ref.read(importedSourcesProvider.notifier).addAll(list);
}

Future<void> importSourcesFromClipboard(
  BuildContext context,
  WidgetRef ref,
) async {
  final data = await Clipboard.getData('text/plain');
  final raw = data?.text;
  if (raw == null || raw.trim().isEmpty) return;
  try {
    final list = BookSource.listFromJson(jsonDecode(raw));
    if (list.isEmpty) return;
    ref.read(importedSourcesProvider.notifier).addAll(list);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已从剪贴板导入 ' + list.length.toString() + ' 条')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：' + e.toString())));
    }
  }
}

Future<void> importSourcesFromUrl(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController();
  final url = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('从 URL 导入书源'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(hintText: 'https://...json'),
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
    final res = await ref
        .read(httpPortProvider)
        .send(HttpRequestSpec(url: url));
    final body = res.body ?? '';
    final list = BookSource.listFromJson(jsonDecode(body));
    if (list.isEmpty) throw StateError('没有解析到书源');
    ref.read(importedSourcesProvider.notifier).addAll(list);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ' + list.length.toString() + ' 条')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：' + e.toString())));
    }
  }
}

Future<void> validateShownSources(
  BuildContext context,
  WidgetRef ref,
  List<BookSource> sources,
) async {
  final report = await BulkSourceValidator(
    http: ref.read(httpPortProvider),
    searchProbe: (source, keyword) =>
        ref.read(searchOnlineBooksUseCaseProvider)(source, keyword),
  ).validate(sources);
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('批量校验结果'),
      content: Text(
        '已校验 ' +
            report.results.length.toString() +
            ' 条，健康 ' +
            report.healthyCount.toString() +
            ' 条，平均质量分 ' +
            report.averageQuality.toStringAsFixed(1),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
