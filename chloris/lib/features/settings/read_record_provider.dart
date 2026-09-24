import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/persist/kv_settings.dart';

class ReadRecord {
  ReadRecord({
    required this.bookName,
    required this.chapterTitle,
    required this.bookUrl,
    required this.time,
  });

  final String bookName;
  final String chapterTitle;
  final String bookUrl;
  final int time;

  Map<String, dynamic> toJson() => {
        'bookName': bookName,
        'chapterTitle': chapterTitle,
        'bookUrl': bookUrl,
        'time': time,
      };

  factory ReadRecord.fromJson(Map<String, dynamic> json) => ReadRecord(
        bookName: json['bookName']?.toString() ?? '',
        chapterTitle: json['chapterTitle']?.toString() ?? '',
        bookUrl: json['bookUrl']?.toString() ?? '',
        time: (json['time'] as num?)?.toInt() ?? 0,
      );
}

final readRecordProvider =
    NotifierProvider<ReadRecordNotifier, List<ReadRecord>>(
  ReadRecordNotifier.new,
);

class ReadRecordNotifier extends Notifier<List<ReadRecord>> {
  @override
  List<ReadRecord> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString('readRecords');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map((e) => ReadRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(
      'readRecords',
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  void add({
    required String bookName,
    required String chapterTitle,
    required String bookUrl,
  }) {
    state = [
      ReadRecord(
        bookName: bookName,
        chapterTitle: chapterTitle,
        bookUrl: bookUrl,
        time: DateTime.now().millisecondsSinceEpoch,
      ),
      ...state.where((e) => e.bookUrl != bookUrl),
    ].take(100).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  void addAll(Iterable<ReadRecord> list) {
    state = [...list, ...state].take(100).toList();
    _persist();
  }

  /// Drops the read records of one book.
  ///
  /// Without this, deleting a book left its history entries behind forever.
  void removeByBook(String bookUrl) {
    final next = state.where((e) => e.bookUrl != bookUrl).toList();
    if (next.length == state.length) return;
    state = next;
    _persist();
  }
}
