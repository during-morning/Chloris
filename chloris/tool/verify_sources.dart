// dart run tool/verify_sources.dart
// Probe book sources: search must return usable books within 30s.
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

const query = '斗破苍穹';
const timeout = Duration(seconds: 30);
const concurrency = 24;
const waveNovelOnly = true;

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

bool relevant(SearchBook b) {
  final n = b.name.replaceAll(RegExp(r'\s+'), '');
  return n.contains('斗破') || n.contains('苍穹') || (b.author).contains('蚕');
}

Future<void> main() async {
  EngineLimits.apply(httpTimeoutSec: 30, searchTimeoutSec: 30);
  final file = File('assets/sources/default_book_sources.json');
  final list = BookSource.listFromJson(jsonDecode(await file.readAsString()));
  var candidates = list.where((s) {
    final u = (s.searchUrl ?? '').trim();
    if (u.isEmpty) return false;
    if (waveNovelOnly && s.bookSourceType != 0) return false;
    return true;
  }).toList();
  stdout.writeln('candidates ' + candidates.length.toString());

  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
  final ok = <BookSource>[];
  final fail = <String>[];
  var done = 0;
  var next = 0;
  final log = File('/tmp/verify_sources.log').openWrite();

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= candidates.length) return;
      final s = candidates[i];
      final sw = Stopwatch()..start();
      try {
        final books = await web
            .searchBook(s, query)
            .timeout(timeout);
        final good = books.where(usable).toList();
        final hit = good.where(relevant).toList();
        final elapsed = sw.elapsedMilliseconds;
        done++;
        if (good.isEmpty || elapsed > 30000) {
          fail.add(s.bookSourceUrl);
          log.writeln('FAIL ' + elapsed.toString() + 'ms ' + s.bookSourceName);
        } else {
          s.enabled = true;
          s.bookSourceGroup = 'Chloris有效';
          s.respondTime = elapsed;
          s.weight = hit.isNotEmpty ? 100 : 60;
          ok.add(s);
          log.writeln(
            'OK ' +
                elapsed.toString() +
                'ms n=' +
                good.length.toString() +
                ' rel=' +
                hit.length.toString() +
                ' ' +
                s.bookSourceName,
          );
        }
      } catch (e) {
        done++;
        fail.add(s.bookSourceUrl);
        log.writeln('ERR ' + s.bookSourceName + ' ' + e.toString().split('\n').first);
      }
      if (done % 25 == 0 || done == candidates.length) {
        stdout.writeln(
          'progress ' +
              done.toString() +
              '/' +
              candidates.length.toString() +
              ' ok=' +
              ok.length.toString() +
              ' fail=' +
              fail.length.toString(),
        );
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
  await log.flush();
  await log.close();

  ok.sort((a, b) {
    final rel = b.weight.compareTo(a.weight);
    if (rel != 0) return rel;
    return a.respondTime.compareTo(b.respondTime);
  });
  for (var i = 0; i < ok.length; i++) {
    ok[i].customOrder = i;
  }
  final out = File('assets/sources/verified_book_sources.json');
  await out.writeAsString(
    const JsonEncoder.withIndent('  ').convert(ok.map((s) => s.toJson()).toList()),
  );
  stdout.writeln('wrote ' + out.path + ' n=' + ok.length.toString());
}
