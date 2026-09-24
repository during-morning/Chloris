import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/services/config_import_service.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile(e.key, e.value.length, utf8.encode(e.value)));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  test('一键配置包解析书源/净化/目录/RSS/字典', () {
    final bytes = _zip({
      'bookSource.json': jsonEncode([{'bookSourceUrl': 'https://a.com', 'bookSourceName': 'A'}]),
      'replaceRule.json': jsonEncode([{'name': 'r', 'pattern': 'x', 'replacement': 'y'}]),
      'txtTocRule.json': jsonEncode([{'name': 't', 'rule': '第[一二三四五六七八九十]+章'}]),
      'rssSources.json': jsonEncode([{'sourceUrl': 'https://r.com', 'sourceName': 'R'}]),
      'dictRule.json': jsonEncode([{'name': 'd', 'urlRule': 'https://d.com/{{key}}'}]),
    });
    final result = const ConfigImportService().parse(bytes);
    expect(result.bookSources.length, 1);
    expect(result.replaceRules.length, 1);
    expect(result.tocRules.length, 1);
    expect(result.rssSources.length, 1);
    expect(result.dictRules.length, 1);
  });
}
