// 仿真翻页几何的独立验证脚本（不依赖 Flutter，dart run 直接跑）。
// 验证 curlForward / curlBackward 的关键不变式。
// 运行：dart run test/reader/page_curl_layout_check.dart
import 'dart:io';

import 'package:chloris/features/reader/page_curl_layout.dart';

void _expect(bool cond, String msg) {
  if (!cond) {
    stderr.writeln('FAIL: $msg');
    exit(1);
  }
  print('OK: $msg');
}

void main() {
  const w = 400.0;

  // 前翻
  final f0 = curlForward(0, w);
  _expect(f0.visibleWidth == w, '前翻 p=0：当前页完整可见');
  _expect(!f0.hasFlap, '前翻 p=0：无纸背');

  final f5 = curlForward(0.5, w);
  _expect(f5.visibleWidth == w * 0.5, '前翻 p=0.5：可见区收缩一半');
  _expect(f5.flapLeft == w * 0.5, '前翻 p=0.5：纸背从折缝开始');
  _expect(f5.flapWidth > 0 && f5.flapLeft + f5.flapWidth <= w, '前翻 p=0.5：纸背不越界');
  _expect(f5.hasShadow && f5.shadowLeft + f5.shadowWidth <= w, '前翻 p=0.5：阴影不越界');

  final f1 = curlForward(1, w);
  _expect(f1.visibleWidth == 0, '前翻 p=1：当前页完全卷起');
  _expect(f1.flapWidth == w * kCurlFlapRatio, '前翻 p=1：纸背占最大比例');
  _expect(
    f1.shadowWidth > 0 && f1.shadowLeft + f1.shadowWidth <= w,
    '前翻 p=1：纸背仍立着，阴影合法且不越界',
  );

  // 后翻
  final b0 = curlBackward(0, w);
  _expect(b0.visibleWidth == 0, '后翻 q=0：上一页不可见');
  _expect(!b0.hasFlap, '后翻 q=0：无纸背');

  final b5 = curlBackward(0.5, w);
  _expect(b5.visibleWidth == w * 0.5, '后翻 q=0.5：展开区一半');
  _expect(b5.flapWidth > 0 && b5.flapLeft + b5.flapWidth <= w, '后翻 q=0.5：纸背不越界');

  final b1 = curlBackward(1, w);
  _expect(b1.visibleWidth == w, '后翻 q=1：上一页完全铺平');
  _expect(!b1.hasFlap, '后翻 q=1：无纸背（折叠收合）');

  // 越界输入被钳制
  final fp = curlForward(1.7, w);
  _expect(fp.visibleWidth == 0, '前翻 p>1 被钳制到 1');
  final bn = curlBackward(-0.3, w);
  _expect(bn.visibleWidth == 0, '后翻 q<0 被钳制到 0');

  print('ALL CURL INVARIANTS PASS');
}
