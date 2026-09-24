// `java.getElement` / `java.getElements` 的元素门面对齐测试。
//
// 背景（差异文档 §12 的 P1）：Legado-E 的 `AnalyzeRule.getElement` 交给脚本的是
// 真实 jsoup `Element`，规则可以 `.text()` / `.attr()` / `.select()`；Chloris 的
// 桥是 JSON-only，旧实现把节点降级成 markup 字符串，于是
//   java.getElement('div.list').select('a').text()
// 这类写法必然失效。
//
// 现在的形态：Dart 侧保留活节点并发放句柄，回一个自识别信封
//   {"__el": {...}} / {"__els": [...]} / {"__raws": [...]}
// JS prelude 把它还原成带方法的门面。本文件覆盖 Dart 侧那一半；
// prelude 那一半由 `prelude element facade (node)` 那组用真实 JS 引擎跑。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

class _NoHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  void cancelInFlight() {}
}

const _html =
    '<div class="list"><a href="/a">Alpha</a><a href="/b">Beta</a></div>';

void main() {
  group('信封形态（Dart 侧）', () {
    late JavaHost host;
    setUp(() {
      host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    });

    test('非元素结果原样透传，不破坏正则后端', () {
      // 正则后端的 getElement 返回的是字符串，旧行为必须保留。
      expect(host.elementEnvelope('plain text'), 'plain text');
      expect(host.elementEnvelope(null), isNull);
      expect(host.elementEnvelope(123), 123);
      final raws = host.elementsEnvelope(<Object>['a', 'b']) as Map;
      expect(raws['__raws'], ['a', 'b']);
    });

    test('空列表回 __els: [] 而不是 null（jsoup 的 Elements 是空集合）', () {
      final env = host.elementsEnvelope(const <Object>[]) as Map;
      expect(env['__els'], isEmpty);
    });

    test('元素描述符带上门面需要的全部字段', () async {
      final rule = AnalyzeRule(jsRuntime: const NoJsRuntime(), javaHost: host)
        ..setContent(_html);
      final env = await host.getElement('div.list') as Map;
      final d = env['__el'] as Map;
      expect(d['tag'], 'div');
      expect(d['cls'], 'list');
      expect(d['h'], isA<int>());
      expect(d['outer'], contains('<div class="list">'));
      expect(d['html'], contains('<a href="/a">'));
    });
  });

  group('elementOp：门面的下钻方法', () {
    late JavaHost host;
    late int handle;

    setUp(() async {
      host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      final rule = AnalyzeRule(jsRuntime: const NoJsRuntime(), javaHost: host)
        ..setContent(_html);
      final env = await host.getElement('div.list') as Map;
      handle = (env['__el'] as Map)['h'] as int;
    });

    test('select 返回元素列表信封', () {
      final decoded = jsonDecode(host.elementOp(handle, 'select', 'a')) as Map;
      final els = decoded['__els'] as List;
      expect(els, hasLength(2));
      expect((els[0] as Map)['text'], 'Alpha');
      expect((els[1] as Map)['attrs'], {'href': '/b'});
    });

    test('selectFirst 返回单个元素信封', () {
      final decoded = jsonDecode(host.elementOp(handle, 'selectFirst', 'a')) as Map;
      expect((decoded['__el'] as Map)['text'], 'Alpha');
    });

    test('children / parent 可用', () {
      final kids = jsonDecode(host.elementOp(handle, 'children', '')) as Map;
      expect((kids['__els'] as List), hasLength(2));
      final childHandle = ((kids['__els'] as List).first as Map)['h'] as int;
      final parent = jsonDecode(host.elementOp(childHandle, 'parent', '')) as Map;
      expect((parent['__el'] as Map)['cls'], 'list');
    });

    test('getElementsByTag / getElementsByClass', () {
      final byTag = jsonDecode(host.elementOp(handle, 'tag', 'a')) as Map;
      expect((byTag['__els'] as List), hasLength(2));
      final byClass = jsonDecode(host.elementOp(handle, 'class', 'list')) as Map;
      expect((byClass['__els'] as List), isEmpty); // class.list 只在自身
    });

    test('选不到时返回空信封而不是错误', () {
      final none = jsonDecode(host.elementOp(handle, 'select', 'table')) as Map;
      expect(none['__els'], isEmpty);
    });
  });

  group('句柄生命周期', () {
    test('句柄被淘汰后给出可见告警，而不是静默返回空', () {
      DebugLog.clear();
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      // 注册超过上限的节点，最早的句柄应被淘汰。
      for (var i = 0; i < 200; i++) {
        host.elementEnvelope(_parse('<p>$i</p>'));
      }
      expect(host.elementOp(1, 'select', 'a'), '');
      expect(
        DebugLog.buffer.any(
          (e) => e.tag == 'java.element' && e.message.contains('expired'),
        ),
        isTrue,
        reason: '失效句柄必须是可见失败，不能伪装成「没选到」',
      );
      DebugLog.clear();
    });
  });

  group('invokeSync 出口', () {
    test('elementOp 走同步桥并回 JSON 字符串（运行时会对返回值 toString）', () async {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      final rule = AnalyzeRule(jsRuntime: const NoJsRuntime(), javaHost: host)
        ..setContent(_html);
      final env = await host.getElement('div.list') as Map;
      final handle = (env['__el'] as Map)['h'];
      final out = host.invokeSync('elementOp', [handle, 'select', 'a']);
      expect(out, isA<String>());
      final decoded = jsonDecode(out as String) as Map;
      expect((decoded['__els'] as List), hasLength(2));
      // 未注册句柄也要走 elementOp 的可见告警分支
      DebugLog.clear();
      expect(host.invokeSync('elementOp', [999999, 'children', '']), '');
      DebugLog.clear();
    });
  });

  group('prelude 契约', () {
    test('prelude 定义门面与 elementOp 桥', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final needle in const [
        'function __elFrom(',
        'function __mkEl(',
        'function __mkEls(',
        'elementOp',
        'select: function(css)',
        'outerHtml: function()',
      ]) {
        expect(prelude, contains(needle), reason: needle);
      }
      // cache.get 必须把第二参当 onlyDisk 布尔量，不能当默认值透传。
      expect(prelude, contains('onlyDisk === true'));
    });
  });

  group('prelude element facade (node)', () {
    // 真实 JS 引擎验证：引擎包内不含 JS 虚拟机（真机实现由 App 注入），
    // 所以这里在 node 可用时把 prelude 跑起来；不可用就跳过并说明原因。
    test('java.getElement(...).select(...).text() 端到端可用', () {
      final node = _findNode();
      if (node == null) {
        markTestSkipped('node 不在 PATH 上，跳过 prelude 的 JS 侧验证');
        return;
      }
      final script = _harness(node);
      final result = Process.runSync(node, ['-e', script]);
      expect(
        result.exitCode,
        0,
        reason: 'prelude 在真实 JS 引擎下报错: ${result.stderr}',
      );
      expect((result.stdout as String).trim(), 'ALL OK');
    });
  }, skip: false);
}

