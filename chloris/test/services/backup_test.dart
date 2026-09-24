import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/services/backup_service.dart';
import 'package:chloris/application/rss/rss_models.dart';

void main() {
  final service = const BackupService();

  BookSource makeSource(String url, String name) =>
      BookSource(bookSourceUrl: url, bookSourceName: name);

  test('备份/恢复 无加密往返', () {
    final bytes = service.createBackup(
      sources: [makeSource('https://a.com', '源A')],
      replaces: [ReplaceRule(name: 'r', pattern: 'a', replacement: 'b')],
      tocs: [TxtTocRule(name: 't', rule: r'第[一二三四五六七八九十]+章')],
    );
    expect(bytes.length, greaterThan(0));
    final restored = service.restoreBackup(bytes);
    expect(restored.sources.length, 1);
    expect(restored.sources.first.bookSourceUrl, 'https://a.com');
    expect(restored.replaces.length, 1);
    expect(restored.tocs.length, 1);
  });

  test('备份/恢复 AES 加密往返', () {
    final bytes = service.createBackup(
      sources: [makeSource('https://b.com', '源B')],
      replaces: const [],
      tocs: const [],
      password: 'secret',
    );
    final restored = service.restoreBackup(bytes, password: 'secret');
    expect(restored.sources.length, 1);
    expect(restored.sources.first.bookSourceName, '源B');
  });

  test('AesCbc 直接往返', () {
    final input = Uint8List.fromList(List.generate(37, (i) => i));
    final enc = AesCbc.encrypt(input, 'pw');
    final dec = AesCbc.decrypt(enc, 'pw');
    expect(dec, input);
  });

  test('备份/恢复包含 RSS 与词典规则', () {
    final bytes = service.createBackup(
      sources: const [],
      replaces: const [],
      tocs: const [],
      rssSources: [
        RssSource(sourceUrl: 'https://example.com/feed', sourceName: '订阅'),
      ],
      dictRules: [
        {'name': '词典', 'url': 'https://example.com/dict'},
      ],
    );
    final restored = service.restoreBackup(bytes);
    expect(restored.version, 2);
    expect(restored.rssSources.single.sourceName, '订阅');
    expect(restored.dictRules.single['name'], '词典');
  });
}
