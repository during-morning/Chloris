/// Headless or interactive browser evaluation, injected by the app.
class WebViewRequest {
  const WebViewRequest({
    required this.url,
    this.html,
    this.javaScript,
    this.sourceRegex,
    this.headers = const {},
    this.interactive = false,
    this.title,
  });

  final String url;
  final String? html;
  final String? javaScript;
  final String? sourceRegex;
  final Map<String, String> headers;
  final bool interactive;
  final String? title;
}

class WebViewResult {
  const WebViewResult({
    required this.body,
    required this.url,
    this.cookie,
  });

  final String body;
  final String url;
  final String? cookie;
}

abstract class WebViewPort {
  Future<WebViewResult?> run(WebViewRequest request);
}

bool looksLikeLoginWall(String? body) {
  if (body == null || body.isEmpty) return false;
  final t = body.toLowerCase();
  return t.contains('验证码') ||
      t.contains('captcha') ||
      t.contains('请登录') ||
      t.contains('请登陆') ||
      t.contains('登陆后') ||
      t.contains('登录后') ||
      t.contains('geetest') ||
      t.contains('cf-challenge') ||
      t.contains('cf-browser-verification');
}

/// Inject `<base>`, optional image proxy, and a completion script.
String prepareWebViewDocument({
  required String html,
  required String baseUrl,
  String? javaScript,
  String? sourceRegex,
  bool interactive = false,
  bool proxyImages = false,
  String? messageId,
}) {
  var body = html.trim();
  if (body.isEmpty) {
    body = '<p></p>';
  }
  final baseTag = '<base href="${_esc(baseUrl)}">';
  if (RegExp(r'<head[\s>]', caseSensitive: false).hasMatch(body)) {
    body = body.replaceFirstMapped(
      RegExp(r'<head([^>]*)>', caseSensitive: false),
      (m) => '<head${m.group(1)}>$baseTag',
    );
  } else if (RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(body)) {
    body = body.replaceFirstMapped(
      RegExp(r'<html([^>]*)>', caseSensitive: false),
      (m) => '<html${m.group(1)}><head>$baseTag</head>',
    );
  } else {
    body = '<!DOCTYPE html><html><head>$baseTag</head><body>$body</body></html>';
  }
  if (proxyImages) {
    body = body.replaceAllMapped(
      RegExp(r'''(?<=\ssrc=["'])https?://[^"']+''', caseSensitive: false),
      (m) {
        final u = m.group(0)!;
        if (u.contains('/proxy/img')) return u;
        return '/proxy/img?u=${Uri.encodeQueryComponent(u)}';
      },
    );
  }
  final id = (messageId == null || messageId.isEmpty) ? 'wv' : messageId;
  final boot = interactive
      ? _interactiveBoot(id)
      : _evaluateBoot(javaScript, sourceRegex, id);
  if (RegExp(r'</body>', caseSensitive: false).hasMatch(body)) {
    body = body.replaceFirst(
      RegExp(r'</body>', caseSensitive: false),
      '$boot</body>',
    );
  } else {
    body = '$body$boot';
  }
  return body;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;');

String _evaluateBoot(String? javaScript, String? sourceRegex, String id) {
  final js = (javaScript == null || javaScript.trim().isEmpty)
      ? 'document.documentElement.outerHTML'
      : javaScript;
  final re = sourceRegex == null || sourceRegex.isEmpty
      ? 'null'
      : 'new RegExp(${_jsString(sourceRegex)})';
  return '''
<script>
(function(){
  var re = $re;
  var id = ${_jsString(id)};
  function sniff(){
    if (!re) return null;
    var nodes = document.querySelectorAll('[src],[href]');
    for (var i=0;i<nodes.length;i++){
      var u = nodes[i].src || nodes[i].href || '';
      if (u && re.test(u)) return u;
    }
    return null;
  }
  function finish(){
    var sniffed = sniff();
    var body = sniffed;
    if (!body) {
      try { body = (function(){ return ($js); })(); }
      catch (e) { body = document.documentElement.outerHTML; }
    }
    parent.postMessage({
      type: 'chloris-wv-done',
      id: id,
      body: String(body == null ? '' : body),
      url: location.href,
      cookie: document.cookie || ''
    }, '*');
  }
  if (document.readyState === 'complete') setTimeout(finish, 60);
  else window.addEventListener('load', function(){ setTimeout(finish, 80); });
})();
</script>
''';
}

String _interactiveBoot(String id) {
  return '''
<script>
(function(){
  var id = ${_jsString(id)};
  document.addEventListener('submit', function(e){
    var f = e.target;
    if (!f || !f.action) return;
    e.preventDefault();
    var data = {};
    var fd = new FormData(f);
    fd.forEach(function(v,k){ data[k]=String(v); });
    parent.postMessage({
      type: 'chloris-wv-submit',
      id: id,
      action: f.action,
      method: (f.method || 'GET').toUpperCase(),
      data: data
    }, '*');
  }, true);
  document.addEventListener('click', function(e){
    var a = e.target && e.target.closest ? e.target.closest('a') : null;
    if (!a || !a.href) return;
    if (a.target === '_blank') return;
    e.preventDefault();
    parent.postMessage({type:'chloris-wv-nav', id:id, href:a.href}, '*');
  }, true);
})();
</script>
''';
}

String _jsString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
