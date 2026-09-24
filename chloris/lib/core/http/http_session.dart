import 'dart:async';

/// Zone-scoped HTTP session. Engine calls stay unchanged; ports read [current].
class HttpSession {
  HttpSession._();

  static const token = #chlorisHttpSession;

  static String? get current => Zone.current[token] as String?;

  static Future<T> bind<T>(String id, Future<T> Function() body) {
    return runZoned(body, zoneValues: {token: id});
  }
}
