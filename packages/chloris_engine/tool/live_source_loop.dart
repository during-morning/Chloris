// 真机书源闭环验证：搜索 → 详情 → 目录 → 正文 → 换章 → 换源。
//
// 这是差异文档 §5「怎么算做完」的第 3 条，也是长期没做过的一条。
// 语料用 chloris/assets/sources/verified_book_sources.json（756 个已验证书源）。
//
// 用法（在 packages/chloris_engine 下）：
//   dart run tool/live_source_loop.dart --limit 40 --query 三国演义
//   dart run tool/live_source_loop.dart --limit 200 --concurrency 8
//
// 三条设计取舍，都是为了不把结论跑歪：
//
// 1. **失败必须归因**。第一版把「代理 502 / TLS 握手失败」也算成引擎失败，结果
//    通过率被环境噪声吃掉。现在分三类：`env`（网络/代理/超时，与引擎无关）、
//    `engine`（引擎内部错误或规则求值失败）、`source`（站点返回垃圾页/规则已失效，
//    在没跑 Legado 对照前无法与引擎缺口区分）。报告按类分开统计。
// 2. **注入 `NoJsRuntime` 而不是宽松解释器**。`chloris_engine` 包内没有 JS 虚拟机
//    （真机实现由 App 注入）。宁可让依赖 JS 的源**明确失败**，也不要宽松解释器
//    「猜中」出一个看着合理的结果，那会把真实缺口掩盖掉。含 JS 的源单独分组，不入通过率。
// 3. **搜索取首个「像这本书」的结果**，而不是盲取 `books.first`。实测里有源会把站点
//    导航页（如「阅读记录」）排在第一，盲取会让正文阶段必然空，看起来像引擎坏了。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

const _stages = ['search', 'detail', 'toc', 'content', 'nextChapter', 'changeSource'];
const _coreStages = ['search', 'detail', 'toc', 'content', 'nextChapter'];

/// 失败归因。顺序敏感：先判环境，再判能力，再判站点，最后才落到引擎。
///
/// `js` 单独一类而不是并进 `env`：它同样是「本环境缺能力」，但**源本身是网络可达
/// 的**，所以统计闭环率时必须能把「站点连不上」和「缺 JS 虚拟机」分开 —— 否则
/// 会出现「因为没装 JS 引擎所以引擎不行」的错误结论。
enum FailKind {
  none,
  env,
  js,
  source,
  engine;

  String get label => switch (this) {
    FailKind.none => '—',
    FailKind.env => 'env',
    FailKind.js => 'js',
    FailKind.source => 'source',
    FailKind.engine => 'engine',
  };

  /// 网络是否可达。`js` 与 `source` 说明请求成功了，只是没拿到想要的东西。
  bool get reachable => this != FailKind.env && this != FailKind.none;
}

class StageResult {
  StageResult(this.stage, {this.ok = false, this.detail = '', this.ms = 0});

  final String stage;
  bool ok;
  String detail;
  int ms;
  FailKind kind = FailKind.none;

  Map<String, Object?> toJson() => {
    'stage': stage,
    'ok': ok,
    'kind': kind.label,
    'detail': detail,
    'ms': ms,
  };
}

class SourceOutcome {
  SourceOutcome(this.name, this.url, {required this.usesJs});

  final String name;
  final String url;
  final bool usesJs;
  final List<StageResult> stages = [];
  String? failureReason;
  FailKind failureKind = FailKind.none;
  String? bookName;
  int firstChapterChars = 0;
  String? changedSourceName;
  int changedSourceChars = 0;

  bool get searchOk => stages.any((s) => s.stage == 'search' && s.ok);

  /// 闭环 = 核心五阶段全过（换源是额外能力，单独统计）。
  bool get coreLoopOk =>
      _coreStages.every((name) => stages.any((s) => s.stage == name && s.ok));

