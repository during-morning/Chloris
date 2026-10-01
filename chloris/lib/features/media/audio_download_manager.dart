import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:chloris_engine/chloris_engine.dart' show CookieStore;
import 'audio_types.dart';
import 'audio_file_store.dart';
import 'music_controller.dart';
import 'music_repository.dart';
import 'media_gateway.dart';

enum AudioDownloadStatus { queued, downloading, paused, complete, failed }

class AudioDownloadTask {
  AudioDownloadTask(
    this.track, {
    this.status = AudioDownloadStatus.queued,
    this.completed = 0,
    this.total = 0,
    this.files = const [],
    this.error,
    this.etag,
    this.modified,
    Map<String, Map<String, dynamic>>? resources,
    this.coverKey,
  }) : resources = resources ?? {};
  MusicTrack track;
  final Map<String, Map<String, dynamic>> resources;
  String? coverKey;
  double bytesPerSecond = 0;
  AudioDownloadStatus status;
  int completed, total;
  List<String> files;
  String? error, etag, modified;
  double get progress => total == 0 ? 0 : (completed / total).clamp(0, 1);
  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'status': status.name,
    'completed': completed,
    'total': total,
    'files': files,
    'error': error,
    'etag': etag,
    'modified': modified,
    'resources': resources,
    'coverKey': coverKey,
  };
  factory AudioDownloadTask.fromJson(Map<String, dynamic> j) =>
      AudioDownloadTask(
        MusicTrack.fromJson(Map<String, dynamic>.from(j['track'] as Map)),
        status: AudioDownloadStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => AudioDownloadStatus.paused,
        ),
        completed: j['completed'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
        files: (j['files'] as List? ?? []).cast<String>(),
        error: j['error'] as String?,
        etag: j['etag'] as String?,
        modified: j['modified'] as String?,
        coverKey: j['coverKey'] as String?,
        resources: (j['resources'] as Map? ?? {}).map(
          (k, v) => MapEntry('$k', Map<String, dynamic>.from(v as Map)),
        ),
      );
}

