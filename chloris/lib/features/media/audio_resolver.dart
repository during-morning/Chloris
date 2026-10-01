import 'dart:convert';
import 'package:chloris_engine/chloris_engine.dart';
import '../../engine/engine_facade.dart';
import '../../application/online/online_book_port.dart';
import '../../core/http/http_session.dart';
import 'audio_types.dart';
import 'media_resource.dart';

class AudioSelectionRequired implements Exception {
  const AudioSelectionRequired(this.choices);
  final List<String> choices;
  @override
  String toString() => '请选择曲目、连续分段或音质';
}

/// A chapter string array is one continuous track. An arbitrary array requires
/// an explicit choice instead of silently discarding all but its first item.
ResolvedAudio parseAudio(
  String input, {
  String? baseUrl,
  bool chapter = false,
  Map<String, String> headers = const {},
}) {
  Object? json;
  try {
    json = jsonDecode(input);
  } catch (_) {}
  List<AudioSegment> segments(Object? items) {
    if (items is! List) return const [];
    return [for (final item in items) _segment(item, baseUrl, headers)];
  }

  if (json is List && json.isEmpty) throw const FormatException('音频列表为空');
  if (json is List && !json.every((e) => e is String)) {
    throw AudioSelectionRequired([for (final item in json) jsonEncode(item)]);
  }
  if (json is List && json.every((e) => e is String)) {
    if (!chapter) throw AudioSelectionRequired(json.cast<String>());
    return ResolvedAudio(
      variants: [AudioVariant(label: '原始音质', segments: segments(json))],
    );
  }
  if (json is Map) {
    Object? nestedTracks(Object? value) {
      if (value is! Map) return null;
      final direct = value['songs'] ?? value['tracks'];
      if (direct is List) return direct;
      for (final child in value.values) {
        if (child is Map) {
          final found = nestedTracks(child);
          if (found != null) return found;
        }
      }
      return null;
    }

    final tracks = nestedTracks(json);
    if (tracks is List) {
      throw AudioSelectionRequired([for (final t in tracks) jsonEncode(t)]);
    }
    final extra = mergeMediaHeaders(headers, _map(json['headers']));
    if (json['segments'] is List || json['variants'] is List) {
      final vars = <AudioVariant>[];
      if (json['variants'] is List) {
        for (final v in (json['variants'] as List).whereType<Map>()) {
          final raw = v['segments'];
          vars.add(
            AudioVariant(
              label: '${v['label'] ?? v['quality'] ?? '原始音质'}',
              bitrate: (v['bitrate'] as num?)?.toInt(),
              segments: raw is List
                  ? [for (final s in raw) _segment(s, baseUrl, extra)]
                  : [_segment(v, baseUrl, extra)],
            ),
          );
        }
      } else {
        vars.add(
          AudioVariant(
            label: '原始音质',
            segments: [
              for (final s in json['segments'] as List)
                _segment(s, baseUrl, extra),
            ],
          ),
        );
      }
      if (vars.isEmpty || vars.any((v) => v.segments.isEmpty)) {
        throw const FormatException('音频分段为空');
      }
      return ResolvedAudio(
        variants: vars,
        lyric: json['lyric']?.toString(),
        title: json['title']?.toString(),
        artist: json['artist']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        live: json['live'] == true,
      );
    }
  }
  final r = parseMediaResource(input, baseUrl: baseUrl, headers: headers);
  if (r == null) throw const FormatException('未找到音频资源');
  return ResolvedAudio(
    variants: [
      AudioVariant(
        label: '原始音质',
        segments: [
          _segment(
            json is Map &&
                    (json['method'] != null || json['body'] != null) &&
                    (json['url'] != null ||
                        json['src'] != null ||
                        json['audioUrl'] != null)
                ? json
                : r.ruleUrl ?? r.url,
            baseUrl,
            r.headers,
          ),
        ],
      ),
    ],
    title: r.title,
    artist: r.artist,
    coverUrl: r.coverUrl,
    lyric: r.lyric,
  );
}

