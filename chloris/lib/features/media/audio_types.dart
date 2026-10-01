import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class MusicOperation {
  MusicOperation({
    Duration timeout = const Duration(seconds: 15),
    String lane = '',
  }) : id =
           'music-${lane.isEmpty ? '' : '$lane-'}${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
       deadline = DateTime.now().add(timeout);
  static int _counter = 0;
  final String id;
  final DateTime deadline;
  bool cancelled = false;
  final List<void Function()> _cancel = [];
  void onCancel(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _cancel.add(callback);
    }
  }

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final f in _cancel) {
      f();
    }
    _cancel.clear();
  }

  void check() {
    if (cancelled) throw const MusicCancelled();
    if (DateTime.now().isAfter(deadline)) {
      cancel();
      throw TimeoutException('音频解析超时');
    }
  }

  Future<T> wait<T>(Future<T> task) async {
    check();
    final result = await task.timeout(
      deadline.difference(DateTime.now()),
      onTimeout: () {
        cancel();
        throw TimeoutException('音频解析超时');
      },
    );
    check();
    return result;
  }
}

class MusicCancelled implements Exception {
  const MusicCancelled();
}

enum TrackOrigin { address, source, local }

class TrackRef {
  const TrackRef({
    required this.id,
    this.origin = TrackOrigin.address,
    this.address,
    this.sourceId,
    this.book,
    this.chapter,
    this.localKey,
    this.title = '',
    this.artist,
    this.album,
    this.variant = 0,
    this.continuous = false,
  });
  static String identity(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  final String id;
  final TrackOrigin origin;
  final String? address, sourceId, localKey, artist, album;
  final String title;
  final int variant;
  final bool continuous;
  final Map<String, dynamic>? book, chapter;
  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin.name,
    'address': address,
    'sourceId': sourceId,
    'book': book,
    'chapter': chapter,
    'localKey': localKey,
    'title': title,
    'artist': artist,
    'album': album,
    'variant': variant,
    'continuous': continuous,
  };
  factory TrackRef.fromJson(Map<String, dynamic> j) => TrackRef(
    id: j['id'] as String,
    origin: TrackOrigin.values.firstWhere(
      (e) => e.name == j['origin'],
      orElse: () => TrackOrigin.address,
    ),
    address: j['address'] as String?,
    sourceId: j['sourceId'] as String?,
    localKey: j['localKey'] as String?,
    book: j['book'] == null
        ? null
        : Map<String, dynamic>.from(j['book'] as Map),
    chapter: j['chapter'] == null
        ? null
        : Map<String, dynamic>.from(j['chapter'] as Map),
    title: j['title'] as String? ?? '',
    artist: j['artist'] as String?,
    album: j['album'] as String?,
    variant: (j['variant'] as num?)?.toInt() ?? 0,
    continuous: j['continuous'] == true,
  );
}

class MediaRequestSpec {
  const MediaRequestSpec({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.mimeType,
    this.operationId,
    this.sourceId,
    this.cookieJar = const {},
  });
  final String url, method;
  final Map<String, String> headers;
  final String? body, mimeType, operationId, sourceId;
  final Map<String, String> cookieJar;
  Map<String, dynamic> toJson() => {
    'url': url,
    'method': method,
    'headers': headers,
    'body': body,
    'mimeType': mimeType,
    'operationId': operationId,
    'sourceId': sourceId,
    'cookieJar': cookieJar,
  };
  factory MediaRequestSpec.fromJson(Map<String, dynamic> j) => MediaRequestSpec(
    url: j['url'] as String,
    method: j['method'] as String? ?? 'GET',
    headers: (j['headers'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v')),
    body: j['body'] as String?,
    mimeType: j['mimeType'] as String?,
    cookieJar: (j['cookieJar'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', '$v'),
    ),
  );
}

class AudioSegment {
  const AudioSegment(this.request, {this.duration});
  final MediaRequestSpec request;
  final Duration? duration;
}

class AudioVariant {
  const AudioVariant({
    required this.label,
    required this.segments,
    this.bitrate,
  });
  final String label;
  final List<AudioSegment> segments;
  final int? bitrate;
}

class ResolvedAudio {
  const ResolvedAudio({
    required this.variants,
    this.lyric,
    this.title,
    this.artist,
    this.coverUrl,
    this.live = false,
    this.expiresAt,
  });
  final List<AudioVariant> variants;
  final String? lyric, title, artist, coverUrl;
  final bool live;
  final DateTime? expiresAt;
}

extension ResolvedAudioJson on ResolvedAudio {
  Map<String, dynamic> toJson() => {
    'version': 1,
    'variants': [
      for (final v in variants)
        {
          'label': v.label,
          'bitrate': v.bitrate,
          'segments': [
            for (final s in v.segments)
              {
                ...s.request.toJson(),
                if (s.duration != null)
                  'durationMs': s.duration!.inMilliseconds,
              },
          ],
        },
    ],
    'title': title,
    'artist': artist,
    'coverUrl': coverUrl,
    'lyric': lyric,
    'live': live,
    'expiresAt': expiresAt?.toIso8601String(),
  };
}
