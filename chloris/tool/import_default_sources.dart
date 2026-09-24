// dart run tool/import_default_sources.dart <legado.json>
import 'dart:convert';
import 'dart:io';

import 'package:chloris/features/sources/source_unify.dart';
import 'package:chloris_engine/chloris_engine.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/import_default_sources.dart <file.json>');
    exit(64);
  }
  final decoded = jsonDecode(File(args.first).readAsStringSync());
  if (decoded is! List) {
    stderr.writeln('expected a JSON array');
    exit(1);
  }
  final best = <String, (int, Map<String, dynamic>)>{};
  var skipped = 0;
  for (final item in decoded) {
    if (item is! Map) {
      skipped++;
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    BookSource source;
    try {
      source = BookSource.fromJson(map);
    } catch (_) {
      skipped++;
      continue;
    }
    if (source.bookSourceName.trim().isEmpty) {
      skipped++;
      continue;
    }
    final url = canonicalizeSourceUrl(source.bookSourceUrl);
    if (url.isEmpty) {
      skipped++;
      continue;
    }
    map['bookSourceUrl'] = url;
    final score = sourceQualityScore(source);
    final prev = best[url];
    if (prev == null || score >= prev.$1) {
      best[url] = (score, map);
    }
  }
  final out = best.values.map((e) => e.$2).toList();
  final json = jsonEncode(out);
  File('assets/sources/default_book_sources.json').writeAsStringSync(json);
  File('tool/archive/default_book_sources.all.json').writeAsStringSync(json);
  stdout.writeln(
    'in ${decoded.length} kept ${out.length} skipped $skipped bytes ${json.length}',
  );
}