  bool get changeSourceOk => stages.any((s) => s.stage == 'changeSource' && s.ok);

  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    'usesJs': usesJs,
    'bookName': bookName,
    'coreLoopOk': coreLoopOk,
    'firstChapterChars': firstChapterChars,
    'changeSourceOk': changeSourceOk,
    'changedSourceName': changedSourceName,
    'changedSourceChars': changedSourceChars,
    'failureReason': failureReason,
    'failureKind': failureKind.label,
    'stages': [for (final s in stages) s.toJson()],
  };
}

String _findRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/reference/开源阅读').existsSync() &&
        File('${dir.path}/packages/chloris_engine/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.absolute.path;
    dir = parent;
  }
}

bool _usesJs(Map<String, dynamic> raw) {
  final buffer = StringBuffer();
  for (final key in const [
    'searchUrl',
    'exploreUrl',
    'ruleSearch',
    'ruleBookInfo',
    'ruleToc',
    'ruleContent',
    'ruleExplore',
  ]) {
    final v = raw[key];
    if (v == null) continue;
    buffer.write(v is String ? v : jsonEncode(v));
  }
  final text = buffer.toString();
  return text.contains('<js>') ||
      text.contains('@js:') ||
      text.contains('@webjs:');
}

/// 环境层失败的特征串：请求**根本没成功**，与引擎无关。
const _envMarkers = [
  'HandshakeException',
  'SocketException',
  'Proxy failed',
  'ClientException',
  'TimeoutException',
  'Connection refused',
  'Connection reset',
  'Connection closed',
  'timed out',
  'Future not completed',
  'Bad Gateway',
  'Failed host lookup',
  'TlsException',
  'HttpException',
  // Cloudflare 源站错误码（520-527）与 5xx：服务端/链路问题，不是规则引擎问题。
  'HTTP 520',
  'HTTP 521',
  'HTTP 522',
  'HTTP 523',
  'HTTP 524',
  'HTTP 525',
  'HTTP 526',
  'HTTP 527',
  'HTTP 502',
  'HTTP 503',
  'HTTP 504',
];

/// 本环境缺能力：规则需要真正的 JS 虚拟机，而 CLI 判题环境只有 `NoJsRuntime`。
/// 严格语义把它显式报出来（而不是静默回退输入）正是期望行为。
const _jsMarkers = ['js_unsupported'];

/// 站点层失败：请求成功、但页面里没有规则想要的东西。
///
/// 注意「搜索返回空列表 / 目录为空 / 正文为空」都归这里 —— 它们是**空抽取**，不是
/// 引擎抛异常。在没跑 Legado 对照前无法与「规则已失效」区分，所以单列而不算缺陷。
const _sourceMarkers = [
  'ContentEmpty',
  '搜索返回空列表',
  '目录为空',
  '详情没有书名',
  '没有下一章',
  '目录只有分卷节点',
];

FailKind _classify(Object error) {
  final text = error.toString();
  if (_envMarkers.any(text.contains)) return FailKind.env;
  if (_jsMarkers.any(text.contains)) return FailKind.js;
  if (_sourceMarkers.any(text.contains)) return FailKind.source;
  return FailKind.engine;
}

