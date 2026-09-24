import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/services/file_scan_service.dart';

void main() {
  test('扫描目录返回 txt/epub 文件', () async {
    final dir = await Directory.systemTemp.createTemp('chloris_scan');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/a.txt').writeAsString('x');
    await File('${dir.path}/sub/b.epub').create(recursive: true);
    await File('${dir.path}/c.jpg').writeAsString('y');
    final found = await const FileScanService().scanDirectory(dir.path);
    expect(found.length, 2);
    expect(found.any((f) => f.path.endsWith('.txt')), isTrue);
    expect(found.any((f) => f.path.endsWith('.epub')), isTrue);
  });
}
