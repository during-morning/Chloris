import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/persist/kv_settings.dart';
import '../../core/persist/app_db.dart';
import '../../core/persist/persist_queue.dart';
import '../../data/database/app_database.dart';

import '../../services/persist/vault_sync.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.bookUrl,
    required this.chapterIndex,
    this.chapterTitle = '',
    this.chapterPos = 0,
    this.updatedAt = 0,
  });

  final String bookUrl;
  final int chapterIndex;
  final String chapterTitle;
  final int chapterPos;
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'bookUrl': bookUrl,
        'chapterIndex': chapterIndex,
        'chapterTitle': chapterTitle,
        'chapterPos': chapterPos,
        'updatedAt': updatedAt,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        bookUrl: json['bookUrl']?.toString() ?? '',
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        chapterTitle: json['chapterTitle']?.toString() ?? '',
        chapterPos: (json['chapterPos'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

final readingProgressProvider = NotifierProvider<ReadingProgressNotifier,
    Map<String, ReadingProgress>>(ReadingProgressNotifier.new);

class ReadingProgressNotifier
    extends Notifier<Map<String, ReadingProgress>> {
  static const _key = 'readingProgressV1';

  @override
  Map<String, ReadingProgress> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    final out = <String, ReadingProgress>{};
    final p = await KvSettings.ready();
    final raw = p.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          if (e.value is Map) {
            out[e.key] = ReadingProgress.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            );
          }
        }
      } catch (_) {}
    }
    final d = await AppDb.open();
    if (d != null) {
      try {
        final rows = await d.select(d.books).get();
        for (final r in rows) {
          if (r.durChapterIndex <= 0 &&
              r.durChapterPos <= 0 &&
              (r.durChapterTitle == null || r.durChapterTitle!.isEmpty)) {
            continue;
          }
          out.putIfAbsent(
            r.bookUrl,
            () => ReadingProgress(
              bookUrl: r.bookUrl,
              chapterIndex: r.durChapterIndex,
              chapterTitle: r.durChapterTitle ?? '',
              chapterPos: r.durChapterPos,
              updatedAt: r.lastReadTime,
            ),
          );
        }
      } catch (_) {}
    }
    if (out.isNotEmpty) state = out;
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(
      _key,
      jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await syncVaultFromPrefs();
    PersistQueue.instance.schedule('progress.drift', _persistDrift);
  }

  Future<void> _persistDrift() async {
    final d = await AppDb.open();
    if (d == null) return;
    try {
      for (final v in state.values) {
        // Update only. This used to insert a row named after the bookUrl when
        // the book was not on the shelf, which left permanent junk rows whose
        // "name" was a URL. KV is the source of truth for progress, so a book
        // with no shelf row simply has nothing to mirror into.
        await (d.update(d.books)..where((t) => t.bookUrl.equals(v.bookUrl)))
            .write(
          BooksCompanion(
            durChapterIndex: Value(v.chapterIndex),
            durChapterTitle: Value(v.chapterTitle),
            durChapterPos: Value(v.chapterPos),
            lastReadTime: Value(v.updatedAt),
          ),
        );
      }
    } catch (_) {}
  }

  void save({
    required String bookUrl,
    required int chapterIndex,
    String chapterTitle = '',
    int chapterPos = 0,
  }) {
    if (bookUrl.isEmpty) return;
    final next = Map<String, ReadingProgress>.from(state);
    next[bookUrl] = ReadingProgress(
      bookUrl: bookUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterPos: chapterPos,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    state = next;
    _persist();
  }

  ReadingProgress? of(String bookUrl) => state[bookUrl];

  /// Drops the stored progress for one book.
  ///
  /// Deleting a book used to leave its progress behind forever because this
  /// notifier had no removal path at all.
  Future<void> remove(String bookUrl) async {
    if (bookUrl.isEmpty || !state.containsKey(bookUrl)) return;
    final next = Map<String, ReadingProgress>.from(state)..remove(bookUrl);
    state = next;
    await _persist();
  }

  /// Drops every stored progress entry.
  Future<void> removeAll() async {
    if (state.isEmpty) return;
    state = const {};
    await _persist();
  }
}