Future<void> main(List<String> args) async {
  final limit = _intArg(args, '--limit', 30);
  final query = _strArg(args, '--query', '三国演义');
  final concurrency = _intArg(args, '--concurrency', 6);
  final sourceBudget = Duration(seconds: _intArg(args, '--source-timeout', 90));
  final changeSourceTries = _intArg(args, '--change-source-tries', 6);
  final root = _findRoot();
  final jsonOut = _strArg(
    args,
    '--json',
    '$root/artifacts/verification/20260912-rule-engine-parity/live-book-source-loop.json',
  );
  final mdOut = _strArg(
    args,
    '--md',
    '$root/artifacts/verification/20260912-rule-engine-parity/live-book-source-loop.md',
  );

  final corpus = File(
    '$root/chloris/assets/sources/verified_book_sources.json',
  );
  if (!corpus.existsSync()) {
    stderr.writeln('找不到书源语料: ${corpus.path}');
    exit(2);
  }
  final raws = (jsonDecode(corpus.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final sources = BookSource.listFromJson(raws)
      .where((s) => s.enabled && (s.searchUrl ?? '').trim().isNotEmpty)
      .toList();
  final jsByName = {
    for (final r in raws)
      (r['bookSourceName'] ?? '').toString(): _usesJs(r),
  };

  // `--only-urls <file>`：只跑文件里列出的 bookSourceUrl（每行一个）。
  // 用途：先用一轮拿到「哪些源在沙箱里网络可达」，再只看可达子集的闭环率，
  // 避免「站点连不上」把引擎的结论带偏。
  final onlyUrlsFile = _strArg(args, '--only-urls', '');
  final Set<String>? onlyUrls = onlyUrlsFile.isEmpty
      ? null
      : File(onlyUrlsFile)
            .readAsLinesSync()
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toSet();
  final eligible = onlyUrls == null
      ? sources
      : sources.where((s) => onlyUrls.contains(s.bookSourceUrl)).toList();

  final picked = eligible.take(limit).toList();
  stdout.writeln(
    '语料 ${sources.length} 个可用书源'
    '${onlyUrls == null ? '' : '，按 --only-urls 过滤后 ${eligible.length} 个'}，'
    '本轮跑前 ${picked.length} 个，'
    '关键词「$query」，并发 $concurrency，单源预算 ${sourceBudget.inSeconds}s',
  );

  final http = PackageHttpPort();
  final web = WebBook(http: http, jsRuntime: const NoJsRuntime());
  final outcomes = <SourceOutcome>[];

  Future<void> runOne(BookSource source) async {
    final outcome = SourceOutcome(
      source.bookSourceName,
      source.bookSourceUrl,
      usesJs: jsByName[source.bookSourceName] ?? false,
    );
    outcomes.add(outcome);
    var exhausted = false;
    final timer = Timer(sourceBudget, () => exhausted = true);

    Future<void> step(
      String stage,
      Future<String> Function() body, {
      bool required = true,
    }) async {
      if (exhausted) {
        outcome.stages.add(StageResult(stage, detail: '跳过（预算耗尽）'));
        if (required) {
          outcome.failureReason ??= '预算耗尽';
          outcome.failureKind = FailKind.env;
        }
        return;
      }
      final watch = Stopwatch()..start();
      final result = StageResult(stage);
      try {
        final detail = await body();
        watch.stop();
        result
          ..ok = true
          ..detail = detail
          ..ms = watch.elapsedMilliseconds;
      } catch (e) {
        watch.stop();
        final kind = _classify(e);
        result
          ..ok = false
          ..kind = kind
          ..detail = _short(e.toString())
          ..ms = watch.elapsedMilliseconds;
        if (required) {
          outcome.failureReason ??= '$stage: ${_short(e.toString())}';
          outcome.failureKind = kind;
        }
      }
      outcome.stages.add(result);
    }

    SearchBook? found;
    Book? book;
    List<BookChapter> chapters = const [];

    await step('search', () async {
      final books = await web.searchBook(source, query);
      if (books.isEmpty) throw StateError('搜索返回空列表');
      // 不盲取第一条：优先书名与关键词相交、且详情页看起来是书的条目。
      final scored = books.toList()
        ..sort((a, b) => _rank(b, query).compareTo(_rank(a, query)));
      found = scored.first;
      return '${books.length} 条，选用《${found!.name}》';
    });

    if (found != null) {
      outcome.bookName = found!.name;
      await step('detail', () async {
        book = await web.getBookInfo(source, found!.toBook());
        if (book!.name.trim().isEmpty) throw StateError('详情没有书名');
        return '《${book!.name}》 作者:${book!.author.isEmpty ? "—" : book!.author}';
      });
    }

    if (book != null) {
      await step('toc', () async {
        chapters = await web.getChapterList(source, book!);
        if (chapters.isEmpty) throw StateError('目录为空');
        return '${chapters.length} 章，首章《${chapters.first.title}》';
      });
    }

    final readable = chapters.where((c) => !c.isVolume).toList();
    if (chapters.isNotEmpty && readable.isEmpty) {
      outcome.stages.add(StageResult('content', detail: '目录只有分卷节点'));
      outcome.failureReason ??= 'content: 目录只有分卷节点';
      outcome.failureKind = FailKind.source;
    } else if (readable.isNotEmpty) {
      await step('content', () async {
        final text = await web.getContent(source, book!, readable.first);
        if (text.trim().isEmpty) throw StateError('ContentEmpty: 正文为空');
        outcome.firstChapterChars = text.length;
        return '${text.length} 字';
      });
      await step('nextChapter', () async {
        if (readable.length < 2) throw StateError('没有下一章');
        final next = readable[1];
        final text = await web.getContent(
          source,
          book!,
          next,
          nextChapterUrl: readable.length > 2 ? readable[2].url : null,
        );
        if (text.trim().isEmpty) throw StateError('ContentEmpty: 下一章正文为空');
        return '《${next.title}》 ${text.length} 字';
      });
    }

    // 换源：拿这本书的名字去别的源上取目录与正文。这是「换源」能力的最小可验证形态。
    if (outcome.coreLoopOk && found != null && changeSourceTries > 0) {
      await step('changeSource', () async {
        final wanted = found!.name;
        var tried = 0;
        // 候选来自**全量**语料而不是本轮抽样的那几十个：换源的本质就是从别的源里
        // 找同一本书，只在抽样集合里找会几乎必然落空。
        for (final other in sources) {
          if (tried >= changeSourceTries) break;
          if (other.bookSourceUrl == source.bookSourceUrl) continue;
          if ((jsByName[other.bookSourceName] ?? false)) continue;
          tried++;
          try {
            final alt = await web.searchBook(other, wanted);
            final match = alt.where(
              (b) => b.name.toLowerCase() == wanted.toLowerCase(),
            );
            if (match.isEmpty) continue;
            final altBook = await web.getBookInfo(other, match.first.toBook());
            final altChapters = await web.getChapterList(other, altBook);
            final altReadable = altChapters.where((c) => !c.isVolume).toList();
            if (altReadable.isEmpty) continue;
            final text = await web.getContent(other, altBook, altReadable.first);
            if (text.trim().isEmpty) continue;
            outcome
              ..changedSourceName = other.bookSourceName
              ..changedSourceChars = text.length;
            return '改由「${other.bookSourceName}」取得 ${text.length} 字';
          } catch (_) {
            // 候选源失败是正常的（换源就是要在多个源里挑能用的），继续试下一个。
            continue;
          }
        }
        throw StateError('ContentEmpty: $changeSourceTries 个候选源都没拿到正文');
      }, required: false);
    }

    timer.cancel();
  }

  final queue = List<BookSource>.from(picked);
  await Future.wait([
    for (var i = 0; i < concurrency; i++)
      () async {
        while (true) {
          if (queue.isEmpty) return;
          final next = queue.removeAt(0);
          try {
            await runOne(next);
          } catch (e) {
            stderr.writeln('worker error: $e');
          }
        }
      }(),
  ]);
  http.cancelInFlight();

  await _report(
    outcomes: outcomes,
    query: query,
    jsonPath: jsonOut,
    mdPath: mdOut,
  );
}

/// 给搜索结果打分：书名与关键词相交优先，作者非空次之。
int _rank(SearchBook b, String query) {
  var score = 0;
  if (b.name.contains(query) || query.contains(b.name)) score += 4;
  for (final ch in query.runes) {
    if (b.name.contains(String.fromCharCode(ch))) score += 1;
  }
  if (b.author.trim().isNotEmpty) score += 2;
  if (b.bookUrl.trim().isNotEmpty) score += 1;
  return score;
}

Future<void> _report({
  required List<SourceOutcome> outcomes,
  required String query,
  required String jsonPath,
  required String mdPath,
}) async {
  final pure = outcomes.where((o) => !o.usesJs).toList();
  final jsy = outcomes.where((o) => o.usesJs).toList();
  int okIn(List<SourceOutcome> xs, String stage) =>
      xs.where((o) => o.stages.any((s) => s.stage == stage && s.ok)).length;
  Map<String, int> kindCount(List<SourceOutcome> xs) {
    final out = <String, int>{};
    for (final o in xs) {
      if (o.coreLoopOk) continue;
      out[o.failureKind.label] = (out[o.failureKind.label] ?? 0) + 1;
    }
    return out;
  }

  final report = {
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'query': query,
    'sourceCounts': {
      'total': outcomes.length,
      'noJs': pure.length,
      'usesJs': jsy.length,
    },
    'stagePass': {
      for (final stage in _stages)
        stage: {'noJs': okIn(pure, stage), 'usesJs': okIn(jsy, stage)},
    },
    'coreLoop': {
      'noJs': pure.where((o) => o.coreLoopOk).length,
      'usesJs': jsy.where((o) => o.coreLoopOk).length,
    },
    'changeSource': {
      'noJs': pure.where((o) => o.changeSourceOk).length,
      'usesJs': jsy.where((o) => o.changeSourceOk).length,
    },
    'failureKinds': {'noJs': kindCount(pure), 'usesJs': kindCount(jsy)},
    'outcomes': [for (final o in outcomes) o.toJson()],
  };
  final jsonFile = File(jsonPath);
  await jsonFile.parent.create(recursive: true);
  await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(report));

  final envBound = pure.where((o) => !o.coreLoopOk && o.failureKind == FailKind.env);
  final jsBound = pure.where((o) => !o.coreLoopOk && o.failureKind == FailKind.js);
  final engineBound = pure.where((o) => !o.coreLoopOk && o.failureKind == FailKind.engine);
  final sourceBound = pure.where((o) => !o.coreLoopOk && o.failureKind == FailKind.source);
  // 「网络可达」= 请求成功过（因此失败原因只可能是站点或引擎），或本来就闭环了。
  final reachable = pure.where(
    (o) => o.coreLoopOk || o.failureKind != FailKind.env,
  );

  report['reachable'] = {
    'noJs': reachable.length,
    'coreLoopOk': reachable.where((o) => o.coreLoopOk).length,
  };

  final buffer = StringBuffer()
    ..writeln('# 真机书源闭环验证')
    ..writeln()
    ..writeln('- 生成时间：${report['generatedAt']}')
    ..writeln('- 关键词：`$query`，尝试 ${outcomes.length} 个书源')
    ..writeln(
      '- 分组：不含 JS 规则 ${pure.length} 个 / 含 JS 规则 ${jsy.length} 个。'
      '引擎包内没有 JS 虚拟机，含 JS 的源以 `NoJsRuntime` 跑，单独统计不入通过率。',
    )
    ..writeln()
    ..writeln('## 各阶段通过数')
    ..writeln()
    ..writeln('| 阶段 | 不含 JS (n=${pure.length}) | 含 JS (n=${jsy.length}) |')
    ..writeln('|---|---:|---:|');
  for (final stage in _stages) {
    buffer.writeln('| $stage | ${okIn(pure, stage)} | ${okIn(jsy, stage)} |');
  }
  buffer
    ..writeln()
    ..writeln(
      '**完整闭环（搜索→详情→目录→正文→换章）**：不含 JS '
      '${pure.where((o) => o.coreLoopOk).length} / ${pure.length}；含 JS '
      '${jsy.where((o) => o.coreLoopOk).length} / ${jsy.length}',
    )
    ..writeln()
    ..writeln(
      '**只看网络可达的源**（排除 `env` 类：出口代理拦断 / TLS 证书校验失败 / 超时）：'
      '不含 JS 闭环 ${reachable.where((o) => o.coreLoopOk).length} / ${reachable.length}。'
      '这一列才是引擎相关的分母 —— 沙箱的出口白名单挡住了大部分中文书站，'
      '把它们算进去会把结论带偏。',
    )
    ..writeln()
    ..writeln(
      '**换源**：不含 JS ${pure.where((o) => o.changeSourceOk).length} 个源成功改由他源取到正文。',
    )
    ..writeln()
    ..writeln('## 未闭环的归因（不含 JS 的源）')
    ..writeln()
    ..writeln('| 归因 | 数量 | 含义 |')
    ..writeln('|---|---:|---|')
    ..writeln('| env | ${envBound.length} | 出口代理/TLS/超时等网络层失败，与引擎无关 |')
    ..writeln('| js | ${jsBound.length} | 规则需要真 JS 虚拟机，本 CLI 环境没有（源本身可达） |')
    ..writeln('| source | ${sourceBound.length} | 站点返回垃圾页或规则已失效；未跑 Legado 对照前无法与引擎缺口区分 |')
    ..writeln('| engine | ${engineBound.length} | **需要查的**：引擎内部错误或规则求值异常 |')
    ..writeln();

  void table(String title, Iterable<SourceOutcome> xs) {
    final list = xs.take(40).toList();
    if (list.isEmpty) return;
    buffer
      ..writeln('### $title')
      ..writeln()
      ..writeln('| 书源 | 节点 | 断在哪一步 | 原因 |')
      ..writeln('|---|---|---|---|');
    for (final o in list) {
      final firstFail = o.stages.firstWhere(
        (s) => !s.ok && s.detail.isNotEmpty,
        orElse: () => StageResult('—', detail: '—'),
      );
      buffer.writeln(
        '| ${o.name} | ${o.url.replaceAll('https://', '').replaceAll('http://', '')} '
        '| ${firstFail.stage} | ${firstFail.detail.replaceAll('|', '/')} |',
      );
    }
    buffer.writeln();
  }

  table('引擎层失败（重点排查）', engineBound);
  table('站点层失败（可能是书源失效）', sourceBound);
  table('缺 JS 虚拟机（源本身可达，需要真机运行时）', jsBound);
  table('环境层失败（代理/TLS/超时）', envBound);

  final successes = pure.where((o) => o.coreLoopOk).toList();
  if (successes.isNotEmpty) {
    buffer
      ..writeln('### 已闭环的源')
      ..writeln()
      ..writeln('| 书源 | 选用书 | 首章字数 | 换源 |')
      ..writeln('|---|---|---:|---|');
    for (final o in successes.take(40)) {
      buffer.writeln(
        '| ${o.name} | ${o.bookName ?? '—'} | ${o.firstChapterChars} '
        '| ${o.changedSourceName ?? '—'} |',
      );
    }
    buffer.writeln();
  }

  final mdFile = File(mdPath);
  await mdFile.parent.create(recursive: true);
  await mdFile.writeAsString(buffer.toString());

  stdout
    ..writeln()
    ..writeln('── 各阶段通过数（不含JS / 含JS）')
    ..writeln('   ${_stages.map((s) => '$s=${okIn(pure, s)}/${okIn(jsy, s)}').join('  ')}')
    ..writeln(
      '   完整闭环: 不含JS ${pure.where((o) => o.coreLoopOk).length}/${pure.length}'
      '  含JS ${jsy.where((o) => o.coreLoopOk).length}/${jsy.length}',
    )
    ..writeln(
      '   只看网络可达的源（排除 env 类）: 闭环 '
      '${reachable.where((o) => o.coreLoopOk).length}/${reachable.length}',
    )
    ..writeln('   换源成功: ${pure.where((o) => o.changeSourceOk).length}')
    ..writeln(
      '   归因: engine=${engineBound.length} source=${sourceBound.length} '
      'js=${jsBound.length} env=${envBound.length}',
    )
    ..writeln('   JSON: $jsonPath')
    ..writeln('   Markdown: $mdPath');
}

String _short(String s) {
  final one = s.replaceAll('\n', ' ').trim();
  return one.length <= 120 ? one : '${one.substring(0, 120)}…';
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _strArg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return args[i + 1];
}
