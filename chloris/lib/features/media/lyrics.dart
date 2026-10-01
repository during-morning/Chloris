import 'dart:convert';

class LyricWord {
  const LyricWord({required this.text, required this.time, this.end});
  final String text;
  final Duration time;
  final Duration? end;
}

class LyricLine {
  const LyricLine({
    required this.text,
    this.time,
    this.end,
    this.translation,
    this.romanization,
    this.words = const [],
  });
  final String text;
  final Duration? time;
  final Duration? end;
  final String? translation;
  final String? romanization;
  final List<LyricWord> words;
  String get original => translation == null ? text : text.split('\n').first;
}

typedef LyricCue = LyricLine;

class LyricDocument {
  const LyricDocument(
    this.lines, {
    this.metadata = const {},
    this.offset = Duration.zero,
  });
  final List<LyricLine> lines;
  final Map<String, String> metadata;
  final Duration offset;
  bool get timed => lines.isNotEmpty && lines.first.time != null;

  static int? _clock(String value) {
    final m = RegExp(
      r'^(?:(\d+):)?(\d+):(\d{1,2})(?:[.,:](\d+))?$',
    ).firstMatch(value.trim());
    if (m == null || int.parse(m[3]!) >= 60) return null;
    return (int.parse(m[1] ?? '0') * 3600 +
                int.parse(m[2]!) * 60 +
                int.parse(m[3]!)) *
            1000 +
        int.parse((m[4] ?? '').padRight(3, '0').substring(0, 3));
  }

  factory LyricDocument.parse(String text) {
    text = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst('\ufeff', '');
    final metadata = <String, String>{};
    for (final m in RegExp(
      r'\[([a-z]+):([^\]]*)\]',
      caseSensitive: false,
    ).allMatches(text)) {
      metadata[m[1]!.toLowerCase()] = m[2]!.trim();
    }
    final offset = int.tryParse(metadata['offset'] ?? '') ?? 0;
    final result = <LyricLine>[];
    Duration at(int ms) =>
        Duration(milliseconds: (ms + offset).clamp(0, 1 << 53));
    if (text.trimLeft().startsWith('{') || text.trimLeft().startsWith('[')) {
      try {
        final raw = jsonDecode(text);
        final list = raw is Map ? raw['lines'] ?? raw['cues'] : raw;
        if (list is List) {
          int ms(Object? v) =>
              v is num ? v.toInt() : _clock('$v') ?? int.tryParse('$v') ?? 0;
          for (final item in list.whereType<Map>()) {
            final words = <LyricWord>[];
            if (item['words'] is List) {
              for (final w in (item['words'] as List).whereType<Map>()) {
                words.add(
                  LyricWord(
                    text: '${w['text'] ?? ''}',
                    time: at(ms(w['start'] ?? w['time'])),
                    end: w['end'] == null ? null : at(ms(w['end'])),
                  ),
                );
              }
              words.sort((a, b) => a.time.compareTo(b.time));
            }
            result.add(
              LyricLine(
                text: '${item['text'] ?? ''}',
                time: item['start'] == null && item['time'] == null
                    ? null
                    : at(ms(item['start'] ?? item['time'])),
                end: item['end'] == null ? null : at(ms(item['end'])),
                translation: item['translation']?.toString(),
                romanization: item['romanization']?.toString(),
                words: List.unmodifiable(words),
              ),
            );
          }
          if (result.isNotEmpty) return _finish(result, metadata, offset);
        }
      } catch (_) {}
    }
    if (text.contains('-->')) {
      for (final block in text.split(RegExp(r'\n\s*\n'))) {
        final rows = block.split('\n');
        final i = rows.indexWhere((l) => l.contains('-->'));
        if (i < 0) continue;
        final range = rows[i].split('-->');
        final start = _clock(range[0]);
        final end = _clock(range[1].trim().split(' ').first);
        if (start == null) continue;
        result.add(
          LyricLine(
            text: rows
                .skip(i + 1)
                .join('\n')
                .replaceAll(RegExp(r'<[^>]+>'), ''),
            time: at(start),
            end: end == null ? null : at(end),
          ),
        );
      }
      return _finish(result, metadata, offset);
    }
    final stamp = RegExp(r'\[(\d+:\d{1,2}(?:[.:]\d+)?)\]');
    final wordStamp = RegExp(r'<(\d+:\d{1,2}(?:[.:]\d+)?)>');
    final plain = <LyricLine>[];
    for (final row in text.split('\n')) {
      final stamps = stamp.allMatches(row).toList();
      final body = row.replaceAll(stamp, '').trim();
      if (stamps.isEmpty) {
        if (body.isNotEmpty &&
            !RegExp(r'^\[[a-z]+:.*\]$', caseSensitive: false).hasMatch(body)) {
          plain.add(LyricLine(text: body));
        }
        continue;
      }
      final wstamps = wordStamp.allMatches(body).toList();
      final words = <LyricWord>[];
      for (var i = 0; i < wstamps.length; i++) {
        final m = wstamps[i];
        final time = _clock(m[1]!);
        if (time == null) continue;
        final label = body.substring(
          m.end,
          i + 1 < wstamps.length ? wstamps[i + 1].start : body.length,
        );
        if (label.isEmpty) continue;
        final end = i + 1 < wstamps.length ? _clock(wstamps[i + 1][1]!) : null;
        words.add(
          LyricWord(
            text: label,
            time: at(time),
            end: end == null ? null : at(end),
          ),
        );
      }
      for (final m in stamps) {
        final time = _clock(m[1]!);
        if (time == null) continue;
        final firstTime = _clock(stamps.first[1]!) ?? time;
        result.add(
          LyricLine(
            text: body.replaceAll(wordStamp, ''),
            time: at(time),
            words: List.unmodifiable([
              for (final w in words)
                LyricWord(
                  text: w.text,
                  time: w.time + Duration(milliseconds: time - firstTime),
                  end: w.end == null
                      ? null
                      : w.end! + Duration(milliseconds: time - firstTime),
                ),
            ]),
          ),
        );
      }
    }
    return result.isEmpty
        ? LyricDocument(List.unmodifiable(plain), metadata: metadata)
        : _finish([...result, ...plain], metadata, offset);
  }

