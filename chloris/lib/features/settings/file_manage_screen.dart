import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/export_filename_settings.dart';
import '../../services/export_service.dart';
import '../../services/file_download.dart';
import '../../app/widgets/meow.dart';

import '../local/local_book_provider.dart';
import '../local/local_book_service.dart';
import '../local/local_import_screen.dart';

class FileManageScreen extends ConsumerStatefulWidget {
  const FileManageScreen({super.key});

  @override
  ConsumerState<FileManageScreen> createState() => _FileManageScreenState();
}

class _FileManageScreenState extends ConsumerState<FileManageScreen> {
  String _q = '';

  Future<void> _export(LocalBookBundle bundle, bool epub) async {
    final service = const ExportService();
    final hydrated = await ref
        .read(localShelfProvider.notifier)
        .loadForExport(bundle);
    final bytes = epub
        ? service.buildEpub(hydrated)
        : service.buildTxtBytes(hydrated);
    final base = service.exportBaseName(
      hydrated,
      template: await loadExportFileNameTemplate(),
    );
    await downloadBytes(
      bytes,
      '$base.${epub ? 'epub' : 'txt'}',
      epub ? 'application/epub+zip' : 'text/plain;charset=utf-8',
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 $base.${epub ? 'epub' : 'txt'}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final shelf = ref.watch(localShelfProvider);
    final q = _q.toLowerCase();
    final shown = q.isEmpty
        ? shelf
        : shelf
              .where(
                (b) =>
                    b.book.name.toLowerCase().contains(q) ||
                    b.book.originName.toLowerCase().contains(q),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('文件管理'),
        actions: [
          IconButton(
            tooltip: '导入',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocalImportScreen()),
            ),
          ),
        ],
      ),
      body: shelf.isEmpty
          ? const Center(
              child: Text('还没有本地书。点右上角导入 TXT / EPUB / PDF / MOBI / UMD。'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: MeowQueryField(
                    hint: '筛选本地书',
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final b = shown[i];
                      return ListTile(
                        title: Text(b.book.name),
                        subtitle: Text(
                          '${b.isPdf ? 'PDF · ' : (b.umdTexts != null ? 'UMD · ' : '')}${b.book.originName} · ${b.chapters.length} 章',
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            if (!b.isPdf)
                              IconButton(
                                tooltip: '导出 TXT',
                                icon: const Icon(Icons.text_snippet_outlined),
                                onPressed: b.isPdf
                                    ? null
                                    : () => _export(b, false),
                              ),
                            if (!b.isPdf)
                              IconButton(
                                tooltip: '导出 EPUB',
                                icon: const Icon(Icons.menu_book_outlined),
                                onPressed: b.isPdf
                                    ? null
                                    : () => _export(b, true),
                              ),
                            if (b.isPdf)
                              IconButton(
                                tooltip: '下载 PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                onPressed: () async {
                                  final bytes = await ref
                                      .read(localShelfProvider.notifier)
                                      .readOriginal(b);
                                  if (bytes == null) return;
                                  await downloadBytes(
                                    bytes,
                                    '${b.book.name}.pdf',
                                    'application/pdf',
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref
                                  .read(localShelfProvider.notifier)
                                  .remove(b.book.bookUrl),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocalBookChaptersPage(bundle: b),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
