import 'dart:io';

/// 本地书扫描（TXT/EPUB）。IO 平台使用；Web 无文件系统访问。
class FileScanService {
  const FileScanService();

  Future<List<File>> scanDirectory(String dir) async {
    final root = Directory(dir);
    if (!await root.exists()) return const [];
    final out = <File>[];
    await for (final e in root.list(recursive: true)) {
      if (e is File) {
        final lower = e.path.toLowerCase();
        if (lower.endsWith('.txt') || lower.endsWith('.epub')) {
          out.add(e);
        }
      }
    }
    return out;
  }
}
