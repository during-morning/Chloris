// dart run tool/curate_sources.dart [--merge-only]
// 从 reference/开源阅读 原书源重新合并分区，再用「我」「你」「的」+ 名著 + 深度选优。
// 禁止把上一轮 default_book_sources.all.json 当输入。
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/sources/source_unify.dart';

const probeWords = ['的', '我', '你'];
const novelQueries = ['斗破苍穹', '凡人修仙传', '诡秘之主'];
const comicQueries = ['一人之下', '海贼', '斗罗'];
const timeout = Duration(seconds: 12);
const depthTimeout = Duration(seconds: 18);
const concurrency = 28;
const perHost = 6;

const originFiles = <(String, int)>[
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【最推荐】超级精选书源（强烈推荐！）最强.json', 40),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/data.json', 25),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】轻小说书源@小霖子.json', 20),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/国内小说网文整合@小霖子.json', 15),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】漫画书源@小霖子.json', 12),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】总书源@小霖子.json', 8),
];

bool usable(SearchBook book) {
  final name = book.name.trim();
  final url = book.bookUrl.trim();
  if (name.length < 2 || url.length < 8) return false;
  if (isChromeBookName(name) || isChromeBookUrl(url)) return false;
  if (name.contains('验证码') ||
      name.contains('登录') ||
      name.contains('Cloudflare') ||
      name.contains('海词') ||
      name.contains('词典')) {
    return false;
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  if (uri.path.isEmpty || uri.path == '/') return false;
  return true;
}

int matchScore(SearchBook book, String query) {
  final n = book.name.replaceAll(RegExp(r'\s+'), '');
  final a = book.author.replaceAll(RegExp(r'\s+'), '');
  final k = query.replaceAll(RegExp(r'\s+'), '');
  if (k.isEmpty) return 0;
  if (n == k) return 1000;
  if (n.contains(k) || k.contains(n) && n.length >= 2) return 700;
  if (a.contains(k)) return 300;
  return 0;
}

bool isComic(BookSource s) =>
    s.bookSourceType == BookSourceType.image ||
    (s.bookSourceGroup ?? '').contains('漫画');

List<String> stage2Queries(BookSource s) =>
    isComic(s) ? comicQueries : novelQueries;

Future<List<(BookSource, int)>> loadOrigins() async {
  final ranked = <(BookSource, int)>[];
  for (final (path, preferred) in originFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      stdout.writeln('skip missing $path');
      continue;
    }
    final decoded = jsonDecode(await file.readAsString());
    final list = BookSource.listFromJson(decoded);
    stdout.writeln(
      'load ${file.uri.pathSegments.last} n=${list.length} p=$preferred',
    );
    for (final s in list) {
      ranked.add((s, preferred));
    }
  }
  return ranked;
}

String _jsonOf(List<BookSource> list) => const JsonEncoder.withIndent('  ')
    .convert(list.map((s) => s.toJson()).toList());

Future<void> writeAssets(List<BookSource> all, List<BookSource> enabled) async {
  final allOut = File('tool/archive/default_book_sources.all.json');
  final defOut = File('assets/sources/default_book_sources.json');
  final verOut = File('assets/sources/verified_book_sources.json');
  for (final s in all) {
    s.enabled = false;
  }
  await allOut.writeAsString(_jsonOf(all));
  for (final s in enabled) {
    s.enabled = true;
  }
  await defOut.writeAsString(_jsonOf(enabled));
  await verOut.writeAsString(_jsonOf(enabled));
}