Map<String, String> _map(Object? raw) =>
    raw is Map ? raw.map((k, v) => MapEntry('$k', '$v')) : {};
AudioSegment _segment(Object? raw, String? base, Map<String, String> headers) {
  final map = raw is Map ? raw : null;
  var text = map == null
      ? '$raw'
      : '${map['url'] ?? map['src'] ?? map['audioUrl'] ?? ''}';
  var method = '${map?['method'] ?? 'GET'}'.toUpperCase();
  String? body = map?['body']?.toString();
  final start = RegExp(r',\s*\{').firstMatch(text);
  var extra = <String, String>{};
  if (start != null) {
    final options = jsonDecode(text.substring(start.start + 1));
    if (options is Map) {
      method = '${options['method'] ?? method}'.toUpperCase();
      body = options['body']?.toString() ?? body;
      extra = _map(options['headers']);
    }
    text = text.substring(0, start.start);
  }
  final parsed = parseMediaResource(
    text,
    baseUrl: base,
    headers: mergeMediaHeaders(
      headers,
      mergeMediaHeaders(_map(map?['headers']), extra),
    ),
  );
  if (parsed == null) throw const FormatException('音频分段地址无效');
  return AudioSegment(
    MediaRequestSpec(
      url: parsed.url,
      method: method,
      body: body,
      headers: parsed.headers,
      mimeType: map?['mimeType']?.toString(),
    ),
    duration: map?['durationMs'] is num
        ? Duration(milliseconds: (map!['durationMs'] as num).toInt())
        : null,
  );
}

class AudioResolver {
  AudioResolver({
    required this.http,
    required this.engine,
    required this.port,
    required this.findSource,
  });
  final HttpPort http;
  final EngineFacade engine;
  final OnlineBookPort port;
  final Future<BookSource?> Function(String) findSource;

  Future<ResolvedAudio> _resolveWebPage(
    MediaRequestSpec request,
    MusicOperation operation, {
    String? html,
  }) async {
    final view = engine.webView!;
    final response = await view.run(
      WebViewRequest(
        url: request.url,
        html: html,
        headers: request.headers,
        sourceRegex:
            r'\.([mM][pP]3|[mM]4[aA]|[aA][aA][cC]|[fF][lL][aA][cC]|[oO][gG][gG]|[oO][pP][uU][sS]|[wW][aA][vV]|[wW][mM][aA]|[mM]3[uU]8)([?#]|$)',
        javaScript:
            r'''new Promise(resolve => {const read=()=>Array.from(document.querySelectorAll('audio,source,video')).map(n=>n.currentSrc||n.src).find(Boolean);const first=read();if(first){resolve(first);return;}const observer=new MutationObserver(()=>{const url=read();if(url){observer.disconnect();resolve(url);}});observer.observe(document,{subtree:true,childList:true,attributes:true,attributeFilter:['src']});})''',
      ),
    );
    operation.check();
    if (response == null || response.body.isEmpty) {
      throw const FormatException('网页未提供可播放音频，请检查登录或书源规则');
    }
    if (response.cookie?.isNotEmpty == true) {
      engine.cookieStore.set(response.url, response.cookie!);
    }
    if (response.body.trim().startsWith('blob:')) {
      throw const FormatException('页面使用无法导出的 blob／MSE 音频，请选择原始媒体地址；不支持 DRM');
    }
    final captured = parseAudio(
      response.body,
      baseUrl: response.url,
      chapter: true,
      headers: request.headers,
    );
    if (captured.variants.any(
      (v) => v.segments.any((s) => s.request.url.startsWith('blob:')),
    )) {
      throw const FormatException('网页 blob／MSE 音频无法导出，请提供原始媒体地址；不支持 DRM');
    }
    return captured;
  }

