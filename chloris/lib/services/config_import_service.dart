import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../application/rss/rss_models.dart';

class ConfigImportResult {
  ConfigImportResult({
    this.bookSources = const [],
    this.replaceRules = const [],
    this.tocRules = const [],
    this.rssSources = const [],
    this.dictRules = const [],
  });

  final List<BookSource> bookSources;
  final List<ReplaceRule> replaceRules;
  final List<TxtTocRule> tocRules;
  final List<RssSource> rssSources;
  final List<Map<String, dynamic>> dictRules;
}

/// 解析“一键配置包”（zip：bookSource.json / replaceRule.json / txtTocRule.json / dictRule.json / rssSources.json）。
class ConfigImportService {
  const ConfigImportService();

  ConfigImportResult parse(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    T? read<T>(String name, T Function(dynamic) parse) {
      final f = archive.findFile(name);
      if (f == null) return null;
      return parse(jsonDecode(utf8.decode(f.content as List<int>)));
    }

    final bookSources =
        read('bookSource.json', BookSource.listFromJson) ?? const [];
    final replaceRules =
        read('replaceRule.json', ReplaceRule.listFromJson) ?? const [];
    final tocRules =
        read('txtTocRule.json', TxtTocRule.listFromJson) ?? const [];
    final rssSources =
        read('rssSources.json', RssSource.listFromJson) ?? const [];
    final dictRaw =
        read(
          'dictRule.json',
          (d) => (d as List).cast<Map<String, dynamic>>(),
        ) ??
        const [];
    return ConfigImportResult(
      bookSources: bookSources,
      replaceRules: replaceRules,
      tocRules: tocRules,
      rssSources: rssSources,
      dictRules: dictRaw,
    );
  }
}