String? _findNode() {
  for (final candidate in const ['/opt/homebrew/bin/node', '/usr/local/bin/node', 'node']) {
    try {
      final r = Process.runSync(candidate, ['-e', 'process.exit(0)']);
      if (r.exitCode == 0) return candidate;
    } catch (_) {}
  }
  return null;
}

/// 用真实 JS 引擎跑 prelude 的门面，`sendMessage` 由测试自己实现，
/// 走的就是 prelude 里 `__chlorisJava` 的真实分支。
String _harness(String node) {
  final prelude = JsHostBridge.prelude(
    vars: const {
      'source': <String, Object?>{'bookSourceUrl': 'https://e.test'},
      'book': <String, Object?>{},
      'chapter': <String, Object?>{},
      'cookie': '',
      'result': '',
      'baseUrl': 'https://e.test',
    },
    hid: 'h1',
  );
  final encoded = jsonEncode(prelude);
  return '''
var PRELUDE = $encoded;
// Dart 侧 elementOp / getElement 会回的信封（真实实现见 JavaHost.elementOp）。
// 这里用 JSON.stringify 现场构造，避免手写 JSON 时转义层数出错 —— 之前就是
// 因为 `outer` 里的引号被 JS 提前吃掉，JSON.parse 失败后退回原始字符串。
function envl(o) { return JSON.stringify(o); }
var EL_DIV = {h:1, tag:'div', cls:'list', text:'Alpha Beta', own:'', html:'<a>Alpha</a>', outer:'<div class="list">', attrs:{}, id:''};
var EL_A1 = {h:2, tag:'a', text:'Alpha', outer:'<a href="/a">Alpha</a>', attrs:{href:'/a'}};
var EL_A2 = {h:3, tag:'a', text:'Beta', outer:'<a href="/b">Beta</a>', attrs:{href:'/b'}};
var EL_BODY = {h:9, tag:'body', cls:'', attrs:{}};
globalThis.sendMessage = function (channel, payload) {
  if (channel !== 'chlorisJava') return '';
  var req = JSON.parse(payload);
  if (req.m === 'getElement') return req.a[0] === 'div.list' ? envl({__el: EL_DIV}) : '';
  if (req.m === 'getElements') return envl({__els: []});
  if (req.m === 'elementOp') {
    var h = req.a[0], op = req.a[1], arg = req.a[2];
    if (h === 1 && op === 'select' && arg === 'a') return envl({__els: [EL_A1, EL_A2]});
    if (h === 1 && op === 'select' && arg === 'table') return envl({__els: []});
    if (h === 1 && op === 'children') return envl({__els: [EL_A1]});
    if (op === 'parent') return envl({__el: EL_BODY});
    if (h === 1 && op === 'tag' && arg === 'a') return envl({__els: [EL_A1, EL_A2]});
    return '';
  }
  return '';
};
eval(PRELUDE);
var errs = [];
function chk(name, got, want) {
  if (got !== want) errs.push(name + ': got ' + JSON.stringify(got) + ' want ' + JSON.stringify(want));
}
var el = java.getElement('div.list');
chk('tagName', el.tagName(), 'div');
chk('text', el.text(), 'Alpha Beta');
chk('ownText', el.ownText(), '');
chk('html', el.html(), '<a>Alpha</a>');
chk('attr missing', el.attr('nope'), '');
chk('outerHtml', el.outerHtml(), '<div class="list">');
chk('id', el.id(), '');
chk('className', el.className(), 'list');
chk('attributes length', el.attributes().length, 0);
var links = el.select('a');
chk('select length', links.length, 2);
chk('select size', links.size(), 2);
chk('select text join', links.text(), 'Alpha\\nBeta');
chk('select first text', links.first().text(), 'Alpha');
chk('select last text', links.last().text(), 'Beta');
chk('select attr', links.attr('href'), '/a');
chk('select get', links.get(1).text(), 'Beta');
chk('select outerHtml', links.outerHtml(), '<a href="/a">Alpha</a><a href="/b">Beta</a>');
chk('select empty', el.select('table').length, 0);
chk('children length', el.children().length, 1);
chk('children chained text', el.children().text(), 'Alpha');
chk('parent tag', el.parent().tagName(), 'body');
chk('getElementsByTag', el.getElementsByTag('a').length, 2);
chk('toString', String(el), '<div class="list">');
chk('getElements empty', java.getElements('x').length, 0);
// 非信封字符串必须原样返回（正则后端的旧行为）
chk('plain passthrough', __elFrom('Chapter 1'), 'Chapter 1');
chk('numeric passthrough', __elFrom('123'), '123');
chk('empty passthrough is null', __elFrom(''), null);
if (errs.length) { console.error(errs.join('\\n')); process.exit(1); }
console.log('ALL OK');
''';
}

dynamic _parse(String html) {
  // 复用引擎的 CSS 后端拿一个真实 Element，避免测试自己再引 package:html。
  final css = AnalyzeByCss(html);
  return css.getElements('p').first;
}