  Future<ResolvedAudio> resolve(
    TrackRef ref,
    MusicOperation operation, {
    String? contentOverride,
  }) async {
    operation.onCancel(() => engine.cancelSession(operation.id));
    return operation.wait(
      HttpSession.bind(operation.id, () async {
        String input = ref.address ?? '';
        BookSource? source;
        Book? book;
        BookChapter? chapter;
        if (ref.origin == TrackOrigin.source) {
          source = await findSource(ref.sourceId ?? '');
          if (source == null) throw const FormatException('音乐书源已删除，请重新导入书源');
          book = Book.fromJson(ref.book!);
          chapter = BookChapter.fromJson(ref.chapter!);
          operation.onCancel(() => port.cancelSession(operation.id));
          input =
              contentOverride ??
              await port.loadChapterContent(source, book, chapter);
          operation.check();
        }
        ResolvedAudio parsed;
        try {
          parsed = parseAudio(
            input,
            baseUrl: chapter?.baseUrl.isNotEmpty == true
                ? chapter!.baseUrl
                : chapter?.url,
            chapter: chapter != null || ref.continuous,
          );
        } on FormatException {
          if (ref.origin != TrackOrigin.address ||
              engine.webView == null ||
              !RegExp(
                r'<(?:html|script|audio|body)\b',
                caseSensitive: false,
              ).hasMatch(input))
            rethrow;
          parsed = await _resolveWebPage(
            const MediaRequestSpec(url: 'about:blank'),
            operation,
            html: input,
          );
        }
        final variants = <AudioVariant>[];
        for (final v in parsed.variants) {
          final result = <AudioSegment>[];
          for (final segment in v.segments) {
            operation.check();
            var request = segment.request;
            if (source != null) {
              final prepared = await engine.prepareAudioRequest(
                '${request.url},${jsonEncode({'method': request.method, 'body': request.body, 'headers': request.headers})}',
                source: source,
                book: book!,
                chapter: chapter!,
                headers: request.headers,
              );
              request = MediaRequestSpec(
                url: prepared.url,
                method: prepared.method,
                body: prepared.body,
                headers: prepared.headers,
                operationId: operation.id,
                sourceId: ref.sourceId,
                cookieJar: engine.cookieStore.snapshot(),
              );
            }
            if (request.method == 'GET') {
              MediaResource media;
              try {
                media = await MediaResourceResolver(http: http).resolveResource(
                  MediaResource(url: request.url, headers: request.headers),
                );
              } on FormatException {
                if (ref.origin != TrackOrigin.address ||
                    engine.webView == null) {
                  rethrow;
                }
                final captured = await _resolveWebPage(request, operation);
                result.addAll(captured.variants.first.segments);
                parsed = ResolvedAudio(
                  variants: parsed.variants,
                  lyric: parsed.lyric ?? captured.lyric,
                  title: parsed.title ?? captured.title,
                  artist: parsed.artist ?? captured.artist,
                  coverUrl: parsed.coverUrl ?? captured.coverUrl,
                  live: parsed.live || captured.live,
                );
                continue;
              }
              request = MediaRequestSpec(
                url: media.url,
                headers: media.headers,
                mimeType: media.mimeType ?? request.mimeType,
                operationId: operation.id,
                sourceId: ref.sourceId,
                cookieJar: engine.cookieStore.snapshot(),
              );
              parsed = ResolvedAudio(
                variants: parsed.variants,
                lyric: parsed.lyric ?? media.lyric,
                title: parsed.title ?? media.title,
                artist: parsed.artist ?? media.artist,
                coverUrl: parsed.coverUrl ?? media.coverUrl,
                live: parsed.live,
              );
            }
            result.add(AudioSegment(request, duration: segment.duration));
          }
          variants.add(
            AudioVariant(
              label: v.label,
              segments: List.unmodifiable(result),
              bitrate: v.bitrate,
            ),
          );
        }
        return ResolvedAudio(
          variants: List.unmodifiable(variants),
          title: parsed.title,
          artist: parsed.artist,
          coverUrl: parsed.coverUrl,
          lyric: chapter?.getVariable('lyric').isNotEmpty == true
              ? chapter!.getVariable('lyric')
              : parsed.lyric,
          live: parsed.live,
        );
      }),
    );
  }
}
