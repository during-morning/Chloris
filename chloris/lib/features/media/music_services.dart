import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../sources/source_library_provider.dart';
import 'audio_types.dart';
import 'audio_resolver.dart';
import 'audio_metadata.dart';
import 'audio_file_store.dart';
import 'audio_download_manager.dart';
import 'music_controller.dart';
import 'music_repository.dart';
import 'media_gateway.dart';

final musicServicesProvider = Provider<MusicServices>((ref) {
  final resolver = AudioResolver(
    http: ref.read(httpPortProvider),
    engine: ref.read(engineFacadeProvider),
    port: ref.read(onlineBookPortProvider),
    findSource: (id) async {
      final sources = await ref.read(allSourcesProvider.future);
      for (final s in sources) {
        if (s.bookSourceUrl == id) return s;
      }
      return null;
    },
  );
  final services = MusicServices(resolver: resolver);
  ref.onDispose(services.dispose);
  return services;
});

class MusicServices extends ChangeNotifier with WidgetsBindingObserver {
  MusicServices({
    required this.resolver,
    MusicRepository? repository,
    MusicController? controller,
    AudioFileStore? store,
  }) : repository = repository ?? MusicRepository(),
       controller = controller ?? sharedMusicController(),
       store = store ?? AudioFileStore() {
    downloads = AudioDownloadManager(
      repository: this.repository,
      resolve: (t, o) => resolveTrack(t, o, forDownload: true),
      store: this.store,
    );
    this.controller.resolveTrack = resolveTrack;
    this.controller.addListener(_changed);
    this.controller.positionListenable.addListener(_progress);
    this.repository.addListener(_notify);
    downloads.addListener(_notify);
    WidgetsBinding.instance.addObserver(this);
    startup = _restore();
  }
  final Map<String, String> seedContent = {};
  Map<String, dynamic> settings = {};
  Future<void> updateSettings(Map<String, dynamic> values) async {
    settings.addAll(values);
    await repository.putState('settings', settings);
    _notify();
  }

  String bookKey(TrackRef ref) =>
      'audio-book-${TrackRef.identity('${ref.sourceId}\u0000${ref.book?['bookUrl']}')}';
  final AudioResolver resolver;
  final MusicRepository repository;
  final MusicController controller;
  final AudioFileStore store;
  late final AudioDownloadManager downloads;
  late final Future<void> startup;
  String? error;
  Timer? _persist;
  bool _restoring = true, _disposed = false;
  DateTime _lastSaved = DateTime(0);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restore() async {
    try {
      settings = await repository.state('settings') ?? {};
      await downloads.restore();
      final state = await repository.state('queue');
      if (state != null) {
        controller.restoreQueue(
          [
            for (final j in state['tracks'] as List? ?? [])
              MusicTrack.fromJson(Map<String, dynamic>.from(j as Map)),
          ],
          selected: state['index'] as int? ?? 0,
          at: Duration(milliseconds: state['position'] as int? ?? 0),
          rate: (state['speed'] as num? ?? 1).toDouble(),
          random: state['shuffle'] == true,
          mode: MusicRepeat.values[(state['repeat'] as int? ?? 0).clamp(0, 2)],
        );
      }
    } catch (e) {
      error = e.toString();
    } finally {
      _restoring = false;
      _notify();
    }
  }

