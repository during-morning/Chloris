// dart run tool/verify_sources_full.dart
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

const queries = ['我', '你', '的'];
const timeout = Duration(seconds: 30);
const concurrency = 28;

bool usable(SearchBook b) {
  final name = b.name.trim();
  final url = b.bookUrl.trim();
  if (name.length < 2 || url.length < 8) return false;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
    return false;
  }
  if (uri.host.isEmpty) return false;
  if (uri.path.isEmpty || uri.path == '/') return false;
  if (name.contains('验证码') || name.contains('登录') || name.contains('Cloudflare')) {
    return false;
  }
  return true;
}

Future<void> main() async {
  EngineLimits.apply(httpTimeoutSec: 30, searchTimeoutSec: 30);
  final origin = File('tool/archive/default_book_sources.all.json');
  final haveFile = File('assets/sources/verified_book_sources.json');
  final jsonl = File('/tmp/verify_ok.jsonl');
  final list = BookSource.listFromJson(jsonDecode(await origin.readAsString()));
  final have = haveFile.existsSync()
      ? BookSource.listFromJson(jsonDecode(await haveFile.readAsString()))
      : <BookSource>[];
  final skip = <String>{for (final s in have) s.bookSourceUrl};
  if (jsonl.existsSync()) {
    for (final line in await jsonl.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final m = jsonDecode(line);
        if (m is Map && m['bookSourceUrl'] != null) {
          skip.add(m['bookSourceUrl'].toString());
        }
      } catch (_) {}
    }
  }
  final candidates = <BookSource>[];
  final seen = <String>{};
  for (final s in list) {
    final key = s.bookSourceUrl.trim();
    if (key.isEmpty || seen.contains(key) || skip.contains(key)) continue;
    if ((s.searchUrl ?? '').trim().isEmpty) continue;
    seen.add(key);
    candidates.add(s);
  }
  stdout.writeln(
    'skip ' + skip.length.toString() + ' probe ' + candidates.length.toString(),
  );

  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
  final sink = jsonl.openWrite(mode: FileMode.append);
  var done = 0;
  var next = 0;
  var extra = 0;

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= candidates.length) return;
      final s = candidates[i];
      var bestElapsed = 0;
      var bestN = 0;
      var hit = false;
      for (final q in queries) {
        final sw = Stopwatch()..start();
        try {
          final books = await web.searchBook(s, q).timeout(timeout);
          final good = books.where(usable).toList();
          final elapsed = sw.elapsedMilliseconds;
          if (good.isNotEmpty && elapsed <= 30000) {
            hit = true;
            bestElapsed = elapsed;
            bestN = good.length;
            break;
          }
        } catch (_) {}
      }
      done++;
      if (hit) {
        s.enabled = true;
        s.bookSourceGroup = 'Chloris有效';
        s.respondTime = bestElapsed;
        s.weight = bestN >= 8 ? 100 : 80;
        extra++;
        sink.writeln(jsonEncode(s.toJson()));
      }
      if (done % 20 == 0 || done == candidates.length) {
        stdout.writeln(
          'progress ' +
              done.toString() +
              '/' +
              candidates.length.toString() +
              ' extra=' +
              extra.toString(),
        );
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
  await sink.flush();
  await sink.close();

  final fromLines = <BookSource>[];
  if (jsonl.existsSync()) {
    for (final line in await jsonl.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        final m = jsonDecode(line);
        if (m is Map) {
          final src = BookSource.fromJson(Map<String, dynamic>.from(m));
          fromLines.add(src);
        }
      } catch (_) {}
    }
  }
  final byUrl = <String, BookSource>{
    for (final s in have) s.bookSourceUrl: s,
    for (final s in fromLines) s.bookSourceUrl: s,
  };
  final ok = byUrl.values.toList();
  for (final s in ok) {
    s.enabled = true;
    s.bookSourceGroup = 'Chloris有效';
  }
  ok.sort((a, b) {
    final w = b.weight.compareTo(a.weight);
    if (w != 0) return w;
    return a.respondTime.compareTo(b.respondTime);
  });
  for (var i = 0; i < ok.length; i++) {
    ok[i].customOrder = i;
  }
  final payload = const JsonEncoder.withIndent('  ')
      .convert(ok.map((s) => s.toJson()).toList());
  await File('assets/sources/verified_book_sources.json').writeAsString(payload);
  await File('assets/sources/default_book_sources.json').writeAsString(payload);
  stdout.writeln('DONE n=' + ok.length.toString());
}