class AudioDownloadManager extends ChangeNotifier {
  AudioDownloadManager({
    required this.repository,
    required this.resolve,
    this.store,
  });
  final MusicRepository repository;
  final Future<MusicTrack> Function(MusicTrack, MusicOperation) resolve;
  final AudioFileStore? store;
  AudioFileStore get _store => store ?? AudioFileStore();
  final List<AudioDownloadTask> tasks = [];
  final _active = <String, MusicOperation>{};
  final _hosts = <String>{};
  final _activeHosts = <String, String>{};
  bool _disposed = false, _shuttingDown = false;
  DateTime _lastUpdate = DateTime(0);
  Future<void> restore() async {
    for (final j in await repository.downloads()) {
      final task = AudioDownloadTask.fromJson(j);
      if (task.status == AudioDownloadStatus.downloading ||
          task.status == AudioDownloadStatus.queued) {
        task.status = AudioDownloadStatus.paused;
      }
      tasks.add(task);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(AudioDownloadTask t) => _disposed
      ? Future.value()
      : repository.saveDownload(t.track.id, t.toJson(), t.status.name);
  Future<void> enqueue(List<MusicTrack> tracks) async {
    for (final t in tracks) {
      if (t.live) throw const FormatException('直播音频无法离线下载');
      if (tasks.any((e) => e.track.id == t.id)) continue;
      await repository.saveTrack(t);
      final task = AudioDownloadTask(t);
      tasks.add(task);
      await _save(task);
    }
    _notify();
    _pump();
  }

  String _host(AudioDownloadTask t) =>
      t.track.ref?.sourceId ?? Uri.tryParse(t.track.url)?.host ?? t.track.id;
  void _pump() {
    if (_disposed || _shuttingDown) return;
    for (final task in tasks) {
      if (_active.length >= 2) break;
      if (task.status != AudioDownloadStatus.queued ||
          _hosts.contains(_host(task))) {
        continue;
      }
      final op = MusicOperation(timeout: const Duration(days: 7));
      _active[task.track.id] = op;
      _activeHosts[task.track.id] = _host(task);
      _hosts.add(_activeHosts[task.track.id]!);
      task.status = AudioDownloadStatus.downloading;
      unawaited(_run(task, op));
    }
    _notify();
  }

  Future<http.StreamedResponse> _request(
    MediaRequestSpec spec,
    MusicOperation op, {
    Map<String, String> extra = const {},
  }) async {
    op.check();
    final abort = Completer<void>();
    op.onCancel(() => abort.isCompleted ? null : abort.complete());
    final url = kIsWeb ? await MediaGateway.instance.prepare(spec) : spec.url;
    final client = http.Client();
    op.onCancel(client.close);
    final request = http.AbortableRequest(
      kIsWeb ? 'GET' : spec.method,
      Uri.parse(url),
      abortTrigger: abort.future,
    )..headers.addAll(kIsWeb ? extra : {...spec.headers, ...extra});
    if (!kIsWeb && spec.body != null) request.body = spec.body!;
    try {
      final r = await client.send(request).timeout(const Duration(seconds: 30));
      if (r.statusCode >= 400) {
        client.close();
        throw StateError('音频下载失败（${r.statusCode}）');
      }
      final stream = r.stream.timeout(const Duration(seconds: 45));
      return http.StreamedResponse(
        _closing(stream, client),
        r.statusCode,
        headers: r.headers,
        contentLength: r.contentLength,
      );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Stream<List<int>> _closing(Stream<List<int>> s, http.Client c) async* {
    try {
      yield* s;
    } finally {
      c.close();
    }
  }

  Future<void> _run(AudioDownloadTask task, MusicOperation op) async {
    try {
      final resolveOperation = MusicOperation();
      op.onCancel(resolveOperation.cancel);
      final track = await resolveOperation.wait(
        resolve(task.track, resolveOperation),
      );
      op.check();
      task.track = track.copyWith();
      if (track.lyric != null) {
        final key = '${task.track.id}-lyrics.lrc';
        await _store.write(key, Stream.value(utf8.encode(track.lyric!)));
        task.files = [...task.files.where((f) => f != key), key];
      }
      if (task.coverKey == null && track.coverUrl?.startsWith('http') == true) {
        try {
          final key = '${task.track.id}-cover.jpg',
              response = await _request(
                MediaRequestSpec(url: track.coverUrl!),
                op,
              );
          final cover = BytesBuilder(copy: false);
          await for (final chunk in response.stream) {
            if (cover.length + chunk.length > 8 * 1024 * 1024) {
              throw const FormatException('封面过大');
            }
            cover.add(chunk);
          }
          await _store.write(key, Stream.value(cover.takeBytes()));
          task.coverKey = key;
        } catch (_) {}
      }
      await repository.saveTrack(task.track);
      if (track.live) throw const FormatException('直播音频无法下载');
      final segments = track.segments.isEmpty
          ? [
              AudioSegment(
                MediaRequestSpec(url: track.url, headers: track.headers),
              ),
            ]
          : track.segments;
      final keys = <String>[
        if (task.coverKey != null) task.coverKey!,
        if (track.lyric != null) '${task.track.id}-lyrics.lrc',
      ];
      for (var i = 0; i < segments.length; i++) {
        op.check();
        final req = segments[i].request;
        final extension = Uri.parse(req.url).path.split('.').last.toLowerCase();
        final key =
            '${task.track.id}-$i.${req.mimeType?.contains('mpegurl') == true
                ? 'm3u8'
                : RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
                ? extension
                : 'mp3'}';
        if (extension == 'm3u8' || req.mimeType?.contains('mpegurl') == true) {
          await _hls(task, req, key, keys, op);
        } else {
          keys.add(key);
          task.files = List.of(keys);
          await _save(task);
          await _file(task, req, key, op);
        }
      }
      task.completed = task.resources.values.fold<int>(
        0,
        (a, r) => a + (r['size'] as int? ?? 0),
      );
      task.total = task.completed;
      task.files = keys;
      task.status = AudioDownloadStatus.complete;
      task.error = null;
      await _save(task);
    } catch (e) {
      task.status = op.cancelled
          ? AudioDownloadStatus.paused
          : AudioDownloadStatus.failed;
      task.error = op.cancelled ? null : e.toString();
      await _save(task);
    } finally {
      _active.remove(task.track.id);
      _hosts.remove(_activeHosts.remove(task.track.id));
      _notify();
      _pump();
    }
  }

  Future<void> _file(
    AudioDownloadTask task,
    MediaRequestSpec req,
    String key,
    MusicOperation op,
  ) async {
    final validator = task.resources.putIfAbsent(key, () => {});
    if (validator['complete'] == true) {
      try {
        final file = await _store.open(key);
        if (file.size == validator['size']) {
          file.release();
          return;
        }
        file.release();
      } catch (_) {}
    }
    var offset = await _store.partialSize(key);
    var response = await _request(
      req,
      op,
      extra: {
        if (offset > 0) 'Range': 'bytes=$offset-',
        if (offset > 0 && (validator['etag'] ?? validator['modified']) != null)
          'If-Range': '${validator['etag'] ?? validator['modified']}',
      },
    );
    if (offset > 0 && response.statusCode != 206) offset = 0;
    if (offset > 0 &&
        response.statusCode == 206 &&
        !RegExp(
          '^bytes $offset-',
        ).hasMatch(response.headers['content-range'] ?? '')) {
      await response.stream.drain<void>();
      throw const FormatException('续传响应位置不一致');
    }
    final old = validator['etag'] ?? validator['modified'];
    final changed =
        response.headers['etag'] ?? response.headers['last-modified'];
    if (offset > 0 && old != null && changed != null && old != changed) {
      await response.stream.drain<void>();
      offset = 0;
      response = await _request(req, op);
    }
    validator['etag'] = response.headers['etag'];
    validator['modified'] = response.headers['last-modified'];
    final previous = task.resources.entries
        .where((e) => e.key != key && e.value['complete'] == true)
        .fold<int>(0, (a, e) => a + (e.value['size'] as int? ?? 0));
    var fileBytes = offset;
    final expected = (response.contentLength ?? 0) + offset;
    task.completed = previous + offset;
    task.total = response.contentLength == null ? 0 : previous + expected;
    final began = DateTime.now();
    final beganBytes = fileBytes;
    await _save(task);
    Stream<List<int>> progress() async* {
      await for (final chunk in response.stream) {
        op.check();
        fileBytes += chunk.length;
        task.completed = previous + fileBytes;
        final elapsed = DateTime.now().difference(began).inMilliseconds;
        task.bytesPerSecond = elapsed <= 0
            ? 0
            : (fileBytes - beganBytes) * 1000 / elapsed;
        if (DateTime.now().difference(_lastUpdate).inMilliseconds >= 200) {
          _lastUpdate = DateTime.now();
          _notify();
        }
        yield chunk;
      }
    }

    await _store.write(key, progress(), partial: true, append: offset > 0);
    op.check();
    if (expected > 0 && fileBytes != expected) {
      throw const FormatException('音频下载不完整');
    }
    await _store.commit(key);
    validator['size'] = fileBytes;
    validator['complete'] = true;
    await _save(task);
  }

  Future<void> _hls(
    AudioDownloadTask task,
    MediaRequestSpec spec,
    String key,
    List<String> files,
    MusicOperation op, {
    int depth = 0,
  }) async {
    if (depth > 3) throw const FormatException('HLS 播放列表嵌套过深');
    final response = await _request(spec, op);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      op.check();
      if (bytes.length + chunk.length > 2 * 1024 * 1024) {
        throw const FormatException('HLS 播放列表过大');
      }
      bytes.add(chunk);
    }
    final text = utf8.decode(bytes.takeBytes());
    final lines = text.split('\n');
    if (!text.startsWith('#EXTM3U')) throw const FormatException('HLS 播放列表无效');
    if (text.contains('#EXT-X-STREAM-INF')) {
      // Prefer a dedicated audio rendition, otherwise select the highest bandwidth variant.
      final audio = RegExp(
        r'#EXT-X-MEDIA:[^\n]*TYPE=AUDIO[^\n]*URI="([^"]+)"',
      ).firstMatch(text);
      String? selected = audio?[1];
      var bandwidth = -1;
      if (selected == null)
        for (var i = 0; i + 1 < lines.length; i++) {
          if (!lines[i].startsWith('#EXT-X-STREAM-INF:')) continue;
          final b =
              int.tryParse(
                RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?[1] ?? '',
              ) ??
              0;
          if (b > bandwidth) {
            bandwidth = b;
            selected = lines[i + 1].trim();
          }
        }
      if (selected == null) throw const FormatException('HLS 没有可播放音质');
      return _hls(
        task,
        _relative(spec, selected),
        key,
        files,
        op,
        depth: depth + 1,
      );
    }
    if (!text.contains('#EXT-X-ENDLIST')) {
      throw const FormatException('直播 HLS 无法离线下载');
    }
    if (RegExp(r'METHOD=(?!NONE|AES-128)[^,\s]+').hasMatch(text) ||
        text.contains('KEYFORMAT=')) {
      throw const FormatException('该 HLS 加密格式无法离线下载');
    }
    final resources = <String, String>{};
    String register(String raw) {
      final resolved = Uri.parse(spec.url).resolve(raw).toString();
      return resources.putIfAbsent(resolved, () {
        final ext = Uri.parse(resolved).path.split('.').last;
        return '${key.split('.').first}-h${resources.length}.${RegExp(r'^[a-zA-Z0-9]{1,5}$').hasMatch(ext) ? ext : 'bin'}';
      });
    }

    final rewritten = [
      for (final line in lines)
        line.trim().isEmpty
            ? line
            : line.startsWith('#')
            ? line.replaceAllMapped(
                RegExp(r'URI="([^"]+)"'),
                (m) => 'URI="${register(m[1]!)}"',
              )
            : register(line.trim()),
    ].join('\n');
    for (final entry in resources.entries) {
      files.add(entry.value);
      task.files = List.of(files);
      await _save(task);
      await _file(task, _relative(spec, entry.key), entry.value, op);
    }
    await _store.write(key, Stream.value(utf8.encode(rewritten)));
    files.insert(0, key);
    task.files = List.of(files);
  }

  MediaRequestSpec _relative(MediaRequestSpec origin, String path) {
    final url = Uri.parse(origin.url).resolve(path);
    final headers = Map<String, String>.from(origin.headers);
    if (url.origin != Uri.parse(origin.url).origin) {
      headers.removeWhere(
        (k, v) => ['cookie', 'authorization'].contains(k.toLowerCase()),
      );
    }
    final cookie = origin.cookieJar[CookieStore.domainOf(url.toString())];
    if (cookie?.isNotEmpty == true) headers['Cookie'] = cookie!;
    return MediaRequestSpec(
      url: url.toString(),
      headers: headers,
      cookieJar: origin.cookieJar,
    );
  }

  void pause(AudioDownloadTask t) {
    if (t.status == AudioDownloadStatus.complete) return;
    t.status = AudioDownloadStatus.paused;
    _active[t.track.id]?.cancel();
    unawaited(_save(t));
    _notify();
  }

  void resume(AudioDownloadTask t) {
    if (t.status == AudioDownloadStatus.complete ||
        _active.containsKey(t.track.id)) {
      return;
    }
    t.status = AudioDownloadStatus.queued;
    t.error = null;
    unawaited(_save(t));
    _pump();
  }

  Future<void> remove(AudioDownloadTask t) async {
    pause(t);
    while (_active.containsKey(t.track.id)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    for (final key in t.files) {
      await _store.delete(key);
    }
    tasks.remove(t);
    await repository.removeDownload(t.track.id);
    _notify();
  }

  Future<void> close() async {
    _shuttingDown = true;
    for (final op in _active.values) {
      op.cancel();
    }
    while (_active.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final op in _active.values) {
      op.cancel();
    }
    super.dispose();
  }
}
