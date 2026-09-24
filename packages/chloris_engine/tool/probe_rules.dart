// 书源规则诊断探针：拿一个**已保存的页面**，逐条跑规则，看每一步抽到什么。
//
// 用途：真机闭环报告里出现「搜索返回空列表 / 目录为空 / 正文为空」时，用它区分
// 三种原因 ——
//   1. 页面本身就没有目标元素（站点改版 / 站点返回垃圾页）；
//   2. 规则写法与页面结构不符（书源规则问题）；
//   3. 引擎求值错误（真缺陷）。
// 把区分做出来，才不会把站点问题记到引擎头上（或反过来）。
//
// 用法（在 packages/chloris_engine 下）：
//   # 先把页面存下来
//   curl -sL -A "Mozilla/5.0 (Linux; Android 13) Chrome/120" -o /tmp/p.html '<搜索URL>'
//   # 再逐条跑规则
//   dart run tool/probe_rules.dart /tmp/p.html '<bookList 规则>' '<name 规则>' '<bookUrl 规则>'
//
// 交互式看某条规则的命中数：
//   dart run tool/probe_rules.dart /tmp/p.html --count '<任意 CSS/@ 链规则>'
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      '用法: dart run tool/probe_rules.dart <html文件> <bookList规则> [子规则...]\n'
      '      dart run tool/probe_rules.dart <html文件> --count <规则...>',
    );
    exit(2);
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('页面文件不存在: ${file.path}');
    exit(2);
  }
  final html = file.readAsStringSync();
  final css = AnalyzeByCss(html);
  stdout.writeln('页面 ${file.path}  ${html.length} 字节');

  if (args[1] == '--count') {
    for (final rule in args.sublist(2)) {
      final els = css.getElements(rule);
      final texts = css.getStringList(rule);
      stdout.writeln(
        '$rule -> 元素 ${els.length} / 文本 ${texts.length} '
        '${texts.isNotEmpty ? texts.take(3).toList() : ''}',
      );
    }
    return;
  }

  final listRule = args[1];
  final rows = css.getElements(listRule);
  stdout.writeln('bookList: $listRule -> ${rows.length} 条');
  if (rows.isEmpty) {
    stdout.writeln('  ⚠️ 列表规则一条都没命中：先用 --count 确认页面里是否存在对应元素。');
  }
  for (final sub in args.sublist(2)) {
    final pageWide = css.getStringList(sub);
    stdout.writeln(
      '  整页 $sub -> ${pageWide.length} 条 ${pageWide.take(3).toList()}',
    );
    if (rows.isEmpty) continue;
    // 真实求值是「在每条 row 上跑子规则」，整页跑只是参考值。
    final perRow = AnalyzeByCss(rows.first).getStringList(sub);
    stdout.writeln('  首行 $sub -> $perRow');
    if (rows.length > 1) {
      final second = AnalyzeByCss(rows[1]).getStringList(sub);
      stdout.writeln('  次行 $sub -> $second');
    }
  }
}
