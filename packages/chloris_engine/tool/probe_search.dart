import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

/// Live probe: search a few default sources and print hit/error counts.
Future<void> main(List<String> args) async {
  final query = args.isNotEmpty ? args.first : '三国演义';
  final raw = File(
    '../../chloris/assets/sources/default_book_sources.json',
  ).readAsStringSync();
  final sources = BookSource.listFromJson(jsonDecode(raw) as List);
  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
  final simple = sources.where((s) {
    final url = (s.searchUrl ?? '').toLowerCase();
    return s.enabled &&
        url.startsWith('http') &&
        !url.contains('<js>') &&
        !url.contains('@js:');
  }).take(8);
  var hits = 0;
  var errors = 0;
  for (final source in simple) {
    final sw = Stopwatch()..start();
    try {
      final books = await web
          .searchBook(source, query)
          .timeout(const Duration(seconds: 12));
      final names = books.take(3).map((b) => b.name).join(' / ');
      stdout.writeln(
        'OK  ${source.bookSourceName.padRight(16)} ${books.length}  ${sw.elapsedMilliseconds}ms  $names',
      );
      if (books.isNotEmpty) hits++;
    } catch (e) {
      errors++;
      stdout.writeln(
        'ERR ${source.bookSourceName.padRight(16)} ${sw.elapsedMilliseconds}ms  $e',
      );
    }
  }
  stdout.writeln('hits=$hits errors=$errors query=$query');
  http.cancelInFlight();
}
