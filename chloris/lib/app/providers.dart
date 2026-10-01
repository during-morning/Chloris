import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../application/online/http_online_book_port.dart';
import '../application/online/online_book_port.dart';
import '../application/online/online_reading_use_cases.dart';
import 'router.dart';
import '../core/persist/kv_settings.dart';
import '../core/startup_metrics.dart';
import '../application/sources/source_unify.dart';
import '../engine/engine_facade.dart';
import '../engine/file_port/file_port_factory.dart';
import '../engine/host_environment_app.dart';
import '../engine/online_book_adapter.dart';
import '../engine/js_runtime/js_runtime_factory.dart';
import '../engine/proxy_http_port.dart';
import '../services/web/api_client.dart';
import '../services/web/server_connection.dart';
import 'webview/app_webview_port.dart';

/// 引擎所需 HTTP 端口。Web 走同源服务端代理，避免 CORS。
final httpPortProvider = Provider<HttpPort>((ref) {
  final HttpPort port = kIsWeb
      ? ProxyHttpPort(
          connection: () async {
            final server = await ServerConnection.load();
            return (
              origin: server.isConfigured
                  ? server.normalizedBaseUrl
                  : Uri.base.origin,
              token: server.token,
            );
          },
        )
      : PackageHttpPort();
  ref.onDispose(port.cancelInFlight);
  return port;
});

/// A direct HTTP port, bypassing the same-origin proxy.
///
/// Used to talk to a Chloris server. The proxy exists to reach arbitrary
/// third-party sites from a browser, and its SSRF guard deliberately refuses
/// loopback targets — so routing the API through it would be wrong twice over.
/// The server sends CORS headers for loopback origins, so a direct request
/// works.
final directHttpPortProvider = Provider<HttpPort>((ref) {
  final port = PackageHttpPort();
  ref.onDispose(port.cancelInFlight);
  return port;
});

final cookieStoreProvider = Provider<CookieStore>((ref) {
  final cookies = CookieStore();
  KvSettings.ready().then((p) {
    final raw = p.getString('cookies');
    if (raw == null || raw.isEmpty) return;
    try {
      final map = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
      cookies.load(map);
    } catch (_) {}
  });
  cookies.onChange = (domain, cookie) async {
    final p = await KvSettings.ready();
    await p.setString('cookies', jsonEncode(cookies.snapshot()));
  };
  return cookies;
});

/// engine facade 单例。
final engineFacadeProvider = Provider<EngineFacade>((ref) {
  final http = ref.watch(httpPortProvider);
  final cookies = ref.watch(cookieStoreProvider);
  final hostEnvironment = AppHostEnvironment();
  final jsRuntime = createPlatformJsRuntime();
  final facade = EngineFacade(
    http: http,
    jsRuntime: jsRuntime,
    cookieStore: cookies,
    filePort: createFilePort(),
    hostEnvironment: hostEnvironment,
    webView: AppWebViewPort(
      http: http,
      cookieStore: cookies,
      navigatorKey: appNavigatorKey,
    ),
  );
  ref.onDispose(facade.cancelInFlight);
  ref.onDispose(() => disposePlatformJsRuntime(jsRuntime));
  ref.onDispose(hostEnvironment.dispose);
  return facade;
});

/// Application-layer gateway. Feature providers must depend on this port or
/// one of the use cases below, never on [EngineFacade] directly.
final onlineBookPortProvider = Provider<OnlineBookPort>((ref) {
  // A configured server wins: this is the A3 switch that turns the client into
  // a renderer. Until one is configured the engine keeps working, so the change
  // is additive rather than a flag day.
  final connection = ref.watch(serverConnectionProvider).valueOrNull;
  if (connection != null && connection.isConfigured) {
    return HttpOnlineBookPort(
      ChlorisApiClient(
        transport: httpPortTransport(
          ref.watch(directHttpPortProvider),
          connection.normalizedBaseUrl,
          token: connection.token,
        ),
        token: connection.token,
      ),
      serverToken: connection.token,
    );
  }
  return EngineOnlineBookAdapter(ref.watch(engineFacadeProvider));
});

