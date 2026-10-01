import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:html/parser.dart' as html_parser;

class MediaResource {
  const MediaResource({
    required this.url,
    this.headers = const {},
    this.title,
    this.artist,
    this.coverUrl,
    this.lyric,
    this.lyricUrl,
    this.ruleUrl,
    this.mimeType,
  });

  final String url;
  final Map<String, String> headers;
  final String? title;
  final String? artist;
  final String? coverUrl;
  final String? lyric;
  final String? lyricUrl;
  final String? ruleUrl;
  final String? mimeType;

  MediaResource copyWith({
    String? url,
    String? lyric,
    String? mimeType,
    Map<String, String>? headers,
  }) => MediaResource(
    url: url ?? this.url,
    headers: headers ?? this.headers,
    title: title,
    artist: artist,
    coverUrl: coverUrl,
    lyric: lyric ?? this.lyric,
    lyricUrl: lyricUrl,
    ruleUrl: ruleUrl,
    mimeType: mimeType ?? this.mimeType,
  );
}

bool isMediaUrl(String url) => RegExp(
  r'\.(?:mp3|m4a|aac|ogg|opus|wav|flac|aiff|wma|m3u8|mp4|webm)(?:[?#]|$)',
  caseSensitive: false,
).hasMatch(url);

String? _resolveUrl(String raw, String? baseUrl) {
  var value = html_parser.parseFragment(raw.trim()).text ?? raw.trim();
  value = value.replaceAll(r'\/', '/');
  var uri = Uri.tryParse(value);
  if (uri == null || value.isEmpty) return null;
  if (uri.scheme.isEmpty) {
    final base = Uri.tryParse(baseUrl ?? '');
    if (base?.hasScheme == true) {
      uri = base!.resolveUri(uri);
    } else if (value.startsWith('//')) {
      uri = Uri.tryParse('https:$value');
    }
  }
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}

Map<String, String> _headers(Object? value) {
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return {};
    }
  }
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      if (entry.value != null) entry.key.toString(): entry.value.toString(),
  };
}

Map<String, String> mergeMediaHeaders(
  Map<String, String> base,
  Map<String, String> override,
) {
  final result = Map<String, String>.from(base);
  for (final entry in override.entries) {
    result.removeWhere(
      (key, _) => key.toLowerCase() == entry.key.toLowerCase(),
    );
    result[entry.key] = entry.value;
  }
  return Map.unmodifiable(result);
}

