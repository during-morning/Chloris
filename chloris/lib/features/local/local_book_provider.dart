import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../core/persist/kv_settings.dart';
import '../../core/persist/blob_store.dart';
import '../../core/persist/local_document_store.dart';
import '../../core/persist/app_db.dart';
import '../../core/startup_metrics.dart';
import '../../data/database/app_database.dart' as db;
import 'local_book_service.dart';

final tocRulesProvider = FutureProvider<List<TxtTocRule>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/sources/default_txt_toc_rules.json',
  );
  return TxtTocRule.listFromJson(jsonDecode(raw));
});

String localBundleKind(LocalBookBundle bundle) {
  if (bundle.isPdf || bundle.format == LocalDocumentFormat.pdf) return 'pdf';
  if (bundle.isUmd || bundle.umdTexts != null) return 'umd';
  final format = bundle.document?.format ?? bundle.format;
  if (format == LocalDocumentFormat.epub) return 'epub';
  if (format == LocalDocumentFormat.mobi || format == LocalDocumentFormat.kf8) {
    return 'mobi';
  }
  return 'txt';
}

final localShelfProvider =
    NotifierProvider<LocalShelfNotifier, List<LocalBookBundle>>(
      LocalShelfNotifier.new,
    );

/// The shelf retains descriptors only. Original files and per-chapter text are
/// durable files, loaded on demand when the user opens a book or chapter.
class LocalShelfNotifier extends Notifier<List<LocalBookBundle>> {
  static const _key = 'localShelfV1';
  final Map<String, Future<void>> _legacyMigrations = {};
  final List<Map<String, dynamic>> _unmigratedRows = [];

