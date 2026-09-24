import 'dart:async';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';

import '../../app/providers.dart';
import '../../application/rss/rss_models.dart';
import '../../features/rss/rss_provider.dart';
import '../../features/sources/source_library_provider.dart';
import 'deep_link_service.dart';

/// 订阅系统深链，接收 `legado://import/*` 并尝试导入书源。
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) {
      final q = Uri.base.queryParameters['import'];
      if (q != null && q.isNotEmpty) {
        _importBookSource(q);
      }
      final rss = Uri.base.queryParameters['rss'];
      if (rss != null && rss.isNotEmpty) {
        _importRss(rss);
      }
      return;
    }
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handle(initial.toString());
    } catch (_) {}
    try {
      _sub = appLinks.uriLinkStream.listen(
        (uri) => _handle(uri.toString()),
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _handle(String uri) {
    final req = parseLegadoImport(uri);
    if (req == null || req.type != ImportType.bookSource) return;
    _importBookSource(req.src);
  }

  Future<void> _importBookSource(String src) async {
    if (!src.startsWith('http')) return;
    try {
      final res = await ref
          .read(httpPortProvider)
          .send(HttpRequestSpec(url: src));
      final sources = BookSource.listFromJson(jsonDecode(res.body ?? '[]'));
      if (sources.isEmpty) return;
      ref.read(importedSourcesProvider.notifier).addAll(sources);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('已通过深链导入 ${sources.length} 条书源')));
    } catch (_) {}
  }

  Future<void> _importRss(String src) async {
    if (!src.startsWith('http')) return;
    try {
      final res = await ref
          .read(httpPortProvider)
          .send(HttpRequestSpec(url: src));
      final list = RssSource.listFromJson(jsonDecode(res.body ?? '[]'));
      if (list.isEmpty) return;
      ref.read(importedRssSourcesProvider.notifier).addAll(list);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('已导入订阅源 ' + list.length.toString() + ' 条')),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
