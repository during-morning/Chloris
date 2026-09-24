import 'dart:async';
import 'dart:isolate';

import '../models/domain_protocol.dart';

/// 小文本阈值（32KB，按 UTF-16 code unit 计，约等于字节数）。
///
/// 小文本同步替换既快又不可能卡住主线程；为它开一个短命 isolate 的
/// 启动开销（spawn + 消息往返）反而得不偿失。只有超过此阈值的「大文本」
/// 才有必要丢进 isolate，用看门狗硬杀潜在的灾难性回溯。
const int regexWatchdogSmallThreshold = 32 * 1024;

/// 同步执行单次替换，不进 isolate。
///
/// - [isRegex] 为 false：走字面 [String.replaceAll]；
/// - [isRegex] 为 true：编译 [RegExp] 后 [String.replaceAll]。
///
/// 非法 pattern（[RegExp] 构造抛 [FormatException]）或非法 replacement
/// （分组引用语法错误抛 [FormatException]/[ArgumentError]）会原样上抛，
/// 由 [replaceWithWatchdog] 转成 [DomainError]。
String _replaceSync({
  required String input,
  required String pattern,
  required String replacement,
  required bool isRegex,
}) {
  if (!isRegex) {
    return input.replaceAll(pattern, replacement);
  }
  final re = RegExp(pattern, multiLine: true);
  return input.replaceAll(re, replacement);
}

/// 看门狗 worker：只能在独立 isolate 内跑，故必须是顶层函数、且只通过
/// 消息传递拿入参（[SendPort] + 可序列化的基本类型）。
void _watchdogWorker(List<dynamic> message) {
  final sendPort = message[0] as SendPort;
  final input = message[1] as String;
  final pattern = message[2] as String;
  final replacement = message[3] as String;
  final isRegex = message[4] as bool;
  try {
    final out = _replaceSync(
      input: input,
      pattern: pattern,
      replacement: replacement,
      isRegex: isRegex,
    );
    sendPort.send(<String>['__ok__', out]);
  } catch (e, st) {
    sendPort.send(<String>['__err__', e.toString(), st.toString()]);
  }
}

String _ruleLabel(String? ruleName) =>
    ruleName != null && ruleName.isNotEmpty ? '「$ruleName」' : '';

/// 带执行看门狗的替换，语义对齐 legado 的 [ReplaceRule] 超时机制
/// （`ReplaceRule.timeoutMillisecond` 默认 3000ms，超时抛
/// `RegexTimeoutException` 且 rule 被禁用）。
///
/// 行为：
/// 1. 输入长度 ≤ [regexWatchdogSmallThreshold]：**直接同步执行**（小文本
///    卡不住主线程，也不值得开 isolate）。
/// 2. 输入长度 > 阈值：把同步替换丢进短命 isolate，挂一个 [Timer] 硬杀
///    （`isolate.kill(priority: Isolate.immediate)`）——Dart 的同步 [RegExp]
///    无法被中断，但纯计算可跨 isolate。超时抛
///    [DomainError](code: `'regex_timeout'`, recoverable: true)。
/// 3. pattern 非法 / replacement 异常：抛
///    [DomainError](code: `'regex_invalid'`)。
///
/// [ruleName] 仅用于报错信息，便于定位是哪条规则超时/异常。
Future<String> replaceWithWatchdog({
  required String input,
  required String pattern,
  required String replacement,
  required Duration timeout,
  bool isRegex = true,
  String? ruleName,
}) async {
  // 1) 小文本：同步执行，开销 < 风险。
  if (input.length <= regexWatchdogSmallThreshold) {
    try {
      return _replaceSync(
        input: input,
        pattern: pattern,
        replacement: replacement,
        isRegex: isRegex,
      );
    } on FormatException catch (e) {
      throw DomainError(
        code: 'regex_invalid',
        stage: DomainErrorStage.content,
        message: '替换规则${_ruleLabel(ruleName)}正则表达式非法：${e.message}',
        cause: e,
      );
    } on ArgumentError catch (e) {
      throw DomainError(
        code: 'regex_invalid',
        stage: DomainErrorStage.content,
        message: '替换规则${_ruleLabel(ruleName)}替换表达式非法：$e',
        cause: e,
      );
    }
  }

  // 2) 大文本：丢进短命 isolate + 看门狗硬杀。
  final port = ReceivePort();
  late final Isolate isolate;
  final completer = Completer<String>();
  // settled 防止超时 kill 之后迟到的结果消息二次完成 completer。
  var settled = false;

  final sub = port.listen((msg) {
    if (settled) return;
    if (msg is List && msg.isNotEmpty && msg[0] == '__ok__') {
      settled = true;
      completer.complete(msg.length > 1 ? msg[1] as String : '');
    } else if (msg is List && msg.isNotEmpty && msg[0] == '__err__') {
      settled = true;
      completer.completeError(DomainError(
        code: 'regex_invalid',
        stage: DomainErrorStage.content,
        message:
            '替换规则${_ruleLabel(ruleName)}执行异常：${msg.length > 1 ? msg[1] : msg}',
      ));
    }
  });

  isolate = await Isolate.spawn(
    _watchdogWorker,
    <dynamic>[port.sendPort, input, pattern, replacement, isRegex],
  );

  final timer = Timer(timeout, () {
    if (settled) return;
    settled = true;
    // 硬杀失控 isolate——这是「看门狗」的核心：纯计算无法被中断，只能跨
    // isolate 用 kill 终结。Isolate.run + .timeout 杀不掉底层 isolate，
    // 会让进程挂死，所以这里用 spawn + kill。
    isolate.kill(priority: Isolate.immediate);
    completer.completeError(DomainError(
      code: 'regex_timeout',
      stage: DomainErrorStage.content,
      message: '替换规则${_ruleLabel(ruleName)}执行超时已中止',
      recoverable: true,
    ));
  });

  try {
    return await completer.future;
  } finally {
    timer.cancel();
    sub.cancel();
    port.close();
  }
}
