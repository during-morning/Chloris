import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/rules/rules_provider.dart';
import '../../features/rss/rss_provider.dart';
import 'app_server_backend.dart';
import 'server.dart';

class WebServiceStatus {
  const WebServiceStatus({
    required this.running,
    required this.port,
    this.token = '',
    this.error,
  });

  final bool running;
  final int port;

  /// Shared secret every request must carry. Empty when stopped.
  ///
  /// The server holds the user's book sources, cookies and WebDAV
  /// credentials, so it no longer answers unauthenticated requests; the UI
  /// must show this value so the user can pair a client.
  final String token;
  final String? error;
}

final webServiceControllerProvider =
    NotifierProvider<WebServiceController, WebServiceStatus>(
      WebServiceController.new,
    );

class WebServiceController extends Notifier<WebServiceStatus> {
  ChlorisServer? _server;

  @override
  WebServiceStatus build() =>
      const WebServiceStatus(running: false, port: 1234);

  Future<void> start() async {
    try {
      final sources = await ref.read(defaultSourcesProvider.future);
      final rules = await ref.read(defaultReplaceRulesProvider.future);
      final rss = ref.read(importedRssSourcesProvider);
      final server = await startServer(
        bookSources: sources,
        replaceRules: rules,
        // Subscription sources travel as JSON: the server must not depend on
        // the RSS feature's model types.
        rssSources: [for (final s in rss) s.toJson()],
        // The shelf, catalogue and content routes go through the same use cases
        // the reader uses, so a client sees what the user sees.
        backend: ref.read(appServerBackendProvider),
        httpPort: state.port,
      );
      _server = server;
      state = WebServiceStatus(
        running: true,
        port: server.port,
        token: server.token,
      );
    } catch (e) {
      state = WebServiceStatus(running: false, port: state.port, error: '$e');
    }
  }

  Future<void> stop() async {
    await _server?.stop();
    _server = null;
    state = WebServiceStatus(running: false, port: state.port);
  }
}