  @override
  List<LocalBookBundle> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final database = AppDb.current;
    final stored = database == null
        ? const <db.LocalBookDescriptor>[]
        : await (database.select(database.localBookDescriptors)..orderBy([
                (row) => drift.OrderingTerm(expression: row.customOrder),
              ]))
              .get();
    final fromDatabase = stored.isNotEmpty;
    final raw = fromDatabase
        ? jsonEncode([for (final row in stored) jsonDecode(row.metadata)])
        : p.getString(_key);
    if (raw == null || raw.isEmpty) {
      StartupMetrics.mark('shelf_available');
      return;
    }
    _unmigratedRows.clear();
    try {
      final rows = jsonDecode(raw) as List<dynamic>;
      final out = <LocalBookBundle>[];
      var migrated = false;
      for (final value in rows) {
        if (value is! Map) continue;
        final row = Map<String, dynamic>.from(value);
        if (row['chapters'] is List) {
          out.add(_descriptorFromRow(row));
          continue;
        }
        // Migrate pre-descriptor shelf rows lazily with parsing off the UI
        // isolate, then persist chapter files before dropping the old record.
        final bytes = await _readLegacyBytes(row);
        if (bytes == null || bytes.isEmpty) {
          _unmigratedRows.add(row);
          continue;
        }
        try {
          final bundle = await _parseBytes(
            bytes,
            kind: row['kind']?.toString() ?? 'txt',
            fileName: row['fileName']?.toString() ?? 'book.txt',
            overrideName: row['name']?.toString(),
            bookUrl: row['bookUrl']?.toString(),
          );
          await _persistFiles(bundle);
          out.add(_descriptor(bundle));
          migrated = true;
        } catch (_) {
          _unmigratedRows.add(row);
        }
      }
      state = out;
      StartupMetrics.mark('shelf_available');
      if (!fromDatabase || migrated) await _persistMetadata();
    } catch (_) {
      StartupMetrics.mark('shelf_available');
    }
  }

  LocalBookBundle _descriptorFromRow(Map<String, dynamic> row) {
    final bookData = row['book'] is Map
        ? Map<String, dynamic>.from(row['book'] as Map)
        : <String, dynamic>{
            'bookUrl': row['bookUrl'],
            'name': row['name'],
            'originName': row['fileName'],
            'origin': BookType.localTag,
            'type': BookType.local | BookType.text,
          };
    final book = Book.fromJson(bookData);
    final chapters = (row['chapters'] as List<dynamic>)
        .whereType<Map>()
        .map(
          (chapter) => BookChapter.fromJson(Map<String, dynamic>.from(chapter)),
        )
        .toList(growable: false);
    for (final chapter in chapters) {
      chapter.bookUrl = book.bookUrl;
    }
    final kind = row['kind']?.toString() ?? 'txt';
    final format = switch (kind) {
      'pdf' => LocalDocumentFormat.pdf,
      'epub' => LocalDocumentFormat.epub,
      'mobi' => LocalDocumentFormat.mobi,
      'txt' => LocalDocumentFormat.txt,
      _ => null,
    };
    return LocalBookBundle(
      book: book,
      chapters: chapters,
      document: null,
      isPdf: kind == 'pdf',
      isUmd: kind == 'umd',
      format: format,
      htmlDocument: row['isHtml'] == true,
    );
  }

  LocalBookBundle _descriptor(LocalBookBundle bundle) => LocalBookBundle(
    book: bundle.book,
    chapters: bundle.chapters,
    document: null,
    isPdf: bundle.isPdf,
    isUmd: bundle.isUmd || bundle.umdTexts != null,
    format: bundle.document?.format ?? bundle.format,
    htmlDocument: bundle.isHtml,
  );

  Future<Uint8List?> _readLegacyBytes(Map<String, dynamic> row) async {
    final key =
        row['blobKey']?.toString() ??
        _legacyBlobKey(row['bookUrl']?.toString() ?? '');
    final stored = await BlobStore.instance.get(key);
    if (stored != null && stored.isNotEmpty) return stored;
    final legacy = row['bytes']?.toString() ?? '';
    if (legacy.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(legacy));
    } catch (_) {
      return null;
    }
  }

  Future<LocalBookBundle> _parseBytes(
    Uint8List bytes, {
    required String kind,
    required String fileName,
    String? overrideName,
    String? bookUrl,
  }) async {
    final rules = await ref.read(tocRulesProvider.future);
    final parsed = await compute(parseLocalDocumentWorker, {
      'bytes': bytes,
      'kind': kind,
      'fileName': fileName,
      'name': overrideName,
      'tocRules': rules.map((rule) => rule.toJson()).toList(growable: false),
    });
    final book = Book.fromJson(
      Map<String, dynamic>.from(parsed['book']! as Map),
    );
    if (bookUrl != null && bookUrl.isNotEmpty) book.bookUrl = bookUrl;
    final chapters = (parsed['chapters']! as List<dynamic>)
        .whereType<Map>()
        .map((chapter) {
          final value = BookChapter.fromJson(
            Map<String, dynamic>.from(chapter),
          );
          value.bookUrl = book.bookUrl;
          return value;
        })
        .toList(growable: false);
    final contents = Map<String, dynamic>.from(
      parsed['contents']! as Map,
    ).map((key, value) => MapEntry(key, value?.toString() ?? ''));
    final parsedKind = parsed['kind']?.toString() ?? kind;
    return LocalBookBundle(
      book: book,
      chapters: chapters,
      document: null,
      rawBytes: bytes,
      isPdf: parsed['isPdf'] == true,
      isUmd: parsedKind == 'umd',
      htmlDocument: parsed['isHtml'] == true,
      format: switch (parsedKind) {
        'pdf' => LocalDocumentFormat.pdf,
        'epub' => LocalDocumentFormat.epub,
        'mobi' => LocalDocumentFormat.mobi,
        'txt' => LocalDocumentFormat.txt,
        _ => null,
      },
      chapterContent: contents,
    );
  }

  Future<void> _persistFiles(LocalBookBundle bundle) async {
    final bytes = bundle.rawBytes;
    if (bytes != null &&
        !await LocalDocumentStore.instance.write(
          _rawKey(bundle.book.bookUrl),
          bytes,
        )) {
      throw StateError('无法保存本地书文件');
    }
    final contents = bundle.chapterContent;
    if (contents == null) {
      for (final chapter in bundle.chapters) {
        final text = bundle.content(chapter);
        if (text.isEmpty) continue;
        final ok = await LocalDocumentStore.instance.write(
          _chapterKey(bundle.book.bookUrl, chapter),
          Uint8List.fromList(utf8.encode(text)),
        );
        if (!ok) throw StateError('无法保存章节 ${chapter.title}');
      }
    } else {
      final entries = contents.entries.toList(growable: false);
      for (var i = 0; i < entries.length; i += 16) {
        final batch = entries.skip(i).take(16);
        final results = await Future.wait([
          for (final entry in batch)
            LocalDocumentStore.instance.write(
              _chapterKeyByUrl(bundle.book.bookUrl, entry.key),
              Uint8List.fromList(utf8.encode(entry.value)),
            ),
        ]);
        if (results.any((ok) => !ok)) throw StateError('无法保存本地书章节');
      }
    }
  }

  Future<void> _persistMetadata() async {
    final p = await KvSettings.ready();
    final rows = <Map<String, dynamic>>[
      for (final bundle in state)
        {
          'book': bundle.book.toJson(),
          'bookUrl': bundle.book.bookUrl,
          'fileName': bundle.book.originName,
          'kind': localBundleKind(bundle),
          'isHtml': bundle.isHtml,
          'chapters': [for (final chapter in bundle.chapters) chapter.toJson()],
        },
      ..._unmigratedRows,
    ];
    final database = AppDb.current;
    if (database != null) {
      await database.transaction(() async {
        await database.delete(database.localBookDescriptors).go();
        for (var i = 0; i < rows.length; i++) {
          await database
              .into(database.localBookDescriptors)
              .insertOnConflictUpdate(
                db.LocalBookDescriptorsCompanion.insert(
                  bookUrl: rows[i]['bookUrl']! as String,
                  metadata: jsonEncode(rows[i]),
                  customOrder: drift.Value(i),
                ),
              );
        }
      });
      final written = await database
          .select(database.localBookDescriptors)
          .get();
      if (written.length != rows.length ||
          written.any((row) => jsonDecode(row.metadata) is! Map)) {
        throw StateError('无法验证本地书架元数据');
      }
      await p.remove(_key);
      return;
    }
    await p.setString(_key, jsonEncode(rows));
  }

  void add(LocalBookBundle bundle) {
    unawaited(addAndPersist(bundle));
  }

  Future<void> addAndPersist(LocalBookBundle bundle) async {
    await _persistFiles(bundle);
    _setBundle(bundle);
    await _persistMetadata();
  }

  void _setBundle(LocalBookBundle bundle) {
    final descriptor = _descriptor(bundle);
    final existing = state.indexWhere(
      (b) => b.book.bookUrl == descriptor.book.bookUrl,
    );
    if (existing >= 0) {
      state = [...state]..[existing] = descriptor;
    } else {
      state = [...state, descriptor];
    }
  }

  Future<Uint8List?> readOriginal(LocalBookBundle bundle) async {
    final bytes = await LocalDocumentStore.instance.read(
      _rawKey(bundle.book.bookUrl),
    );
    if (bytes != null) return bytes;
    return BlobStore.instance.get(_legacyBlobKey(bundle.book.bookUrl));
  }

  Future<String> readChapter(
    LocalBookBundle bundle,
    BookChapter chapter,
  ) async {
    final raw = await LocalDocumentStore.instance.read(
      _chapterKey(bundle.book.bookUrl, chapter),
    );
    if (raw != null) return utf8.decode(raw, allowMalformed: true);
    final pending = _legacyMigrations.putIfAbsent(
      bundle.book.bookUrl,
      () => _migrateLegacyBundle(bundle),
    );
    try {
      await pending;
    } finally {
      _legacyMigrations.remove(bundle.book.bookUrl);
    }
    final migrated = await LocalDocumentStore.instance.read(
      _chapterKey(bundle.book.bookUrl, chapter),
    );
    return migrated == null ? '' : utf8.decode(migrated, allowMalformed: true);
  }

  Future<void> _migrateLegacyBundle(LocalBookBundle bundle) async {
    final bytes = await readOriginal(bundle);
    if (bytes == null) return;
    final parsed = await _parseBytes(
      bytes,
      kind: localBundleKind(bundle),
      fileName: bundle.book.originName,
      overrideName: bundle.book.name,
      bookUrl: bundle.book.bookUrl,
    );
    await _persistFiles(parsed);
  }

  Future<LocalBookBundle> loadForExport(LocalBookBundle bundle) async {
    final content = <String, String>{};
    for (final chapter in bundle.chapters) {
      content[chapter.url] = await readChapter(bundle, chapter);
    }
    return LocalBookBundle(
      book: bundle.book,
      chapters: bundle.chapters,
      document: null,
      isPdf: bundle.isPdf,
      isUmd: bundle.isUmd,
      format: bundle.format,
      htmlDocument: bundle.isHtml,
      chapterContent: content,
    );
  }

  Future<void> remove(String bookUrl) async {
    final removed = state.where((bundle) => bundle.book.bookUrl == bookUrl);
    state = state.where((bundle) => bundle.book.bookUrl != bookUrl).toList();
    for (final bundle in removed) {
      await LocalDocumentStore.instance.delete(_rawKey(bookUrl));
      for (final chapter in bundle.chapters) {
        await LocalDocumentStore.instance.delete(_chapterKey(bookUrl, chapter));
      }
    }
    await BlobStore.instance.remove(_legacyBlobKey(bookUrl));
    await _persistMetadata();
  }

  void top(String bookUrl) {
    final i = state.indexWhere((b) => b.book.bookUrl == bookUrl);
    if (i <= 0) return;
    final item = state[i];
    state = [item, ...state.where((b) => b.book.bookUrl != bookUrl)];
    unawaited(_persistMetadata());
  }
}

String _bookId(String bookUrl) =>
    crypto.sha1.convert(utf8.encode(bookUrl)).toString();
String _rawKey(String bookUrl) => '${_bookId(bookUrl)}/source';
String _chapterKey(String bookUrl, BookChapter chapter) =>
    _chapterKeyByUrl(bookUrl, chapter.url);
String _chapterKeyByUrl(String bookUrl, String chapterUrl) =>
    '${_bookId(bookUrl)}/chapter/${crypto.sha1.convert(utf8.encode(chapterUrl))}';
String _legacyBlobKey(String bookUrl) =>
    'local-book/${crypto.sha1.convert(utf8.encode(bookUrl))}';
