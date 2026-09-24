import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// 对齐 Legado-E 的请求构造层语义（artifacts 文档 §12 的 P0-1/P0-2/P0-3/P0-4/P1-bodyJs）。
/// 每条测试断言「改动后（=Legado 真实语义）」的可判定值。
class _NoopHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      StrResponse(url: spec.url, body: 'response-old', code: 200);

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List.fromList([0, 15, 255]);

  @override
  void cancelInFlight() {}
}

class _HeaderHttp implements HttpPort {
  HttpRequestSpec? last;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    last = spec;
    return StrResponse(url: spec.url, body: 'response-old', code: 200);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List.fromList([0, 15, 255]);

  @override
  void cancelInFlight() {}
}

void main() {
  // P0-1：{{}} 必须先于页模板，否则内嵌规则里的大于小于号会被页模板正则误切
  // （对齐 AnalyzeUrl.kt:190 注释）。这里用一个在 {{}} 内注入 '<' 的规则：
  // 若页模板先跑，正则 <([^>]*)> 会误切 {{}} 内部的 '<'，MARK 占位符残留；
  // 正确顺序下 {{}} 先完整求值，MARK 被替换为 '<a>' 后再按页模板处理。
  test('P0-1 {{}} 先于页模板，内嵌 < > 不被页模板正则误切', () async {
    final a = AnalyzeUrl(
      mUrl: "https://ex.com/a/{{result.replace('MARK','<a>')}}.html?p=<x,y>.html",
      http: _NoopHttp(),
      jsRuntime: const LenientJsRuntime(),
      page: 1,
      baseUrl: 'https://ex.com',
    );
    await a.init();
    expect(a.url, isNot(contains('MARK')),
        reason: '{{...}} 应先被完整求值，MARK 不应残留（旧顺序会被页模板正则切掉内部 < >）');
    expect(a.url, endsWith('p=x.html'),
        reason: '页模板 <x,y> 取第 1 段');
  });

  // P0-2：页模板按索引取 pages[page-1]，越界取 pages.last()，不做步长外推。
  test('P0-2 页模板按索引取，越界取 last，不做外推', () async {
    final a = AnalyzeUrl(
      mUrl: 'https://ex.com/s/<1,2,3>.html',
      http: _NoopHttp(),
      jsRuntime: const NoJsRuntime(),
      page: 2,
      baseUrl: 'https://ex.com',
    );
    await a.init();
    expect(a.url, endsWith('/s/2.html'),
        reason: 'pages[page-1] = pages[1] = 2（旧实现外推得 4）');

    final b = AnalyzeUrl(
      mUrl: 'https://ex.com/s/<1,2,3>.html',
      http: _NoopHttp(),
      jsRuntime: const NoJsRuntime(),
      page: 5,
      baseUrl: 'https://ex.com',
    );
    await b.init();
    expect(b.url, endsWith('/s/3.html'),
        reason: '越界取 pages.last() = 3（旧实现外推得 9）');

    final c = AnalyzeUrl(
      mUrl: 'https://ex.com/s/<a,b,c>.html',
      http: _NoopHttp(),
      jsRuntime: const NoJsRuntime(),
      page: 2,
      baseUrl: 'https://ex.com',
    );
    await c.init();
    expect(c.url, endsWith('/s/b.html'), reason: '非数字模板同理按索引');
  });

  // P0-3：opt.headers 覆盖 source.header（对齐 AnalyzeUrl.kt:248-250）。
  test('P0-3 opt.headers 覆盖 source.header', () async {
    final http = _HeaderHttp();
    final a = AnalyzeUrl(
      mUrl: 'https://ex.com/a,{"headers":{"X-Src":"opt"}}',
      http: http,
      jsRuntime: const NoJsRuntime(),
      source: BookSource(
        bookSourceUrl: 'https://ex.com',
        header: '{"X-Src":"src","X-Extra":"1"}',
      ),
    );
    await a.getStrResponse();
    expect(http.last?.headers['X-Src'], 'opt',
        reason: 'opt.headers 覆盖源 header');
    expect(http.last?.headers['X-Extra'], '1',
        reason: '源 header 未冲突项保留');
  });

  // P0-4：规则 Cookie 覆盖 jar Cookie（对齐 AnalyzeUrl.kt:703-725）。
  test('P0-4 规则 Cookie 覆盖 jar', () async {
    final http = _HeaderHttp();
    final cs = CookieStore();
    cs.set('https://ex.com', 'sid=jar; token=fromjar');
    final a = AnalyzeUrl(
      mUrl: 'https://ex.com/a,{"headers":{"Cookie":"sid=rule"}}',
      http: http,
      jsRuntime: const NoJsRuntime(),
      cookieStore: cs,
      source: BookSource(bookSourceUrl: 'https://ex.com', enabledCookieJar: true),
    );
    await a.getStrResponse();
    final cookie = http.last?.headers['Cookie'] ?? '';
    expect(cookie, contains('sid=rule'), reason: '规则 Cookie 胜出');
    expect(cookie, contains('token=fromjar'), reason: 'jar 独有键保留');
    expect(cookie, isNot(contains('sid=jar')), reason: 'sid 被规则侧覆盖');
  });

  // enabledCookieJar==false 时仍随规则里写的 Cookie 发送（与 Legado 一致）。
  test('P0-4b enabledCookieJar==false 仍带规则 Cookie', () async {
    final http = _HeaderHttp();
    final cs = CookieStore();
    cs.set('https://ex.com', 'sid=jar');
    final a = AnalyzeUrl(
      mUrl: 'https://ex.com/a,{"headers":{"Cookie":"sid=rule"}}',
      http: http,
      jsRuntime: const NoJsRuntime(),
      cookieStore: cs,
      source: BookSource(bookSourceUrl: 'https://ex.com', enabledCookieJar: false),
    );
    await a.getStrResponse();
    expect(http.last?.headers['Cookie'], 'sid=rule',
        reason: '关闭 jar 时仍随规则 Cookie 发送');
  });

  // P1-bodyJs：作用于响应 body，而非请求 body（对齐 AnalyzeUrl.kt:507-510）。
  test('P1-bodyJs 作用于响应 body', () async {
    final http = _HeaderHttp();
    final a = AnalyzeUrl(
      mUrl:
          'https://ex.com/api,{"method":"POST","body":"v=old","bodyJs":"result.replace(\'old\',\'new\')"}',
      http: http,
      jsRuntime: const LenientJsRuntime(),
    );
    final res = await a.getStrResponse();
    expect(http.last?.body, 'v=old', reason: '请求 body 不变');
    expect(res.body, 'response-new', reason: '响应 body 经 bodyJs 处理');
  });
}
