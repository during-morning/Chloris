import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:http/http.dart' as http;
import '../../services/web/server_connection.dart';
import '../../core/http/http_session.dart';
import 'native_browser_script.dart';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('JSON.stringify')
external String _jsonStringify(JSAny? value);

int _seq = 0;

final _browserAborts = <String, Completer<void>>{};
Future<void> cancelBrowserSession(String id) async {
  final pending = _browserAborts.remove(id);
  if (pending != null && !pending.isCompleted) pending.complete();
  final connection = await ServerConnection.load();
  final base = connection.isConfigured
      ? Uri.parse(connection.normalizedBaseUrl)
      : Uri.base;
  await http
      .delete(
        base.resolve('/api/music/v1/browser/$id'),
        headers: {
          if (connection.token.isNotEmpty)
            'authorization': 'Bearer ${connection.token}',
        },
      )
      .timeout(const Duration(seconds: 2))
      .catchError((Object _) => http.Response('', 503));
}

Future<WebViewResult?> evaluateInBrowser(WebViewRequest request) async {
  final connection = await ServerConnection.load();
  final base = connection.isConfigured
      ? Uri.parse(connection.normalizedBaseUrl)
      : Uri.base;
  final id =
      HttpSession.current ??
      'browser-${++_seq}-${DateTime.now().microsecondsSinceEpoch}';
  final abort = Completer<void>();
  _browserAborts[id] = abort;
  final client = http.Client();
  try {
    final message =
        http.AbortableRequest(
            'POST',
            base.resolve('/api/music/v1/browser'),
            abortTrigger: abort.future,
          )
          ..headers.addAll({
            'content-type': 'application/json',
            if (connection.token.isNotEmpty)
              'authorization': 'Bearer ${connection.token}',
          })
          ..body = jsonEncode({
            'id': id,
            'url': request.url,
            'html': request.html,
            'headers': request.headers,
            'capture': browserCaptureScript(),
            'script': browserResultScript(request),
            'timeoutMs': 20000,
          });
    final response = await client
        .send(message)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 21));
    if (response.statusCode != 200)
      throw UnsupportedError('动态解析服务不可用，请连接已安装 Chromium worker 的 Chloris 服务');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['error'] != null) throw StateError('${data['error']}');
    return WebViewResult(
      body: '${data['body'] ?? ''}',
      url: '${data['url'] ?? request.url}',
      cookie: data['cookie'] as String?,
    );
  } finally {
    _browserAborts.remove(id);
    client.close();
    await cancelBrowserSession(id);
  }
}

class LoginWebEmbed extends StatefulWidget {
  const LoginWebEmbed({
    super.key,
    required this.html,
    required this.baseUrl,
    required this.onMessage,
  });

  final String html;
  final String baseUrl;
  final void Function(Map<String, dynamic> message) onMessage;

  @override
  State<LoginWebEmbed> createState() => _LoginWebEmbedState();
}

class _LoginWebEmbedState extends State<LoginWebEmbed> {
  late final String _viewType;
  late final String _id;
  late final JSObject _iframe;
  JSFunction? _handler;

  @override
  void initState() {
    super.initState();
    _id = 'in${++_seq}${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'chloris-login-$_id';
    _iframe =
        _document.callMethod('createElement'.toJS, 'iframe'.toJS) as JSObject;
    _iframe.setProperty('srcdoc'.toJS, _prepared().toJS);
    final styleAny = _iframe.getProperty('style'.toJS);
    if (styleAny != null) {
      final style = styleAny as JSObject;
      style.setProperty('border'.toJS, '0'.toJS);
      style.setProperty('width'.toJS, '100%'.toJS);
      style.setProperty('height'.toJS, '100%'.toJS);
      style.setProperty('background'.toJS, '#fff'.toJS);
    }
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
    void onMessage(JSAny event) {
      try {
        final data = (event as JSObject).getProperty('data'.toJS);
        final raw = _jsonStringify(data);
        final map = jsonDecode(raw);
        if (map is! Map) return;
        if (map['id']?.toString() != _id) return;
        widget.onMessage(Map<String, dynamic>.from(map));
      } catch (_) {}
    }

    _handler = onMessage.toJS;
    _window.callMethod('addEventListener'.toJS, 'message'.toJS, _handler);
  }

  String _prepared() => prepareWebViewDocument(
    html: widget.html,
    baseUrl: widget.baseUrl,
    interactive: true,
    proxyImages: true,
    messageId: _id,
  );

  @override
  void didUpdateWidget(LoginWebEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html || oldWidget.baseUrl != widget.baseUrl) {
      _iframe.setProperty('srcdoc'.toJS, _prepared().toJS);
    }
  }

  @override
  void dispose() {
    final handler = _handler;
    if (handler != null) {
      try {
        _window.callMethod('removeEventListener'.toJS, 'message'.toJS, handler);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

bool get loginEmbedIsRealWebView => true;
