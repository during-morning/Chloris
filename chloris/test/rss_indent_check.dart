// 纯 Dart 验收脚本：RSS 黑白名单判定 + 首行缩进可配。
// 运行：cd chloris && ../reference/flutter-sdk/flutter/bin/dart run test/rss_indent_check.dart
import 'package:chloris_engine/chloris_engine.dart';

import '../lib/application/rss/rss_use_cases.dart';

void expect(bool cond, String msg) {
  // ignore: avoid_print
  print('${cond ? "PASS" : "FAIL"}  $msg');
  if (!cond) throw StateError(msg);
}

void main() {
  // ---- RSS 黑白名单 ----
  expect(
    rssArticleAllowed('https://a.com/x.html',
        blacklist: 'https://b.com,\\.ad\\.'),
    '黑名单未命中 → 放行',
  );
  expect(
    !rssArticleAllowed('https://cdn.ad.evil/x.js',
        blacklist: 'https://b.com,\\.ad\\.'),
    '黑名单正则命中 → 拦截',
  );
  expect(
    !rssArticleAllowed('https://b.com/p/1',
        blacklist: 'https://b.com,\\.ad\\.'),
    '黑名单前缀命中 → 拦截',
  );
  expect(
    rssArticleAllowed('https://a.com/x',
        whitelist: 'https://a.com'),
    '白名单命中 → 放行',
  );
  expect(
    !rssArticleAllowed('https://other.com/x',
        whitelist: 'https://a.com'),
    '白名单未命中 → 拦截',
  );
  expect(
    !rssArticleAllowed('https://other.com/x',
        whitelist: 'https://a.com', blacklist: 'other'),
    '黑名单优先于白名单（黑名单非空时白名单失效，且命中黑名单）',
  );
  expect(
    rssArticleAllowed('https://a.com/x', blacklist: '[invalid'),
    '非法正则跳过该条目，不整体失败',
  );
  expect(rssArticleAllowed('https://a.com/x'), '黑/白名单均为空 → 全放行');

  // ---- 首行缩进可配（legado paragraphIndent）----
  final body = '第一段\n第二段';
  expect(
    ContentProcessor.resegment(body).startsWith('　　第一段'),
    '默认缩进 2 个全角空格',
  );
  expect(
    ContentProcessor.resegment(body, indent: 4).startsWith('　　　　第一段'),
    'indent=4 → 四个全角空格',
  );
  expect(
    !ContentProcessor.resegment(body, indent: 0).startsWith('　'),
    'indent=0 → 不缩进',
  );
  expect(
    ContentProcessor.resegment('　　　已有缩进', indent: 4) ==
        '　　　　已有缩进',
    '统一重缩进（trim 剥全角空格后按 indent 重补，与 legado 一致）',
  );
  // ignore: avoid_print
  print('ALL_CHECKS_PASSED');
}