  void _changed() {
    if (_restoring) return;
    _persist?.cancel();
    _persist = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(flush()),
    );
    _notify();
  }

  void _progress() {
    if (_restoring || DateTime.now().difference(_lastSaved).inSeconds < 5) {
      return;
    }
    _lastSaved = DateTime.now();
    unawaited(flush());
  }

  Future<void> _flushTail = Future.value();
  Future<void> flush() {
    final tracks = controller.queue,
        index = controller.index,
        position = controller.position,
        duration = controller.duration,
        current = controller.current;
    final state = {
      'tracks': [for (final t in tracks) t.toJson()],
      'index': index,
      'position': position.inMilliseconds,
      'speed': controller.speed,
      'shuffle': controller.shuffle,
      'repeat': controller.repeat.index,
    };
    return _flushTail = _flushTail
        .catchError((Object _) {})
        .then((_) => _flush(state, current, position, duration));
  }

  Future<void> _flush(
    Map<String, dynamic> state,
    MusicTrack? current,
    Duration position,
    Duration duration,
  ) async {
    try {
      await repository.putState('queue', state);
      if (current != null) {
        await repository.saveHistory(current, position, duration);
      }
      if (current?.ref?.origin == TrackOrigin.source) {
        await repository.putState(bookKey(current!.ref!), {
          'trackId': current.id,
          'position': position.inMilliseconds,
          'speed': state['speed'],
          'intro': controller.skipIntroSeconds,
          'outro': controller.skipOutroSeconds,
        });
      }
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  Future<MusicTrack> resolveTrack(
    MusicTrack t,
    MusicOperation op, {
    bool forDownload = false,
  }) async {
    op.check();
    await startup;
    MusicTrack result = t;
    final offline = forDownload
        ? null
        : downloads.tasks
              .where(
                (d) =>
                    d.track.id == t.id &&
                    d.status == AudioDownloadStatus.complete,
              )
              .firstOrNull;
    if (offline != null && offline.files.isNotEmpty) {
      final primary = offline.files
          .where((k) => RegExp('^${t.id}-[0-9]+\\.').hasMatch(k))
          .toList();
      final releases = <void Function()>[], segments = <AudioSegment>[];
      for (final key in primary) {
        final file = await store.open(key);
        releases.add(file.release);
        segments.add(AudioSegment(MediaRequestSpec(url: file.url)));
      }
      if (segments.isEmpty) throw const FormatException('离线音频清单无效');
      String? offlineCover;
      if (offline.coverKey != null) {
        final f = await store.open(offline.coverKey!);
        offlineCover = f.url;
        releases.add(f.release);
      }
      result = MusicTrack(
        url: segments.first.request.url,
        ref: t.ref,
        title: t.title,
        artist: t.artist,
        album: t.album,
        coverUrl: offlineCover ?? offline.track.coverUrl ?? t.coverUrl,
        lyric: offline.track.lyric ?? t.lyric,
        segments: segments,
        release: () {
          for (final f in releases) {
            f();
          }
        },
      );
    } else if (t.ref?.origin == TrackOrigin.local) {
      final file = await store.open(t.ref!.localKey!);
      op.check();
      result = MusicTrack(
        url: file.url,
        title: t.title,
        artist: t.artist,
        album: t.album,
        coverUrl: t.coverUrl,
        lyric: t.lyric,
        ref: t.ref,
        mimeType: t.mimeType,
        release: file.release,
      );
    } else if (t.ref != null) {
      final audio = await resolver.resolve(
        t.ref!,
        op,
        contentOverride: seedContent.remove(t.id),
      );
      op.check();
      result = await preparedTrack(t.ref!, audio, op: op, proxy: !forDownload);
    }
    final saved = await repository.lyrics(t.id);
    final offset = await repository.state('lyric-offset:${t.id}');
    op.check();
    return result.copyWith(
      lyric: saved?.text ?? result.lyric,
      lyricOffset:
          offset?['offset'] as int? ?? saved?.offset ?? result.lyricOffset,
    );
  }

  Future<MusicTrack> preparedTrack(
    TrackRef ref,
    ResolvedAudio audio, {
    int variant = 0,
    MusicOperation? op,
    bool proxy = true,
  }) async {
    final selected =
        audio.variants[(variant == 0 ? ref.variant : variant).clamp(
          0,
          audio.variants.length - 1,
        )];
    final segments = <AudioSegment>[];
    for (final s in selected.segments) {
      op?.check();
      final req = s.request;
      final proxied =
          req.method != 'GET' ||
          req.headers.isNotEmpty ||
          (req.url.toLowerCase().contains('.m3u8') ||
              req.mimeType?.contains('mpegurl') == true);
      final url = proxy && proxied
          ? await MediaGateway.instance.prepare(req)
          : req.url;
      segments.add(
        AudioSegment(
          proxy ? MediaRequestSpec(url: url) : req,
          duration: s.duration,
        ),
      );
    }
    return MusicTrack(
      url: segments.first.request.url,
      ref: ref,
      title: audio.title ?? ref.title,
      artist: audio.artist ?? ref.artist,
      album: ref.album,
      coverUrl: audio.coverUrl,
      lyric: audio.lyric,
      segments: segments,
      live: audio.live,
      release: proxy
          ? () {
              for (final s in segments) {
                unawaited(MediaGateway.instance.release(s.request.url));
              }
            }
          : null,
      mimeType:
          selected.segments.any(
            (s) =>
                (s.request.url.toLowerCase().contains('.m3u8') ||
                s.request.mimeType?.contains('mpegurl') == true),
          )
          ? 'application/vnd.apple.mpegurl'
          : 'audio/mpeg',
    );
  }

  Future<MusicTrack> importAudio({
    String? path,
    Uint8List? bytes,
    required String name,
  }) async {
    final ext = name.split('.').last.toLowerCase();
    final stored = path != null
        ? await store.importFile(path, ext)
        : await store.importBytes(bytes!, ext);
    final tags = await compute(
      readAudioMetadata,
      await store.prefix(stored.key),
    );
    if (['m4a', 'aac', 'mp4'].contains(ext)) {
      tags.addAll(
        await compute(readAudioMetadata, await store.tail(stored.key)),
      );
    }
    if (tags['lyric'] == null && path != null) {
      final companion = await store.companion(path);
      if (companion != null) {
        tags['lyric'] = await compute(decodeLyricBytes, companion);
      }
    }
    final title = tags['title'] ?? name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final ref = TrackRef(
      id: stored.key.split('.').first,
      origin: TrackOrigin.local,
      localKey: stored.key,
      title: title,
      artist: tags['artist'],
      album: tags['album'],
    );
    final track = MusicTrack(
      url: stored.url,
      ref: ref,
      title: title,
      artist: ref.artist,
      album: ref.album,
      lyric: tags['lyric'],
      release: stored.release,
    );
    await repository.saveTrack(track);
    stored.release();
    return MusicTrack(
      url: '',
      ref: ref,
      title: title,
      artist: ref.artist,
      album: ref.album,
      lyric: tags['lyric'],
    );
  }

  Future<void> importLyrics(MusicTrack track, Uint8List bytes) async {
    final text = await compute(decodeLyricBytes, bytes);
    await repository.saveTrack(track);
    await repository.saveLyrics(track.id, text);
    if (controller.current?.id == track.id) controller.setLyrics(text);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_restoring && !_disposed && state != AppLifecycleState.resumed) {
      _persist?.cancel();
      unawaited(flush());
    }
  }

  Future<void> offset(int ms) async {
    final track = controller.current;
    if (track == null) return;
    await repository.saveTrack(track);
    await repository.setLyricOffset(track.id, ms);
    controller.setLyricOffset(ms);
  }

  Future<void> play(
    List<MusicTrack> tracks, {
    int index = 0,
    bool resume = false,
  }) async {
    await startup;
    if (tracks.isEmpty) return;
    final reference = tracks[index.clamp(0, tracks.length - 1)].ref;
    if (reference?.origin == TrackOrigin.source) {
      final book = await repository.state(bookKey(reference!));
      controller.speed = (book?['speed'] as num? ?? controller.speed)
          .toDouble();
      controller.skipIntroSeconds = book?['intro'] as int? ?? 0;
      controller.skipOutroSeconds = book?['outro'] as int? ?? 0;
      if (resume && book != null) {
        final at = tracks.indexWhere((t) => t.id == book['trackId']);
        if (at >= 0) index = at;
        controller.resumePosition = Duration(
          milliseconds: book['position'] as int? ?? 0,
        );
      }
    } else {
      controller.skipIntroSeconds = controller.skipOutroSeconds = 0;
      if (resume) {
        controller.resumePosition = await repository.progress(tracks[index].id);
      }
    }

    for (final t in tracks) {
      await repository.saveTrack(t, notify: false);
    }
    repository.publish();
    await controller.setQueue(tracks, initialIndex: index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_restoring) unawaited(flush());
    _disposed = true;
    _persist?.cancel();
    controller.removeListener(_changed);
    controller.positionListenable.removeListener(_progress);
    repository.removeListener(_notify);
    downloads.removeListener(_notify);
    unawaited(
      downloads
          .close()
          .then((_) => _flushTail)
          .whenComplete(repository.dispose),
    );
    super.dispose();
  }
}
