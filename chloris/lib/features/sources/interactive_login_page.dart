import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/webview/webview_factory.dart';

class InteractiveLoginPage extends StatefulWidget {
  const InteractiveLoginPage({
    super.key,
    required this.request,
    required this.http,
    required this.cookieStore,
  });

  final WebViewRequest request;
  final HttpPort http;
  final CookieStore cookieStore;

  @override
  State<InteractiveLoginPage> createState() => _InteractiveLoginPageState();
}

class _InteractiveLoginPageState extends State<InteractiveLoginPage> {
  String _url = '';
  String _html = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = widget.request.url;
    _load(_url);
  }

  Map<String, String> _headersFor(String url) {
    final headers = Map<String, String>.from(widget.request.headers);
    final cookie = widget.cookieStore.get(url);
    if (cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  void _mergeCookies(String url, Map<String, String> headers) {
    final setCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    widget.cookieStore.mergeSetCookie(url, setCookie);
    widget.cookieStore.mergeSetCookie(widget.request.url, setCookie);
  }

  Future<void> _load(String url, {String method = 'GET', String? body}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = _headersFor(url);
      if (method == 'POST' && body != null) {
        headers['Content-Type'] =
            headers['Content-Type'] ?? 'application/x-www-form-urlencoded';
      }
      final res = await widget.http.send(
        HttpRequestSpec(url: url, method: method, headers: headers, body: body),
      );
      _mergeCookies(res.url, res.headers);
      if (!mounted) return;
      setState(() {
        _url = res.url;
        _html = res.body ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onEmbedMessage(Map<String, dynamic> msg) {
    final type = msg['type']?.toString();
    if (type == 'chloris-wv-nav') {
      final href = msg['href']?.toString() ?? '';
      if (href.isEmpty) return;
      _load(Uri.parse(_url).resolve(href).toString());
      return;
    }
    if (type != 'chloris-wv-submit') return;
    final action = msg['action']?.toString() ?? _url;
    final method = (msg['method']?.toString() ?? 'POST').toUpperCase();
    final raw = msg['data'];
    final data = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) => data[k.toString()] = v.toString());
    }
    final encoded = data.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final resolved = Uri.parse(_url).resolve(action);
    if (method == 'GET') {
      final next = resolved.replace(
        query: [
          if (resolved.query.isNotEmpty) resolved.query,
          if (encoded.isNotEmpty) encoded,
        ].join('&'),
      );
      _load(next.toString());
      return;
    }
    _load(resolved.toString(), method: 'POST', body: encoded);
  }

  void _finish() {
    Navigator.of(context).pop(
      WebViewResult(
        body: _html,
        url: _url,
        cookie: widget.cookieStore.get(widget.request.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.request.title?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title == null || title.isEmpty ? '登录 / 验证码' : '登录 · $title',
        ),
        actions: [TextButton(onPressed: _finish, child: const Text('完成登录'))],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _html.isEmpty && !_loading
                ? Center(
                    child: TextButton.icon(
                      onPressed: () {
                        final uri = Uri.tryParse(widget.request.url);
                        if (uri != null) launchUrl(uri);
                      },
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('打开系统浏览器'),
                    ),
                  )
                : LoginWebEmbed(
                    html: _html,
                    baseUrl: _url.isEmpty ? widget.request.url : _url,
                    onMessage: _onEmbedMessage,
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loginEmbedIsRealWebView
                          ? '在页面中完成登录或验证码，然后点「完成登录」。'
                          : '填写表单提交；复杂验证码可改用系统浏览器后粘贴 Cookie。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final uri = Uri.tryParse(widget.request.url);
                      if (uri != null) launchUrl(uri);
                    },
                    child: const Text('系统浏览器'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