/// Parses Legado URL options as well as HTML players and common JSON APIs.
/// Page, advertisement, artwork and lyric URLs never outrank a media source.
MediaResource? parseMediaResource(
  String text, {
  String? baseUrl,
  String? resourceUrl,
  Map<String, String> headers = const {},
}) {
  MediaResource? fromUrl(
    String candidate, {
    Map<String, String> extraHeaders = const {},
  }) {
    var raw = candidate.trim();
    var options = <String, String>{};
    final optionStart = RegExp(r',\s*\{').firstMatch(raw);
    if (optionStart != null) {
      try {
        final option = jsonDecode(raw.substring(optionStart.start + 1));
        if (option is Map) options = _headers(option['headers']);
        raw = raw.substring(0, optionStart.start);
      } catch (_) {}
    }
    if (raw.contains(RegExp(r'\s|<|>|\{|\}'))) return null;
    final url = _resolveUrl(raw, baseUrl);
    if (url == null) return null;
    return MediaResource(
      url: url,
      ruleUrl: candidate.trim(),
      headers: mergeMediaHeaders(
        mergeMediaHeaders(headers, extraHeaders),
        options,
      ),
    );
  }

  MediaResource? fromJson(Object? value, {int depth = 0}) {
    if (depth > 8) return null;
    if (value is List) {
      for (final item in value) {
        final result = fromJson(item, depth: depth + 1);
        if (result != null) return result;
      }
      return null;
    }
    if (value is! Map) return null;
    final extra = _headers(value['headers'] ?? value['header']);
    MediaResource? result;
    for (final key in const [
      'playUrl',
      'play_url',
      'audioUrl',
      'audio_url',
      'musicUrl',
      'music_url',
      'mediaUrl',
      'resourceUrl',
    ]) {
      final url = value[key];
      if (url is String) result = fromUrl(url, extraHeaders: extra);
      if (result != null) break;
    }
    if (result == null) {
      for (final key in const [
        'data',
        'result',
        'music',
        'song',
        'audio',
        'media',
        'play',
        'songs',
        'list',
      ]) {
        result = fromJson(value[key], depth: depth + 1);
        if (result != null) break;
      }
    }
    if (result == null) {
      for (final key in const ['src', 'url']) {
        if (value[key] is String) {
          result = fromUrl(value[key], extraHeaders: extra);
        }
        if (result != null) break;
      }
    }
    if (result == null) return null;
    String? string(Object? item) =>
        item is String && item.trim().isNotEmpty ? item : null;
    var lyric = string(value['lyric'] ?? value['lyrics']);
    final lrc = value['lrc'];
    lyric ??= lrc is Map ? string(lrc['lyric']) : string(lrc);
    final translation = value['tlyric'];
    if (translation is Map && string(translation['lyric']) != null) {
      lyric = [?lyric, translation['lyric']].join('\n');
    }
    final lyricUrl = string(
      value['lyricUrl'] ?? value['lyric_url'] ?? value['lrcUrl'],
    );
    if (lyric != null && RegExp(r'^(?:https?:)?//|^/').hasMatch(lyric.trim())) {
      return MediaResource(
        url: result.url,
        headers: result.headers,
        title: string(value['title'] ?? value['name']) ?? result.title,
        artist: string(value['artist'] ?? value['author']) ?? result.artist,
        coverUrl:
            _resolveUrl(
              string(value['coverUrl'] ?? value['cover'] ?? value['pic']) ?? '',
              baseUrl,
            ) ??
            result.coverUrl,
        lyricUrl: _resolveUrl(lyric, baseUrl) ?? result.lyricUrl,
        ruleUrl: result.ruleUrl,
      );
    }
    return MediaResource(
      url: result.url,
      headers: mergeMediaHeaders(result.headers, extra),
      title: string(value['title'] ?? value['name']) ?? result.title,
      artist: string(value['artist'] ?? value['author']) ?? result.artist,
      coverUrl:
          _resolveUrl(
            string(value['coverUrl'] ?? value['cover'] ?? value['pic']) ?? '',
            baseUrl,
          ) ??
          result.coverUrl,
      lyric: lyric ?? result.lyric,
      lyricUrl: _resolveUrl(lyricUrl ?? '', baseUrl) ?? result.lyricUrl,
      ruleUrl: result.ruleUrl,
    );
  }

  try {
    final result = fromJson(jsonDecode(text));
    if (result != null) return result;
  } catch (_) {}
  final plain = text.trim();
  if (RegExp(
    r'^(?:https?:)?//|^(?:\.\.?/|/)|\.(?:mp3|m4a|aac|ogg|opus|wav|flac|m3u8|mp4|webm)(?:[?#,]|$)',
    caseSensitive: false,
  ).hasMatch(plain)) {
    final result = fromUrl(plain);
    if (result != null) return result;
  }
  final fragment = html_parser.parseFragment(text);
  for (final selector in const [
    'audio[src]',
    'audio[data-src]',
    'audio source[src]',
    'source[src]',
    'source[data-src]',
    'video[src]',
    'video[data-src]',
  ]) {
    for (final node in fragment.querySelectorAll(selector)) {
      final result = fromUrl(
        node.attributes['src'] ?? node.attributes['data-src'] ?? '',
      );
      if (result != null) return result;
    }
  }
  for (final match in RegExp(
    r'''["']?(?:playUrl|audioUrl|musicUrl|mediaUrl|resourceUrl|src)["']?\s*[:=]\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''',
    caseSensitive: false,
  ).allMatches(text)) {
    var raw = match.group(1)!;
    try {
      raw = jsonDecode(raw) as String;
    } catch (_) {
      raw = raw.substring(1, raw.length - 1);
    }
    final result = fromUrl(raw);
    if (result != null) return result;
  }
  for (final match in RegExp(
    r'''(?:https?:)?//[^\s"'<>]+|(?:\.\.?/|/)[^\s"'<>]+''',
  ).allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'''[,;，。；、)\]}]+$'''), '');
    if (!isMediaUrl(raw)) continue;
    final result = fromUrl(raw);
    if (result != null) return result;
  }
  return fromUrl(resourceUrl ?? '') ??
      (isMediaUrl(baseUrl ?? '') ? fromUrl(baseUrl!) : null);
}

