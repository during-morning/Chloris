import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';

import 'local_book_service.dart';

/// 加载默认 TXT 目录规则（来自打包资产）。
final tocRulesProvider = FutureProvider<List<TxtTocRule>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/sources/default_txt_toc_rules.json',
  );
  final decoded = jsonDecode(raw) as List<dynamic>;
  return TxtTocRule.listFromJson(decoded);
});

/// 持久化时保留原始格式；MOBI 与 KF8 共用 `mobi` 读取分支。
String localBundleKind(LocalBookBundle bundle) {
  if (bundle.isPdf) return 'pdf';
  if (bundle.umdTexts != null) return 'umd';
  if (bundle.epub != null) return 'epub';
  final format = bundle.document?.format;
  if (format == LocalDocumentFormat.mobi || format == LocalDocumentFormat.kf8) {
    return 'mobi';
  }
  return 'txt';
}

/// 本地书架：导入后尽量写入本机（Web 有体积上限）。
final localShelfProvider =
    NotifierProvider<LocalShelfNotifier, List<LocalBookBundle>>(
      LocalShelfNotifier.new,
    );

class LocalShelfNotifier extends Notifier<List<LocalBookBundle>> {
  static const _key = 'localShelfV1';

  /// localStorage 友好上限（约 1.2MB 原文）。
  static const _maxBytes = 1200 * 1024;

  @override
  List<LocalBookBundle> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <LocalBookBundle>[];
      final rules = await ref.read(tocRulesProvider.future);
      final svc = LocalBookService(tocRules: rules);
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final kind = m['kind']?.toString() ?? 'txt';
        final b64 = m['bytes']?.toString() ?? '';
        if (b64.isEmpty) continue;
        final bytes = Uint8List.fromList(base64Decode(b64));
        final name = m['name']?.toString();
        final fileName = m['fileName']?.toString();
        final LocalBookBundle bundle;
        if (kind == 'epub') {
          bundle = svc.parseEpub(bytes, fileName: fileName, overrideName: name);
        } else if (kind == 'pdf') {
          bundle = svc.parsePdf(bytes, fileName: fileName, overrideName: name);
        } else if (kind == 'umd') {
          bundle = svc.parseUmd(bytes, fileName: fileName, overrideName: name);
        } else if (kind == 'mobi') {
          bundle = svc.parseMobi(bytes, fileName: fileName, overrideName: name);
        } else {
          bundle = svc.parseTxt(bytes, fileName: fileName, overrideName: name);
        }
        // 恢复原 bookUrl，避免重复。
        final url = m['bookUrl']?.toString();
        if (url != null && url.isNotEmpty) {
          bundle.book.bookUrl = url;
        }
        out.add(bundle);
      }
      if (out.isNotEmpty) state = out;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    final rows = <Map<String, dynamic>>[];
    for (final b in state) {
      final bytes = b.rawBytes;
      if (bytes == null || bytes.length > _maxBytes) continue;
      rows.add({
        'bookUrl': b.book.bookUrl,
        'name': b.book.name,
        'fileName': b.book.originName,
        'kind': localBundleKind(b),
        'bytes': base64Encode(bytes),
      });
    }
    await p.setString(_key, jsonEncode(rows));
  }

  void add(LocalBookBundle bundle) {
    final existing = state.indexWhere(
      (b) => b.book.bookUrl == bundle.book.bookUrl,
    );
    if (existing >= 0) {
      final next = [...state]..[existing] = bundle;
      state = next;
    } else {
      state = [...state, bundle];
    }
    _persist();
  }

  void remove(String bookUrl) {
    state = state.where((b) => b.book.bookUrl != bookUrl).toList();
    _persist();
  }

  void top(String bookUrl) {
    final i = state.indexWhere((b) => b.book.bookUrl == bookUrl);
    if (i <= 0) return;
    final item = state[i];
    state = [item, ...state.where((b) => b.book.bookUrl != bookUrl)];
    _persist();
  }
}