final searchOnlineBooksUseCaseProvider = Provider<SearchOnlineBooksUseCase>((
  ref,
) {
  return SearchOnlineBooksUseCase(ref.watch(onlineBookPortProvider));
});

final exploreOnlineBooksUseCaseProvider = Provider<ExploreOnlineBooksUseCase>((
  ref,
) {
  return ExploreOnlineBooksUseCase(ref.watch(onlineBookPortProvider));
});

final loadOnlineBookInfoUseCaseProvider = Provider<LoadOnlineBookInfoUseCase>((
  ref,
) {
  return LoadOnlineBookInfoUseCase(ref.watch(onlineBookPortProvider));
});

/// Application-layer gateway for running a source's `loginCheckJs`.
///
/// The login screen must not read [EngineFacade] directly (see the rule above
/// [onlineBookPortProvider]); it reaches the JS runtime through this use case.
final loginCheckUseCaseProvider = Provider<LoginCheckUseCase>((ref) {
  return LoginCheckUseCase(ref.watch(engineFacadeProvider));
});

class LoginCheckUseCase {
  const LoginCheckUseCase(this._facade);

  final EngineFacade _facade;

  Future<Object?> eval(String code, JsScope scope) =>
      _facade.jsRuntime.eval(code, scope);
}

/// Application-layer gateway for cover/content image loading.
///
/// Widgets depend on this use case instead of reaching into [EngineFacade]
/// (or the old free [loadEngineImage] helper) to fetch images.
final engineImageLoaderProvider = Provider<EngineImageLoader>((ref) {
  return EngineImageLoader(ref.watch(engineFacadeProvider));
});

class EngineImageLoader {
  const EngineImageLoader(this._facade);

  final EngineFacade _facade;

  Future<Uint8List> load({
    required String url,
    BookSource? source,
    Book? book,
    bool isCover = true,
  }) => _facade.loadImage(url, source: source, book: book, isCover: isCover);
}

final sourceMediaRequestProvider = Provider<SourceMediaRequest>((ref) {
  return SourceMediaRequest(ref.watch(engineFacadeProvider));
});

class SourceMediaRequest {
  const SourceMediaRequest(this._facade);
  final EngineFacade _facade;

  Future<({String url, Map<String, String> headers})> call(
    String url, {
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    Map<String, String> headers = const {},
  }) => _facade.prepareMediaRequest(
    url,
    source: source,
    book: book,
    chapter: chapter,
    headers: headers,
  );
}

/// 默认书源：从打包资产加载并解析为 [BookSource] 列表。
/// 不同平台用 rootBundle 读取资产。
final defaultSourcesProvider = FutureProvider<List<BookSource>>((ref) async {
  final raw = await ref
      .read(assetLoaderProvider)
      .load('assets/sources/default_book_sources.json');
  final sources = kIsWeb
      ? _parseSourcesList(jsonDecode(raw) as List<dynamic>)
      : await compute(_decodeBookSources, raw);
  StartupMetrics.mark('sources_available');
  return sources;
});

List<BookSource> _decodeBookSources(String raw) =>
    _parseSourcesList(jsonDecode(raw) as List<dynamic>);

/// 可注入的资产读取器，便于测试替换。
final assetLoaderProvider = Provider<AssetLoader>(
  (ref) => const RootBundleAssetLoader(),
);

abstract class AssetLoader {
  Future<String> load(String path);
}

class RootBundleAssetLoader implements AssetLoader {
  const RootBundleAssetLoader();

  @override
  Future<String> load(String path) => rootBundle.loadString(path);
}

List<BookSource> _parseSourcesList(List<dynamic> decoded) {
  final list = BookSource.listFromJson(decoded);
  for (final s in list) {
    final key = canonicalizeSourceUrl(s.bookSourceUrl);
    if (key.isNotEmpty) s.bookSourceUrl = key;
    s.bookSourceGroup = unifySourceGroup(s);
  }
  return list;
}
