// AnalyzeUrl `type` 选项与 Legado-E 的对齐测试。
//
// 结论（详见验收报告）：Legado-E 的 `type` 选项真实语义是「二进制下载标记」，
// 而非「显式声明 http」、也**不是** webSocket 路由。对照实现：
//   * reference/legado-E-main .../analyzeRule/AnalyzeUrl.kt:424-426
//       if (type != null) {
//         return StrResponse(url, HexUtil.encodeHexStr(getByteArrayAwait()))
//       }
//     —— 只要 `type` 非空，就把响应切换为「原始字节 → hex 字符串」，且**不去校验
//        type 的取值**，任何非空白值都触发同一行为（`UrlOption.getType()` 见
//        AnalyzeUrl.kt:865-867，setType 仅做空白→null 归一，AnalyzeUrl.kt:861-863）。
//   * 同文件 :695 `upload(...)` 把 `type` 作为 multipart 的 content-type 参数传给
//     `postMultipart` —— 那是另一条（文件上传）路径，引擎无对应 upload，与正常
//     请求的 type 语义无关。
//   * AnalyzeUrl.kt 全文件无 webSocket 路由；`type` 值中不存在 `webSocket` 这种
//     会触发 WS 传输层的值。
//
// 因此本文件锁定的行为严格遵循 Legado：
//   1. type 非空（任意取值）→ 字节通道 + hex 返回，不发起字符串请求（send）。
//   2. type 取值无关：binary/text/image/webSocket 等输出完全一致。
//   3. type 为空字符串或缺省 → 回落普通字符串请求（与 Legado setType 空白即 null 一致）。
//   4. data: URI + type → 直接解出字节转 hex，不发请求。
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// 可编排的 HttpPort：记录 send / getBytes 调用，按脚本返回或抛错。
class _TypeHttp implements HttpPort {
  _TypeHttp(this.bytes, {this.getBytesThrows = false});

  final List<int> bytes;
  final bool getBytesThrows;
  int sendCalls = 0;
  int getBytesCalls = 0;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    sendCalls++;
    return StrResponse(url: spec.url, body: 'string-body', code: 200);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    getBytesCalls++;
    if (getBytesThrows) throw StateError('不该发起请求');
    return Uint8List.fromList(bytes);
  }

  @override
  void cancelInFlight() {}
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  setUp(RateLimiter.resetShared);
  tearDown(RateLimiter.resetShared);

  group('AnalyzeUrl type 选项（对齐 Legado-E AnalyzeUrl.kt:424-426）', () {
    test('type 非空走字节通道，不调用 send()', () async {
      final http = _TypeHttp(utf8.encode('ABC'));
      final a = AnalyzeUrl(
        mUrl: 'https://ex.com/f,{"type":"binary"}',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      // 字节通道只走 getBytes，绝不走 send（普通字符串请求）。
      expect(http.sendCalls, 0);
      expect(http.getBytesCalls, 1);
      // 字节 41 42 43 = "ABC" 的 hex。
      expect(res.body, '414243');
    });

    test('type 取值无关：binary/text/image 输出一致', () async {
      Future<String?> hexFor(String value) async {
        final http = _TypeHttp([0xDE, 0xAD, 0xBE, 0xEF]);
        final a = AnalyzeUrl(
          mUrl: 'https://ex.com/f,{"type":"$value"}',
          http: http,
          jsRuntime: const LenientJsRuntime(),
        );
        return (await a.getStrResponse()).body;
      }

      final b = await hexFor('binary');
      final t = await hexFor('text');
      final i = await hexFor('image');
      expect(b, 'deadbeef');
      expect(t, 'deadbeef');
      expect(i, 'deadbeef');
    });

    test('type=webSocket 不触发 WS 路由，仅按值无关的字节/hex 处理', () async {
      // Legado 无 webSocket 路由；引擎严格对齐：不识别 WS 传输层，只走字节/hex。
      final http = _TypeHttp([0xAA, 0xBB]);
      final a = AnalyzeUrl(
        mUrl: 'https://ex.com/s,{"type":"webSocket"}',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(res.body, 'aabb');
      expect(http.sendCalls, 0);
      expect(http.getBytesCalls, 1);
    });

    test('type 为空字符串时不走字节通道，回落普通请求', () async {
      final http = _TypeHttp([1, 2, 3]);
      final a = AnalyzeUrl(
        mUrl: 'https://ex.com/f,{"type":""}',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(http.sendCalls, 1);
      expect(http.getBytesCalls, 0);
      expect(res.body, 'string-body');
    });

    test('type 缺省走普通请求路径', () async {
      final http = _TypeHttp([1, 2, 3]);
      final a = AnalyzeUrl(
        mUrl: 'https://ex.com/f',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(http.sendCalls, 1);
      expect(http.getBytesCalls, 0);
      expect(res.body, 'string-body');
    });

    test('data: URI 配合 type 直接解出字节并转 hex，不发请求', () async {
      final payload = base64.encode([0x01, 0x02, 0x03]);
      final http = _TypeHttp([0, 0, 0], getBytesThrows: true);
      final a = AnalyzeUrl(
        mUrl: 'data:image/png;base64,$payload,{"type":"binary"}',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(res.body, '010203');
      // data: 由 _decodeDataUri 直接解字节，既不走 send 也不走 getBytes。
      expect(http.sendCalls, 0);
      expect(http.getBytesCalls, 0);
    });

    test('type 非空时返回的 hex 与已知字节严格相等（奇偶校验）', () async {
      // 故意用一段非 ASCII 字节，验证 hex 编码是逐字节而非 utf8 重编码。
      final raw = [0x00, 0x0f, 0xff, 0x80, 0x7f];
      final http = _TypeHttp(raw);
      final a = AnalyzeUrl(
        mUrl: 'https://ex.com/b,{"type":"binary"}',
        http: http,
        jsRuntime: const LenientJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(res.body, _hex(raw));
    });
  });
}
