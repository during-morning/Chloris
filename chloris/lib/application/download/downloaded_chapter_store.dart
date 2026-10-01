import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../../core/persist/local_document_store.dart';

/// Permanent copy of user-requested downloads. Unlike chapter text cache this
/// store is not part of any cache budget or LRU eviction policy.
class DownloadedChapterStore {
  DownloadedChapterStore._();
  static final DownloadedChapterStore instance = DownloadedChapterStore._();

  String _key(String sourceId, String chapterUrl) =>
      'downloads/${crypto.sha1.convert(utf8.encode('$sourceId\u0000$chapterUrl'))}';

  Future<bool> put(String sourceId, String chapterUrl, String content) =>
      LocalDocumentStore.instance.write(
        _key(sourceId, chapterUrl),
        Uint8List.fromList(utf8.encode(content)),
      );

  Future<String?> get(String sourceId, String chapterUrl) async {
    final bytes = await LocalDocumentStore.instance.read(
      _key(sourceId, chapterUrl),
    );
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> remove(String sourceId, String chapterUrl) =>
      LocalDocumentStore.instance.delete(_key(sourceId, chapterUrl));
}
