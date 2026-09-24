import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

@JS('JSON.stringify')
external String _jsonStringify(JSAny? value);

int _seq = 0;

Future<WebViewResult?> evaluateInBrowser(WebViewRequest request) async {
  final html = request.html?.trim() ?? '';
  if (html.isEmpty) return null;
  final id = 'ev${++_seq}${DateTime.now().microsecondsSinceEpoch}';
  final doc = prepareWebViewDocument(
    html: html,
    baseUrl: request.url,
    javaScript: request.javaScript,
    sourceRegex: request.sourceRegex,
    proxyImages: true,
    messageId: id,
  );
  final iframe = _document.callMethod('createElement'.toJS, 'iframe'.toJS);
  if (iframe == null) return null;
  final node = iframe as JSObject;
  node.setProperty('srcdoc'.toJS, doc.toJS);
  final styleAny = node.getProperty('style'.toJS);
  if (styleAny != null) {
    final style = styleAny as JSObject;
    style.setProperty('position'.toJS, 'fixed'.toJS);
    style.setProperty('left'.toJS, '-9999px'.toJS);
    style.setProperty('width'.toJS, '1px'.toJS);
    style.setProperty('height'.toJS, '1px'.toJS);
    style.setProperty('opacity'.toJS, '0'.toJS);
    style.setProperty('pointer-events'.toJS, 'none'.toJS);
  }
  final bodyAny = _document.getProperty('body'.toJS);
  if (bodyAny == null) return null;
  final body = bodyAny as JSObject;
  final completer = Completer<WebViewResult?>();
  late final JSFunction handler;
  void onMessage(JSAny event) {
    if (completer.isCompleted) return;
    try {
      final data = (event as JSObject).getProperty('data'.toJS);
      final raw = _jsonStringify(data);
      final map = jsonDecode(raw);
      if (map is! Map) return;
      if (map['type'] != 'chloris-wv-done') return;
      if (map['id']?.toString() != id) return;
      completer.complete(
        WebViewResult(
          body: map['body']?.toString() ?? '',
          url: map['url']?.toString() ?? request.url,
          cookie: map['cookie']?.toString(),
        ),
      );
    } catch (_) {}
  }

  handler = onMessage.toJS;
  _window.callMethod('addEventListener'.toJS, 'message'.toJS, handler);
  body.callMethod('appendChild'.toJS, node);
  try {
    return await completer.future.timeout(
      const Duration(seconds: 18),
      onTimeout: () => null,
    );
  } finally {
    try {
      _window.callMethod('removeEventListener'.toJS, 'message'.toJS, handler);
    } catch (_) {}
    try {
      node.callMethod('remove'.toJS);
    } catch (_) {
      try {
        body.callMethod('removeChild'.toJS, node);
      } catch (_) {}
    }
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
