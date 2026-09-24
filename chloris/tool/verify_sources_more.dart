// dart run tool/verify_sources_more.dart
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

const queries = ['我', '的', '一'];
const timeout = Duration(seconds: 30);
const concurrency = 24;

bool usable(SearchBook b) {
  final name = b.name.trim();
  final url = b.bookUrl.trim();
  if (name.length < 2 || url.length < 8) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  if (uri.path.isEmpty || uri.path == '/') return false;
  if (name.contains('验证码') || name.contains('登录')) return false;
  return true;
}

Future<void> main() async {
  EngineLimits.apply(httpTimeoutSec: 30, searchTimeoutSec: 30);
  final allFile = File('tool/archive/default_book_sources.all.json');
  final haveFile = File('assets/sources/verified_book_sources.json');
  final all = BookSource.listFromJson(jsonDecode(await allFile.readAsString()));
  final have = BookSource.listFromJson(jsonDecode(await haveFile.readAsString()));
  final seen = {for (final s in have) s.bookSourceUrl};
  final candidates = all.where((s) {
    if (seen.contains(s.bookSourceUrl)) return false;
    if ((s.searchUrl ?? '').trim().isEmpty) return false;
    if (s.bookSourceType != 0) return false;
    return true;
  }).toList();
  stdout.writeln('extra candidates ' + candidates.length.toString());

  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
  final ok = <BookSource>[];
  var done = 0;
  var next = 0;
  final log = File('/tmp/verify_sources_more.log').openWrite();

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= candidates.length) return;
      final s = candidates[i];
      var hit = false;
      var elapsed = 0;
      var n = 0;
      for (final q in queries) {
        final sw = Stopwatch()..start();
        try {
          final books = await web.searchBook(s, q).timeout(timeout);
          final good = books.where(usable).toList();
          elapsed = sw.elapsedMilliseconds;
          if (good.isNotEmpty && elapsed <= 30000) {
            hit = true;
            n = good.length;
            break;
          }
        } catch (_) {}
      }
      done++;
      if (hit) {
        s.enabled = true;
        s.bookSourceGroup = 'Chloris有效';
        s.respondTime = elapsed;
        s.weight = 70;
        ok.add(s);
        log.writeln('OK ' + elapsed.toString() + 'ms n=' + n.toString() + ' ' + s.bookSourceName);
      }
      if (done % 25 == 0 || done == candidates.length) {
        stdout.writeln(
          'progress ' +
              done.toString() +
              '/' +
              candidates.length.toString() +
              ' ok=' +
              ok.length.toString(),
        );
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
  await log.flush();
  await log.close();

  final merged = [...have, ...ok];
  merged.sort((a, b) {
    final w = b.weight.compareTo(a.weight);
    if (w != 0) return w;
    return a.respondTime.compareTo(b.respondTime);
  });
  for (var i = 0; i < merged.length; i++) {
    merged[i].customOrder = i;
  }
  final jsonOut = const JsonEncoder.withIndent('  ')
      .convert(merged.map((s) => s.toJson()).toList());
  await File('assets/sources/verified_book_sources.json').writeAsString(jsonOut);
  await File('assets/sources/default_book_sources.json').writeAsString(jsonOut);
  stdout.writeln('merged n=' + merged.length.toString() + ' extra=' + ok.length.toString());
}