String? playableUrlFromContent(
  String text, {
  String? baseUrl,
  String? resourceUrl,
}) => parseMediaResource(text, baseUrl: baseUrl, resourceUrl: resourceUrl)?.url;

/// Uses the app HTTP port, including the same-origin proxy on Web.
class MediaResourceResolver {
  const MediaResourceResolver({required this.http});
  final HttpPort http;

  Future<MediaResource> resolve(
    String input, {
    String? baseUrl,
    String? resourceUrl,
    Map<String, String> headers = const {},
  }) async {
    final resource = parseMediaResource(
      input,
      baseUrl: baseUrl,
      resourceUrl: resourceUrl,
      headers: headers,
    );
    if (resource == null) {
      throw const FormatException('没有找到音频地址，请输入音频链接或含播放器的 HTML / JSON');
    }
    return resolveResource(resource);
  }

  Future<MediaResource> resolveResource(MediaResource resource) async {
    final seen = <String>{};
    for (var depth = 0; depth < 3; depth++) {
      if (isMediaUrl(resource.url)) return withLyrics(resource);
      if (!seen.add(resource.url)) throw const FormatException('音频页面解析发生循环');
      StrResponse? head;
      try {
        head = await http.send(
          HttpRequestSpec(
            url: resource.url,
            method: 'HEAD',
            headers: resource.headers,
          ),
        );
      } catch (_) {}
      var mime =
          (head?.headers['content-type'] ?? head?.headers['Content-Type'] ?? '')
              .toLowerCase();
      if (head?.isSuccessful == true &&
          (mime.startsWith('audio/') ||
              mime.startsWith('video/') ||
              mime.contains('mpegurl'))) {
        return withLyrics(resource.copyWith(mimeType: mime));
      }
      final response = await http.send(
        HttpRequestSpec(
          url: resource.url,
          headers: mergeMediaHeaders(resource.headers, {
            'Range': 'bytes=0-2097151',
          }),
          maxResponseBytes: 2 * 1024 * 1024,
          allowTruncated: true,
        ),
      );
      if (response.code >= 400) {
        throw FormatException('音频页面加载失败（${response.code}）');
      }
      mime =
          (response.headers['content-type'] ??
                  response.headers['Content-Type'] ??
                  mime)
              .toLowerCase();
      if (mime.startsWith('audio/') ||
          mime.startsWith('video/') ||
          mime.contains('mpegurl') ||
          mime.contains('octet-stream')) {
        return withLyrics(resource.copyWith(mimeType: mime));
      }
      final parsed = parseMediaResource(
        response.body ?? '',
        baseUrl: response.url,
        headers: resource.headers,
      );
      if (parsed == null) {
        throw const FormatException('页面中没有可播放的音频，请使用音频书源或动态解析');
      }
      resource = MediaResource(
        url: parsed.url,
        headers: parsed.headers,
        title: parsed.title ?? resource.title,
        artist: parsed.artist ?? resource.artist,
        coverUrl: parsed.coverUrl ?? resource.coverUrl,
        lyric: parsed.lyric ?? resource.lyric,
        lyricUrl: parsed.lyricUrl ?? resource.lyricUrl,
        ruleUrl: parsed.ruleUrl,
      );
    }
    if (!isMediaUrl(resource.url)) throw const FormatException('音频解析超过三层页面限制');
    return withLyrics(resource);
  }

  Future<MediaResource> withLyrics(MediaResource resource) async {
    if (resource.lyricUrl == null || resource.lyric != null) return resource;
    // An unavailable optional lyric endpoint must not stop the audio itself.
    try {
      final response = await http.send(
        HttpRequestSpec(
          url: resource.lyricUrl!,
          headers: resource.headers,
          maxResponseBytes: 2 * 1024 * 1024,
        ),
      );
      if (response.code >= 400) return resource;
      var lyric = response.body ?? '';
      try {
        final decoded = jsonDecode(lyric);
        if (decoded is Map) {
          final lrc = decoded['lrc'];
          lyric =
              (decoded['lyric'] ??
                      decoded['lyrics'] ??
                      (lrc is Map ? lrc['lyric'] : lrc) ??
                      lyric)
                  .toString();
        }
      } catch (_) {}
      return resource.copyWith(lyric: lyric);
    } catch (_) {
      return resource;
    }
  }
}
