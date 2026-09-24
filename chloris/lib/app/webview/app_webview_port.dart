import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';

import '../../features/sources/interactive_login_page.dart';
import 'webview_factory.dart';

class AppWebViewPort implements WebViewPort {
  AppWebViewPort({
    required this.http,
    required this.cookieStore,
    required this.navigatorKey,
  });

  final HttpPort http;
  final CookieStore cookieStore;
  final GlobalKey<NavigatorState> navigatorKey;

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
    return evaluateInBrowser(request);
  }
}
