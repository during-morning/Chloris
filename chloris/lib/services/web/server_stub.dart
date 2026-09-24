import 'package:chloris_engine/chloris_engine.dart';

import 'server_backend.dart';

/// Web 服务仅在 IO 平台可用。本文件是 Web 端的替身，因此刻意不引用任何
/// `dart:io` 类型（[server_io.dart] 里的 `InternetAddress` 等）。
class ChlorisServer {
  const ChlorisServer({
    this.token = '',
    this.rssSources = const [],
    this.backend,
    this.appVersion = '0.1.0',
  });

  /// 与 IO 实现同名，Web 端恒为空串。
  final String token;
  final List<Map<String, dynamic>> rssSources;
  final ServerBackend? backend;
  final String appVersion;

  int get port => 0;
  int get webSocketPort => 0;

  Future<void> start({int httpPort = 1234, int wsPort = 1235}) async {
    throw UnsupportedError('Web 服务仅在 IO 平台可用');
  }

  Future<void> stop() async {}
}

String generateServerToken() => '';

/// Web 端不承载代理，因此没有可拦截的目标；保留同名 API 以便共享代码编译。
bool isBlockedProxyHost(String host, {bool allowPrivate = false}) => false;

String? proxyTargetError(String url, {bool allowPrivate = false}) => null;

bool isLoopbackOrigin(String origin) => false;

bool constantTimeEquals(String a, String b) => a == b;

Future<ChlorisServer> startServer({
  required List<BookSource> bookSources,
  required List<ReplaceRule> replaceRules,
  int httpPort = 1234,
  int wsPort = 1235,
  String? token,
  bool allowPrivateProxyTargets = false,
  List<Map<String, dynamic>> rssSources = const [],
  ServerBackend? backend,
  String appVersion = '0.1.0',
}) async {
  return const ChlorisServer();
}
