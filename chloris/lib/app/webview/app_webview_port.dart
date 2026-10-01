import 'dart:async';
import '../../core/http/http_session.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';

import '../../features/sources/interactive_login_page.dart';
import 'webview_factory.dart';

class AppWebViewPort implements WebViewPort, SessionAwareWebView {
  AppWebViewPort({
    required this.http,
    required this.cookieStore,
    required this.navigatorKey,
  });

  final HttpPort http;
  final CookieStore cookieStore;
  final GlobalKey<NavigatorState> navigatorKey;

  final _waiting = <({String id, String owner, Completer<void> gate})>[];
  final _active = <String, String>{};
  int _sequence = 0;
  void _pump() {
    while (_active.length < 2 && _waiting.isNotEmpty) {
      final job = _waiting.removeAt(0);
      _active[job.id] = job.owner;
      job.gate.complete();
    }
  }

  @override
  void cancelSession(String id) {
    final waiting = _waiting.where((w) => w.owner == id).toList();
    _waiting.removeWhere((w) => w.owner == id);
    for (final w in waiting) {
      w.gate.completeError(StateError('网页解析已取消'));
    }
    for (final entry in _active.entries) {
      if (entry.value == id) unawaited(cancelBrowserSession(entry.key));
    }
  }

  @override
  Future<WebViewResult?> run(WebViewRequest request) async {
    if (request.interactive) {
      final nav = navigatorKey.currentState;
      if (nav == null) return null;
      return nav.push<WebViewResult>(
        MaterialPageRoute(
          builder: (_) => InteractiveLoginPage(
            request: request,
            http: http,
            cookieStore: cookieStore,
          ),
        ),
      );
    }
    final owner =
        HttpSession.current ??
        'browser-${DateTime.now().microsecondsSinceEpoch}';
    final id = '$owner.browser-${_sequence++}';
    final gate = Completer<void>();
    final job = (id: id, owner: owner, gate: gate);
    if (isBackgroundHttpSession(owner)) {
      _waiting.add(job);
    } else {
      final i = _waiting.indexWhere((w) => isBackgroundHttpSession(w.owner));
      _waiting.insert(i < 0 ? _waiting.length : i, job);
    }
    _pump();
    try {
      await gate.future;
      return await HttpSession.bind(id, () => evaluateInBrowser(request));
    } finally {
      _waiting.remove(job);
      _active.remove(id);
      _pump();
    }
  }
}
