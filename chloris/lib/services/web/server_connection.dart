import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persist/kv_settings.dart';
import '../persist/credentials.dart';

/// Where a Chloris server lives, when this client is configured to use one.
///
/// Deciding this is what turns the Web build from "runs the engine in a
/// browser" into "renders what a server returns". The address is not a secret
/// and lives in preferences; the token is a secret and lives in the vault.
class ServerConnection {
  const ServerConnection({required this.baseUrl, required this.token});

  /// e.g. `http://127.0.0.1:1234`. Empty means "not configured".
  final String baseUrl;

  final String token;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  static const baseUrlKey = 'serverBaseUrl';

  static Future<ServerConnection> load() async {
    final settings = await KvSettings.ready();
    return ServerConnection(
      baseUrl: settings.getString(baseUrlKey) ?? '',
      token: await CredentialStore.serverToken(),
    );
  }

  static Future<void> save({
    required String baseUrl,
    required String token,
  }) async {
    final settings = await KvSettings.ready();
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      await settings.remove(baseUrlKey);
    } else {
      await settings.setString(baseUrlKey, trimmed);
    }
    await CredentialStore.setServerToken(token.trim());
  }

  /// Strips a trailing slash so `'$baseUrl$path'` never doubles up.
  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

final serverConnectionProvider = FutureProvider<ServerConnection>(
  (ref) => ServerConnection.load(),
);
