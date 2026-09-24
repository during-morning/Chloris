// AnalyzeUrl 选项层与 Legado-E 的逐条对齐测试。
//
// 覆盖差异文档 §12 的 P2-13：`data:` URI、`isTest` 负错误码、`skipRateLimit`。
// 对照实现：reference/legado-E-main .../AnalyzeUrl.kt:415-433（限速与跳过）、
// 516-536（测试模式错误码）、634-645 + AppPattern.kt:20（data: URI）。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// 可编排的 HttpPort：记录调用、按脚本返回或抛错。
class _ScriptedHttp implements HttpPort {
  _ScriptedHttp(this.behavior);

  final Future<StrResponse> Function(HttpRequestSpec spec) behavior;
  final List<HttpRequestSpec> calls = [];
  int getBytesCalls = 0;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) {
    calls.add(spec);
    return behavior(spec);
  }

  @override
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
  }) async {
    getBytesCalls++;
    return Uint8List.fromList(utf8.encode('stub-bytes'));
  }

  @override
  void cancelInFlight() {}
}

/// 模拟 TLS 握手失败。
///
/// `dart:io` 的 `HandshakeException` 没有公开构造函数，而 `analyze_url.dart`
/// 又不能 import `dart:io`（引擎要能编到 Web），所以用消息特征来构造这一例。
class _FakeTlsFailure implements Exception {
  @override
  String toString() => 'HandshakeException: Connection terminated during handshake';
}

String _hexOf(String s) =>
    utf8.encode(s).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  setUp(RateLimiter.resetShared);
  tearDown(RateLimiter.resetShared);

  group('data: URI（对齐 Legado AnalyzeUrl.kt:634-645）', () {
    test('type 选项下，base64 data URI 直接解出字节并转 hex，不发起请求', () async {
      final http = _ScriptedHttp(
        (_) async => throw StateError('不该发起请求'),
      );
      final payload = base64.encode(utf8.encode('hello'));
      final a = AnalyzeUrl(
        mUrl: 'data:text/plain;base64,$payload,{"type":"hex"}',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(res.body, _hexOf('hello'));
      expect(http.getBytesCalls, 0, reason: 'data: URI 不应走网络');
      expect(http.calls, isEmpty);
    });

    test('非 base64 形态的 data URI 不当作 data URI（Legado 正则要求 ;base64,）', () async {
      final http = _ScriptedHttp(
        (_) async => const StrResponse(url: 'x', body: 'net'),
      );
      final a = AnalyzeUrl(
        mUrl: 'data:text/plain,hello,{"type":"hex"}',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      final res = await a.getStrResponse();
      // 匹配不到就落到正常字节通道（getBytes），与 Legado 返回 null 后继续请求一致。
      expect(http.getBytesCalls, 1);
      expect(res.body, _hexOf('stub-bytes'));
    });

    test('非法 base64 退化为普通请求，而不是静默空结果', () async {
      final http = _ScriptedHttp(
        (_) async => const StrResponse(url: 'x', body: 'net'),
      );
      final a = AnalyzeUrl(
        mUrl: 'data:text/plain;base64,!!!not-base64!!!,{"type":"hex"}',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      final res = await a.getStrResponse();
      expect(http.getBytesCalls, 1);
      expect(res.body, isNotNull);
    });

    test('不带 type 的 data: URI 明确报错（Legado 也只在字节通道识别 data:）', () async {
      final http = _ScriptedHttp(
        (_) async => const StrResponse(url: 'x', body: 'net'),
      );
      final a = AnalyzeUrl(
        mUrl: 'data:text/plain;base64,aGVsbG8=',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      await expectLater(
        a.getStrResponse(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('type 选项'),
          ),
        ),
      );
    });
  });

  group('isTest 负错误码（对齐 AnalyzeUrl.kt:516-536）', () {
    Future<int> codeFor(Object error) async {
      final http = _ScriptedHttp((_) async => throw error);
      final a = AnalyzeUrl(
        mUrl: 'https://ex.test/a',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      final res = await a.getStrResponse(isTest: true);
      return res.callTime;
    }

    test('调用方超时 → -1', () async {
      expect(await codeFor(TimeoutException('timeout')), -1);
    });

    test('读超时 → -2', () async {
      expect(
        await codeFor(StateError('SocketException: Read timed out')),
        -2,
      );
    });

    test('域名不存在 → -3', () async {
      expect(
        await codeFor(StateError('SocketException: Failed host lookup: nope')),
        -3,
      );
    });

    test('连接被拒 → -4', () async {
      expect(
        await codeFor(StateError('SocketException: Connection refused')),
        -4,
      );
    });

    test('其它 Socket 错误 → -5', () async {
      expect(
        await codeFor(StateError('SocketException: Connection reset by peer')),
        -5,
      );
    });

    test('TLS 握手失败 → -6', () async {
      expect(await codeFor(_FakeTlsFailure()), -6);
    });

    test('其它错误 → -7', () async {
      expect(await codeFor(StateError('weird failure')), -7);
    });

    test('HTTP 5xx 在测试模式下也折叠成 -7 而不抛', () async {
      final http = _ScriptedHttp(
        (_) async => const StrResponse(url: 'u', body: 'oops', code: 502),
      );
      final a = AnalyzeUrl(
        mUrl: 'https://ex.test/a',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      final res = await a.getStrResponse(isTest: true);
      expect(res.callTime, -7);
    });

    test('非测试模式仍然照常抛出（对齐 !isTest -> throw e）', () async {
      final http = _ScriptedHttp(
        (_) async => throw StateError('SocketException: Connection refused'),
      );
      final a = AnalyzeUrl(
        mUrl: 'https://ex.test/a',
        http: http,
        jsRuntime: const NoJsRuntime(),
      );
      await expectLater(a.getStrResponse(), throwsA(isA<StateError>()));
    });
  });

  group('skipRateLimit（对齐 AnalyzeUrl.kt:427-432）', () {
    Future<int> elapsedMs({required bool skip}) async {
      final http = _ScriptedHttp(
        (_) async => const StrResponse(url: 'u', body: 'ok'),
      );
      final source = BookSource(
        bookSourceUrl: 'https://rate.test',
        // 400ms 间隔：第二次请求要么等满一个间隔，要么被跳过。
        concurrentRate: '400',
      );
      final watch = Stopwatch()..start();
      for (var i = 0; i < 2; i++) {
        final a = AnalyzeUrl(
          mUrl: 'https://rate.test/a',
          http: http,
          jsRuntime: const NoJsRuntime(),
          source: source,
        );
        await a.getStrResponse(skipRateLimit: skip);
      }
      watch.stop();
      return watch.elapsedMilliseconds;
    }

    test('默认受限速约束', () async {
      expect(await elapsedMs(skip: false), greaterThanOrEqualTo(350));
    });

    test('skipRateLimit=true 旁路限速', () async {
      expect(await elapsedMs(skip: true), lessThan(350));
    });
  });
}