  static LyricDocument _finish(
    List<LyricLine> lines,
    Map<String, String> meta,
    int offset,
  ) {
    final timed = lines.where((l) => l.time != null).toList()
      ..sort((a, b) => a.time!.compareTo(b.time!));
    if (timed.isEmpty) {
      return LyricDocument(
        List.unmodifiable(lines),
        metadata: Map.unmodifiable(meta),
      );
    }
    final merged = <LyricLine>[];
    for (final line in timed) {
      if (merged.isNotEmpty && merged.last.time == line.time) {
        final prev = merged.removeLast();
        final texts = {...prev.text.split('\n'), ...line.text.split('\n')}
          ..remove('');
        merged.add(
          LyricLine(
            text: texts.join('\n'),
            time: prev.time,
            end: prev.end ?? line.end,
            translation:
                prev.translation ??
                line.translation ??
                (line.text != prev.original ? line.text : null),
            romanization: prev.romanization ?? line.romanization,
            words: prev.words.isEmpty ? line.words : prev.words,
          ),
        );
      } else {
        merged.add(line);
      }
    }
    return LyricDocument(
      List.unmodifiable([
        for (var i = 0; i < merged.length; i++)
          LyricLine(
            text: merged[i].text,
            time: merged[i].time,
            end:
                merged[i].end ??
                (i + 1 < merged.length ? merged[i + 1].time : null),
            words: merged[i].words,
            translation: merged[i].translation,
            romanization: merged[i].romanization,
          ),
        ...lines.where((line) => line.time == null),
      ]),
      metadata: Map.unmodifiable(meta),
      offset: Duration(milliseconds: offset),
    );
  }

  int indexAt(Duration position) {
    if (!timed) return -1;
    var low = 0, high = lines.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (lines[middle].time != null && lines[middle].time! <= position) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final index = low - 1;
    if (index >= 0 &&
        lines[index].end != null &&
        position >= lines[index].end! &&
        (index + 1 == lines.length ||
            lines[index + 1].time == null ||
            position < lines[index + 1].time!)) {
      return -1;
    }
    return index;
  }
}