Future<void> main(List<String> args) async {
  final mergeOnly = args.contains('--merge-only');
  EngineLimits.apply(
    httpTimeoutSec: 10,
    searchTimeoutSec: 12,
    searchPool: 28,
    searchHostCap: 0,
    searchEarlyStopHits: 0,
    debugVerbose: false,
  );

  final merged = mergeBookSources(await loadOrigins());
  stdout.writeln(
    'merged unique=${merged.length} searchable=${merged.where((s) => s.hasSearch).length}',
  );
  final staticPick = applyGroupQuotas(
    pickBestPerHost(
      merged
          .where((s) => s.hasCompleteRules && isHttpSearch(s))
          .toList(),
      perHost: perHost,
    ),
  );
  if (mergeOnly) {
    for (final s in merged) {
      s.enabled = false;
    }
    await File('tool/archive/default_book_sources.all.json')
        .writeAsString(_jsonOf(merged));
    stdout.writeln('merge-only wrote all=${merged.length}');
    return;
  }
  await writeAssets(merged, staticPick);
  stdout.writeln(
    'static enabled=${staticPick.length} (complete HTTP rules, pre-probe)',
  );

  final logDir = Directory('tool/logs')..createSync(recursive: true);
  final log = File('${logDir.path}/curate_sources.log').openWrite();
  final report = StringBuffer()
    ..writeln('# curate report')
    ..writeln()
    ..writeln('merged=${merged.length}');

  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
  final candidates = merged.where((s) => s.hasSearch).toList();

  final s1 = <BookSource>[];
  var done = 0;
  var next = 0;

  Future<List<SearchBook>> search(BookSource source, String q) {
    return web.searchBook(source, q).timeout(timeout);
  }

  Future<void> s1Worker() async {
    while (true) {
      final i = next++;
      if (i >= candidates.length) return;
      final source = candidates[i];
      var hitCount = 0;
      var elapsed = 0;
      var word = '';
      for (final q in probeWords) {
        final sw = Stopwatch()..start();
        try {
          final books = await search(source, q);
          elapsed = sw.elapsedMilliseconds;
          final good = books.where(usable).toList();
          if (good.isNotEmpty) {
            hitCount = good.length;
            word = q;
            break;
          }
        } catch (_) {
          elapsed = sw.elapsedMilliseconds;
        }
      }
      done++;
      source.respondTime = elapsed <= 0 ? 180000 : elapsed;
      if (hitCount > 0) {
        source.weight = 40 +
            (source.hasCompleteRules ? 30 : 0) +
            (isHttpSearch(source) ? 15 : 0) +
            (hitCount > 20 ? 20 : hitCount);
        if (elapsed > 8000) source.weight -= 10;
        s1.add(source);
        log.writeln(
          'S1 OK ${elapsed}ms n=$hitCount q=$word [${source.bookSourceGroup}] ${source.bookSourceName}',
        );
      } else {
        log.writeln('S1 FAIL [${source.bookSourceGroup}] ${source.bookSourceName}');
      }
      if (done % 40 == 0 || done == candidates.length) {
        stdout.writeln('S1 $done/${candidates.length} alive=${s1.length}');
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => s1Worker()));
  report.writeln('S1 alive=${s1.length}/${candidates.length}');

  final s2 = <BookSource>[];
  done = 0;
  next = 0;
  Future<void> s2Worker() async {
    while (true) {
      final i = next++;
      if (i >= s1.length) return;
      final source = s1[i];
      var ok = false;
      var elapsed = 0;
      var word = '';
      var rel = 0;
      for (final q in stage2Queries(source)) {
        final sw = Stopwatch()..start();
        try {
          final books = (await search(source, q)).where(usable).toList();
          elapsed = sw.elapsedMilliseconds;
          rel = books.where((b) => matchScore(b, q) >= 300).length;
          if (rel > 0) {
            ok = true;
            word = q;
            break;
          }
        } catch (_) {
          elapsed = sw.elapsedMilliseconds;
        }
      }
      done++;
      if (ok) {
        source.weight += 20 + (rel.clamp(0, 20));
        if (elapsed > 0 && elapsed < source.respondTime) {
          source.respondTime = elapsed;
        }
        s2.add(source);
        log.writeln(
          'S2 OK ${elapsed}ms rel=$rel q=$word ${source.bookSourceName}',
        );
      } else {
        log.writeln('S2 FAIL ${source.bookSourceName}');
      }
      if (done % 20 == 0 || done == s1.length) {
        stdout.writeln('S2 $done/${s1.length} related=${s2.length}');
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => s2Worker()));
  report.writeln('S2 related=${s2.length}/${s1.length}');

  var depthPool = List<BookSource>.from(s2);
  if (depthPool.length < 80) {
    final extra = List<BookSource>.from(s1)
      ..sort((a, b) => b.weight.compareTo(a.weight));
    for (final s in extra) {
      if (depthPool.length >= 160) break;
      if (!depthPool.contains(s) && s.hasCompleteRules && isHttpSearch(s)) {
        depthPool.add(s);
      }
    }
  }

  final s3 = <BookSource>[];
  done = 0;
  next = 0;
  Future<void> s3Worker() async {
    while (true) {
      final i = next++;
      if (i >= depthPool.length) return;
      final source = depthPool[i];
      var pass = false;
      var infoName = '';
      var nCh = 0;
      var nContent = 0;
      try {
        final q = stage2Queries(source).first;
        final books = (await search(source, q)).where(usable).toList();
        SearchBook? hit;
        for (final b in books) {
          if (matchScore(b, q) >= 300) {
            hit = b;
            break;
          }
        }
        hit ??= books.isEmpty ? null : books.first;
        if (hit != null) {
          final book = await web
              .getBookInfo(source, hit.toBook())
              .timeout(depthTimeout);
          infoName = book.name;
          final chapters = await web
              .getChapterList(source, book, maxPages: 8)
              .timeout(depthTimeout);
          nCh = chapters.length;
          final urls = <String>{
            for (final c in chapters)
              if (c.url.isNotEmpty) c.url,
          };
          if (infoName.trim().isNotEmpty && nCh >= 5 && urls.length >= 5) {
            final sample = chapters[chapters.length > 2 ? 1 : 0];
            final text = await web
                .getContent(source, book, sample)
                .timeout(depthTimeout);
            final plain = text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            nContent = plain.length;
            if (nContent >= 80 &&
                !plain.contains('验证码') &&
                !plain.contains('登录')) {
              pass = true;
              source.weight += 25;
            }
          }
        }
      } catch (_) {}
      done++;
      if (pass) {
        s3.add(source);
        log.writeln(
          'S3 OK ch=$nCh body=$nContent $infoName ${source.bookSourceName}',
        );
      } else {
        log.writeln('S3 FAIL ch=$nCh body=$nContent ${source.bookSourceName}');
      }
      if (done % 10 == 0 || done == depthPool.length) {
        stdout.writeln('S3 $done/${depthPool.length} deep=${s3.length}');
      }
    }
  }

  await Future.wait(List.generate(16, (_) => s3Worker()));
  report.writeln('S3 deep=${s3.length}/${depthPool.length}');

  final pickedSet = <String, BookSource>{
    for (final s in s3) s.bookSourceUrl: s,
  };
  if (pickedSet.length < 80) {
    final fill = [...s2, ...s1]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    for (final s in fill) {
      if (pickedSet.length >= 160) break;
      if (!s.hasCompleteRules || !isHttpSearch(s)) continue;
      pickedSet.putIfAbsent(s.bookSourceUrl, () => s);
    }
  }

  final hostPicked = pickBestPerHost(pickedSet.values.toList(), perHost: perHost);
  final enabled = applyGroupQuotas(hostPicked);
  for (final s in merged) {
    final hit = enabled.where((e) => e.bookSourceUrl == s.bookSourceUrl);
    if (hit.isEmpty) {
      s.enabled = false;
    } else {
      s.enabled = true;
      s.weight = hit.first.weight;
      s.respondTime = hit.first.respondTime;
      s.customOrder = hit.first.customOrder;
      s.bookSourceGroup = hit.first.bookSourceGroup;
    }
  }

  await writeAssets(merged, enabled);
  final counts = <String, int>{};
  for (final s in enabled) {
    counts[s.bookSourceGroup ?? '其他'] =
        (counts[s.bookSourceGroup ?? '其他'] ?? 0) + 1;
  }
  report
    ..writeln('enabled=${enabled.length}')
    ..writeln('groups $counts');
  await File('${logDir.path}/curate_report.md').writeAsString(report.toString());
  await log.flush();
  await log.close();
  stdout.writeln('picked=${enabled.length} groups $counts');
}
