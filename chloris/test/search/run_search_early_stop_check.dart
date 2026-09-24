// 独立实跑脚本：不依赖 flutter / engine，直接用 dart 运行验证早停判定逻辑。
// 运行：
//   ../../reference/flutter-sdk/flutter/bin/dart run test/search/run_search_early_stop_check.dart
//
// ignore_for_file: avoid_print
import 'package:chloris/core/search/search_early_stop.dart';

void main() {
  print('=== searchShouldEarlyStop 实跑验证 ===\n');

  const threshold = 8;

  // 场景 1：mergedHits 从 0 递增，命中数阈值 = 8（默认）。
  print('场景1：earlyStopHits=$threshold，mergedHits 递增');
  print('  mergedHits | stoppedEarly');
  for (var h = 0; h <= 12; h++) {
    final stopped = searchShouldEarlyStop(
      mergedHits: h,
      earlyStopHits: threshold,
    );
    print('  ${h.toString().padLeft(10)} | $stopped');
  }

  // 场景 2：阈值 <= 0 关闭早停。
  print('\n场景2：earlyStopHits=0（关闭）');
  for (var h = 0; h <= 12; h++) {
    final stopped = searchShouldEarlyStop(mergedHits: h, earlyStopHits: 0);
    assert(!stopped, '阈值关闭时永远不应早停');
  }
  print('  mergedHits 0..12 全部 stoppedEarly=false（已断言）');

  // 场景 3：阈值较大，命中数较小不触发。
  print('\n场景3：earlyStopHits=24，mergedHits=12 不应早停');
  final s3 = searchShouldEarlyStop(mergedHits: 12, earlyStopHits: 24);
  print('  stoppedEarly=$s3');
  assert(!s3, '命中不足阈值不应早停');

  // 场景 4：模拟一次真实 fanout 累加——每源返回 1 本书，到阈值即停。
  print('\n场景4：模拟 fanout 累加（每源 1 书，阈值=$threshold）');
  var merged = 0;
  var launched = 0;
  const totalSources = 40;
  for (var i = 0; i < totalSources; i++) {
    if (searchShouldEarlyStop(mergedHits: merged, earlyStopHits: threshold)) {
      break; // 不再发起新源
    }
    launched++;
    merged += 1; // 该源返回 1 本书
  }
  print('  已发起源数=$launched / 总源数=$totalSources');
  print('  停止时 mergedHits=$merged');
  assert(launched == threshold, '应在第 $threshold 个源后停止');
  assert(merged == threshold, '停止时命中数应等于阈值');

  print('\n全部断言通过 ✔');
}
