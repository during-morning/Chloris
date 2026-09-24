// queryTTF / replaceFont 桥接测试 —— 对齐 legado JsExtensions.kt:1016-1059：
// queryBase64TTF(base64) 返回字体句柄；replaceFont(text, err, ok[, filter])
// 按轮廓把错字体的字符映射回正确字体的 Unicode。
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

import 'font_query_test.dart' show buildTtf;

class _NoHttp implements HttpPort {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('no http in test');
}

void main() {
  // 「错误字体」：字符 甲乙丙 的轮廓被打乱（seeds 逆序）；
  // 「正确字体」：同一批字符、正常顺序。轮廓反查应把打乱的字符还原。
  final wrongFont = buildTtf('甲乙丙'.codeUnits, [3, 2, 1]);
  final rightFont = buildTtf('甲乙丙'.codeUnits, [1, 2, 3]);

  test('queryBase64TTF 返回句柄且可被 replaceFont 消费', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final errHandle = await host.queryBase64TTF(base64Encode(wrongFont));
    final okHandle = await host.queryBase64TTF(base64Encode(rightFont));
    expect(errHandle, isNotEmpty);
    expect(okHandle, isNotEmpty);
    expect(errHandle, isNot(okHandle), reason: '两个字体应有不同的句柄');

    // 用打乱字体的字符书写，经 replaceFont 还原
    final obfuscated = '甲乙丙';
    final out = await host.invoke('replaceFont', [
      obfuscated,
      errHandle,
      okHandle,
      true,
    ]);
    expect(out, isA<String>());
    final restored = out! as String;
    // 轮廓反查：每个字符都应映射回「正确字体」中同轮廓的真实字符
    expect(restored.runes.every((r) => '甲乙丙'.contains(String.fromCharCode(r))),
        isTrue,
        reason: '还原结果应仍在原字符集内：$restored');
    expect(restored, isNot(obfuscated),
        reason: '轮廓顺序不同，逐字符不应与输入完全一致：$restored');
  });

  test('replaceFont 无效句柄原样返回文本（可见降级而非崩溃）', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final out = await host.invoke('replaceFont', [
      '正常文本',
      '@font:404@',
      '@font:405@',
      true,
    ]);
    expect(out, '正常文本');
  });

  test('queryBase64TTF 非法数据不产生坏句柄（可见错误或空句柄）', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    Object? outcome;
    try {
      final handle = await host.queryBase64TTF('definitely-not-a-font');
      outcome = handle;
    } catch (e) {
      outcome = e; // 可见错误也是合法行为（file_port 不支持/数据不可读）
    }
    // 断言：要么是合法句柄，要么是显式抛错——绝不能拿到一个静默坏句柄。
    expect(
      outcome is String && (outcome == '' || outcome.startsWith('ttf')) ||
          outcome is Exception,
      isTrue,
    );
  });
}
