import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'lyrics.dart';
import 'audio_focus.dart';
import 'package:audio_session/audio_session.dart';
import 'audio_types.dart';
import 'music_driver_factory.dart';
import 'media_resource.dart';
import 'media_playback_url.dart';
import '../../services/media_session/initialize_audio.dart';
import '../../services/media_session/media_session_factory.dart';

enum MusicPhase { idle, resolving, loading, buffering, ready, completed, error }

enum MusicRepeat { off, all, one }

class MusicTrack {
  const MusicTrack({
    required this.url,
    this.title = '',
    this.artist,
    this.coverUrl,
    this.lyric,
    this.headers = const {},
    this.bytes,
    this.mimeType = 'audio/mpeg',
    this.release,
    this.ref,
    this.segments = const [],
    this.live = false,
    this.album,
    this.lyricOffset = 0,
  });

  factory MusicTrack.fromResource(MediaResource resource) => MusicTrack(
    url: resource.url,
    title: resource.title ?? '',
    artist: resource.artist,
    coverUrl: resource.coverUrl,
    lyric: resource.lyric,
    headers: resource.headers,
  );

  final TrackRef? ref;
  String get id => ref?.id ?? TrackRef.identity(url);
  final List<AudioSegment> segments;
  final bool live;
  final String? album;
  final int lyricOffset;
  final String url;
  final String title;
  final String? artist;
  final String? coverUrl;
  final String? lyric;
  final Map<String, String> headers;
  final Uint8List? bytes;
  final String mimeType;
  final VoidCallback? release;
  String get displayTitle => title.trim().isEmpty ? '音频' : title;

  Map<String, dynamic> toJson() => {
    'ref':
        (ref ??
                TrackRef(
                  id: id,
                  address: url,
                  title: title,
                  artist: artist,
                  album: album,
                ))
            .toJson(),
    'title': title,
    'artist': artist,
    'album': album,
    'coverUrl': coverUrl,
    'lyric': lyric,
    'mimeType': mimeType,
    'lyricOffset': lyricOffset,
  };
  factory MusicTrack.fromJson(Map<String, dynamic> j) {
    final r = TrackRef.fromJson(Map<String, dynamic>.from(j['ref'] as Map));
    return MusicTrack(
      url: r.address ?? '',
      ref: r,
      title: j['title'] as String? ?? r.title,
      artist: j['artist'] as String? ?? r.artist,
      album: j['album'] as String? ?? r.album,
      coverUrl: j['coverUrl'] as String?,
      lyric: j['lyric'] as String?,
      mimeType: j['mimeType'] as String? ?? 'audio/mpeg',
      lyricOffset: j['lyricOffset'] as int? ?? 0,
    );
  }
  MusicTrack copyWith({
    String? url,
    String? lyric,
    int? lyricOffset,
    TrackRef? ref,
    List<AudioSegment>? segments,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
  }) => MusicTrack(
    url: url ?? this.url,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    coverUrl: coverUrl ?? this.coverUrl,
    lyric: lyric ?? this.lyric,
    headers: headers,
    bytes: bytes,
    mimeType: mimeType,
    release: release,
    ref: ref ?? this.ref,
    segments: segments ?? this.segments,
    live: live,
    lyricOffset: lyricOffset ?? this.lyricOffset,
  );
  MusicTrack withLyric(String text) => MusicTrack(
    url: url,
    title: title,
    artist: artist,
    coverUrl: coverUrl,
    lyric: text,
    headers: headers,
    bytes: bytes,
    mimeType: mimeType,
    release: release,
    ref: ref,
    segments: segments,
    live: live,
    album: album,
    lyricOffset: lyricOffset,
  );
}

class MusicDriverState {
  const MusicDriverState(this.phase, this.playing);
  final MusicPhase phase;
  final bool playing;
}

/// 可注入驱动，使界面和媒体会话共用同一播放器。
abstract interface class MusicPlayerDriver {
  Stream<MusicDriverState> get states;
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Stream<Object> get errors;
  Future<void> load(MusicTrack track);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class JustAudioMusicDriver implements MusicPlayerDriver {
  JustAudioMusicDriver() {
    ensureAudioBackendRegistered();
    _player = AudioPlayer();
  }
  late final AudioPlayer _player;
  final List<Duration?> _segmentDurations = [];
  StreamSubscription<dynamic>? _sequenceSub;
  Duration _offset(int index) => _segmentDurations
      .take(index)
      .fold(Duration.zero, (a, b) => a + (b ?? Duration.zero));
  Duration? get _total =>
      _segmentDurations.isEmpty || _segmentDurations.any((d) => d == null)
      ? _player.duration
      : _segmentDurations.fold(Duration.zero, (a, b) => a! + b!);

  @override
  Stream<MusicDriverState> get states => _player.playerStateStream.map((state) {
    final phase = switch (state.processingState) {
      ProcessingState.idle => MusicPhase.idle,
      ProcessingState.loading => MusicPhase.loading,
      ProcessingState.buffering => MusicPhase.buffering,
      ProcessingState.ready => MusicPhase.ready,
      ProcessingState.completed => MusicPhase.completed,
    };
    return MusicDriverState(phase, state.playing);
  });
  @override
  Stream<Duration> get positions =>
      _player.positionStream.map((p) => p + _offset(_player.currentIndex ?? 0));
  @override
  Stream<Duration?> get durations => _player.durationStream.map((d) {
    final i = _player.currentIndex ?? 0;
    if (i < _segmentDurations.length && d != null) _segmentDurations[i] = d;
    if (_segmentDurations.isNotEmpty &&
        _segmentDurations.any((d) => d == null)) {
      return null;
    }
    return _total;
  });
  @override
  Stream<Object> get errors => _player.errorStream;
  @override
  Future<void> load(MusicTrack track) async {
    _segmentDurations.clear();
    await _sequenceSub?.cancel();
    if (track.segments.length > 1) {
      _segmentDurations.addAll(track.segments.map((s) => s.duration));
      _sequenceSub = _player.sequenceStateStream.listen((state) {
        final seq = state.sequence;
        for (var i = 0; i < seq.length && i < _segmentDurations.length; i++) {
          if (seq[i].duration != null) _segmentDurations[i] = seq[i].duration;
        }
      });
      await _player.setAudioSources([
        for (final s in track.segments)
          AudioSource.uri(
            Uri.parse(mediaPlaybackUrl(s.request.url, s.request.headers)),
            headers: kIsWeb || s.request.headers.isEmpty
                ? null
                : s.request.headers,
          ),
      ]);
    } else if (track.bytes != null) {
      if (kIsWeb) {
        await _player.setUrl(
          Uri.dataFromBytes(track.bytes!, mimeType: track.mimeType).toString(),
        );
      } else {
        await _player.setAudioSource(
          _BytesAudioSource(track.bytes!, track.mimeType),
        );
      }
    } else {
      await _player.setUrl(
        mediaPlaybackUrl(track.url, track.headers),
        headers: kIsWeb || track.headers.isEmpty ? null : track.headers,
      );
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) async {
    if (_segmentDurations.length < 2) {
      await _player.seek(position);
      return;
    }
    var remaining = position;
    for (var i = 0; i < _segmentDurations.length; i++) {
      final d = _segmentDurations[i];
      if (d == null || remaining < d || i == _segmentDurations.length - 1) {
        await _player.seek(remaining, index: i);
        return;
      }
      remaining -= d;
    }
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> dispose() async {
    await _sequenceSub?.cancel();
    await _player.dispose();
  }
}

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = (start ?? 0).clamp(0, bytes.length);
    final to = (end ?? bytes.length).clamp(from, bytes.length);
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(bytes.sublist(from, to)),
      contentType: mimeType,
    );
  }
}

MusicController? _sharedController;
MusicController sharedMusicController() => _sharedController ??=
    MusicPlaybackCoordinator(driver: _DeferredMusicDriver());

/// Creating AudioPlayer registers a platform backend and allocates native
/// resources. Keep startup and browsing the music UI cheap; allocate it when a
/// track is first loaded or played.
class _DeferredMusicDriver implements MusicPlayerDriver {
  final StreamController<MusicDriverState> _states =
      StreamController<MusicDriverState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durations =
      StreamController<Duration?>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  MusicPlayerDriver? _inner;
  Future<MusicPlayerDriver>? _initializing;
  bool _disposed = false;

  Future<MusicPlayerDriver> _ensure() {
    if (_disposed) return Future.error(StateError('音频播放器已释放'));
    final active = _inner;
    if (active != null) return Future.value(active);
    return _initializing ??= _create().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initializing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<MusicPlayerDriver> _create() async {
    await initializeAudioBackend();
    if (_disposed) throw StateError('音频播放器已释放');
    final driver = createMusicDriver();
    _inner = driver;
    _subscriptions
      ..add(driver.states.listen(_states.add, onError: _errors.add))
      ..add(driver.positions.listen(_positions.add, onError: _errors.add))
      ..add(driver.durations.listen(_durations.add, onError: _errors.add))
      ..add(driver.errors.listen(_errors.add));
    try {
      await initMediaSession();
    } catch (_) {
      // The player still works if the platform lock-screen session is absent.
    }
    return driver;
  }

  @override
  Stream<MusicDriverState> get states => _states.stream;
  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<Duration?> get durations => _durations.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> load(MusicTrack track) async => (await _ensure()).load(track);
  @override
  Future<void> play() async => (await _ensure()).play();
  @override
  Future<void> pause() async {
    final driver = _inner;
    if (driver != null) await driver.pause();
  }

  @override
  Future<void> stop() async {
    final driver = _inner;
    if (driver != null) await driver.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final driver = _inner;
    if (driver != null) await driver.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final driver = _inner;
    if (driver != null) await driver.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    final driver = _inner;
    if (driver != null) await driver.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final driver = _inner;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await driver?.dispose();
    await Future.wait([
      _states.close(),
      _positions.close(),
      _durations.close(),
      _errors.close(),
    ]);
  }
}

class MusicController extends ChangeNotifier {
  MusicController({required MusicPlayerDriver driver}) : _driver = driver {
    AudioFocusCoordinator.instance.register('music', pause);
    _subscriptions.add(driver.states.listen(_onState));
    _subscriptions.add(
      driver.positions.listen((value) {
        if (_settingSource ||
            phase == MusicPhase.idle ||
            phase == MusicPhase.error) {
          return;
        }
        _pendingPosition = value;
        _positionTimer ??= Timer(const Duration(milliseconds: 100), () {
          _positionTimer = null;
          if (_disposed) return;
          final position = _pendingPosition;
          if (position != null && position != _position.value) {
            _position.value = position;
            if (skipOutroSeconds > 0 &&
                duration > Duration.zero &&
                position >= duration - Duration(seconds: skipOutroSeconds) &&
                !_completedHandled) {
              _completedHandled = true;
              unawaited(_onCompleted());
            }
            final line = lyrics.indexAt(
              position - Duration(milliseconds: lyricOffset),
            );
            if (line != _lyricLine.value) _lyricLine.value = line;
          }
          _pendingPosition = null;
        });
      }),
    );
    _subscriptions.add(
      driver.durations.listen((value) {
        _duration.value = value ?? Duration.zero;
        _notify();
      }),
    );
    _subscriptions.add(driver.errors.listen(_fail));
  }

  Future<MusicTrack> Function(MusicTrack, MusicOperation)? resolveTrack;
  MusicOperation? _operation;
  int lyricOffset = 0;
  Duration get lyricPosition => position - Duration(milliseconds: lyricOffset);
  bool stopAtEnd = false;
  int skipIntroSeconds = 0, skipOutroSeconds = 0;
  MusicTrack? _prefetched;
  MusicOperation? _prefetchOperation;
  Timer? _prefetchExpiry;
  final Map<String, String> failedTracks = {};
  bool _automatic = false, _recovering = false;
  final _refreshAttempted = <String>{};
  void _discardPrefetch() {
    _prefetchOperation?.cancel();
    _prefetchOperation = null;
    _prefetchExpiry?.cancel();
    _prefetched?.release?.call();
    _prefetched = null;
  }

  void _prefetch() {
    _discardPrefetch();
    if (resolveTrack == null || shuffle || index + 1 >= _queue.length) return;
    final next = _queue[index + 1];
    if (next.ref == null) return;
    final op = _prefetchOperation = MusicOperation(lane: 'prefetch');
    unawaited(() async {
      try {
        final ready = await op.wait(resolveTrack!(next, op));
        if (_disposed || op.cancelled || !identical(op, _prefetchOperation)) {
          ready.release?.call();
          return;
        }
        _prefetched = ready;
        _prefetchExpiry = Timer(const Duration(seconds: 30), _discardPrefetch);
      } catch (_) {}
    }());
  }

  Future<void> _recover(Object failure) async {
    if (_recovering || _disposed) return;
    _recovering = true;
    final track = current;
    final generation = _generation;
    try {
      if (track?.ref != null &&
          track!.ref!.origin != TrackOrigin.local &&
          RegExp(
            r'401|403|410|expired|过期|鉴权',
            caseSensitive: false,
          ).hasMatch('$failure') &&
          _refreshAttempted.add(track.id)) {
        final want = _wantsPlayback;
        resumePosition = position;
        await _load(autoplay: want);
        return;
      }
      if (_automatic && track != null) {
        failedTracks[track.id] = '$failure';
        if (failedTracks.length < _queue.length) {
          for (var step = 1; step <= _queue.length; step++) {
            final at = (index + step) % _queue.length;
            if (!failedTracks.containsKey(_queue[at].id)) {
              index = at;
              await _load(autoplay: true);
              return;
            }
          }
        }
      }
      if (generation == _generation) _wantsPlayback = false;
    } finally {
      _recovering = false;
      if (_automatic &&
          phase == MusicPhase.error &&
          failedTracks.length < _queue.length) {
        unawaited(_recover(error ?? failure));
      }
    }
  }

  bool _focusConfigured = false;
  Future<void> _configureFocus() async {
    if (_focusConfigured || kIsWeb) return;
    _focusConfigured = true;
    try {
      final session = await AudioSession.instance;
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) => unawaited(pause())),
      );
      _subscriptions.add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            unawaited(_driver.pause());
            playing = false;
            _notify();
          } else if (_wantsPlayback &&
              AudioFocusCoordinator.instance.current == 'music') {
            _startPlaying();
          }
        }),
      );
    } catch (_) {
      _focusConfigured = false;
    }
  }

  final MusicPlayerDriver _driver;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<MusicTrack> _queue = [];
  List<MusicTrack> get queue => List.unmodifiable(_queue);
  int index = -1;
  MusicTrack? get current =>
      index >= 0 && index < _queue.length ? _queue[index] : null;
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<int> _lyricLine = ValueNotifier(-1);
  Duration get position => _position.value;
  Duration get duration => _duration.value;
  ValueListenable<Duration> get positionListenable => _position;
  ValueListenable<Duration> get durationListenable => _duration;
  ValueListenable<int> get lyricLineListenable => _lyricLine;
  Timer? _positionTimer;
  Duration? _pendingPosition;
  MusicPhase phase = MusicPhase.idle;
  bool playing = false;
  String? error;
  double speed = 1;
  double volume = 1;
  bool shuffle = false;
  MusicRepeat repeat = MusicRepeat.off;
  LyricDocument lyrics = LyricDocument.parse('');
  VoidCallback? previousChapter;
  VoidCallback? nextChapter;
  bool get hasPrevious =>
      previousChapter != null ||
      index > 0 ||
      (repeat == MusicRepeat.all && _queue.length > 1);
  bool get hasNext =>
      nextChapter != null ||
      index < _queue.length - 1 ||
      (shuffle && _queue.length > 1) ||
      (repeat == MusicRepeat.all && _queue.length > 1);
  bool get loading => _settingSource || phase == MusicPhase.loading;
  int _generation = 0;
  bool _completedHandled = false;
  bool _disposed = false;
  bool _settingSource = false;
  bool _wantsPlayback = false;
  Timer? _sleepTimer;
  DateTime? sleepUntil;
  final Random _random = Random();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(Object failure) {
    error = failure.toString();
    phase = MusicPhase.error;
    playing = false;
    _notify();
    unawaited(_recover(failure));
  }

  void _onState(MusicDriverState state) {
    if (_settingSource &&
        (state.phase == MusicPhase.completed ||
            state.phase == MusicPhase.idle)) {
      return;
    }
    phase = state.phase;
    playing = state.playing && state.phase != MusicPhase.completed;
    _notify();
    if (state.phase == MusicPhase.completed && !_completedHandled) {
      _completedHandled = true;
      unawaited(_onCompleted());
    }
  }

  void restoreQueue(
    List<MusicTrack> tracks, {
    int selected = 0,
    Duration at = Duration.zero,
    double rate = 1,
    bool random = false,
    MusicRepeat mode = MusicRepeat.off,
  }) {
    if (_queue.isNotEmpty) return;
    _queue.addAll(tracks);
    index = tracks.isEmpty ? -1 : selected.clamp(0, tracks.length - 1);
    _position.value = at;
    speed = rate.clamp(0.5, 3);
    shuffle = random;
    repeat = mode;
    playing = false;
    phase = MusicPhase.idle;
    lyrics = LyricDocument.parse(current?.lyric ?? '');
    lyricOffset = current?.lyricOffset ?? 0;
    _lyricLine.value = lyrics.indexAt(lyricPosition);
    _notify();
  }

  Duration? resumePosition;
  Future<void> setQueue(
    List<MusicTrack> tracks, {
    int initialIndex = 0,
    bool autoplay = true,
  }) async {
    _automatic = false;
    failedTracks.clear();
    _refreshAttempted.clear();
    _discardPrefetch();
    previousChapter = null;
    nextChapter = null;
    final retired = List<MusicTrack>.from(_queue);
    _queue
      ..clear()
      ..addAll(tracks);
    index = _queue.isEmpty ? -1 : initialIndex.clamp(0, _queue.length - 1);
    if (current == null) {
      await stop();
      _releaseRetired(retired);
      return;
    }
    await _load(autoplay: autoplay);
    _releaseRetired(retired);
  }

  Future<void> openChapter(
    MusicTrack track, {
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) async {
    final retired = List<MusicTrack>.from(_queue);
    _queue
      ..clear()
      ..add(track);
    index = 0;
    previousChapter = onPrevious;
    nextChapter = onNext;
    await _load(autoplay: true);
    _releaseRetired(retired);
  }

  void updateChapterControls({
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    bool notify = true,
  }) {
    previousChapter = onPrevious;
    nextChapter = onNext;
    if (notify) _notify();
  }

  Future<void> addTracks(
    List<MusicTrack> tracks, {
    bool playFirst = false,
  }) async {
    if (tracks.isEmpty) return;
    previousChapter = null;
    nextChapter = null;
    final firstAdded = _queue.length;
    _queue.addAll(tracks);
    _notify();
    if (current == null || playFirst) await select(firstAdded);
  }

  Future<void> select(int selectedIndex, {bool autoplay = true}) async {
    if (selectedIndex < 0 || selectedIndex >= _queue.length) return;
    _automatic = false;
    failedTracks.clear();
    _refreshAttempted.clear();
    index = selectedIndex;
    await _load(autoplay: autoplay);
  }

  Future<void> _load({required bool autoplay}) async {
    var track = current;
    if (track == null) return;
    _operation?.cancel();
    final operation = _operation = MusicOperation();
    final generation = ++_generation;
    _settingSource = true;
    _wantsPlayback = autoplay;
    error = null;
    phase = MusicPhase.loading;
    playing = false;
    final restoreAt = resumePosition;
    resumePosition = null;
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPosition = null;
    _position.value = Duration.zero;
    _duration.value = Duration.zero;
    lyricOffset = track.lyricOffset;
    lyrics = LyricDocument.parse(track.lyric ?? '');
    _lyricLine.value = lyrics.indexAt(Duration.zero);
    _completedHandled = false;
    _notify();
    try {
      // stop cancels an earlier just_audio source load before requesting the
      // next source. Its interrupted Future is discarded by the generation.
      if (!await AudioFocusCoordinator.instance.acquire('music')) return;
      await _configureFocus();
      await _driver.stop();
      if (_disposed || generation != _generation) return;
      if (resolveTrack != null && track.ref != null) {
        phase = MusicPhase.resolving;
        _notify();
        final priorTrack = track;
        if (_prefetched?.id == track.id) {
          track = _prefetched!;
          _prefetched = null;
          _prefetchExpiry?.cancel();
          _prefetchOperation = null;
        } else {
          _discardPrefetch();
          track = await operation.wait(resolveTrack!(track, operation));
        }
        if (!identical(priorTrack.release, track.release)) {
          priorTrack.release?.call();
        }
        if (_disposed || generation != _generation) {
          track.release?.call();
          return;
        }
        _queue[index] = track;
        lyrics = await compute(LyricDocument.parse, track.lyric ?? '');
        lyricOffset = track.lyricOffset;
      }
      await operation.wait(_driver.load(track));
      if (_disposed || generation != _generation) return;
      await _driver.setSpeed(speed);
      await _driver.setVolume(volume);
      if (_disposed || generation != _generation) return;
      if (restoreAt != null && restoreAt > Duration.zero) {
        await seek(restoreAt);
      } else if (skipIntroSeconds > 0) {
        await seek(Duration(seconds: skipIntroSeconds));
      }
      phase = MusicPhase.ready;
      _prefetch();
      _notify();
      // just_audio.play 的 Future 会持续到暂停或播放结束，不能等待它来展示控制器。
      if (_wantsPlayback) _startPlaying();
    } catch (failure) {
      if (!_disposed && generation == _generation) _fail(failure);
    } finally {
      if (generation == _generation) _settingSource = false;
    }
  }

  void _startPlaying() {
    playing = true;
    _notify();
    final generation = _generation;
    unawaited(
      _driver.play().catchError((Object failure) {
        if (!_disposed && generation == _generation) _fail(failure);
      }),
    );
  }

  Future<void> play() async {
    if (current == null) return;
    _wantsPlayback = true;
    if (_settingSource) return;
    if (error != null) {
      await retry();
      return;
    }
    if (phase == MusicPhase.completed) {
      await seek(Duration.zero);
      _completedHandled = false;
    }
    if (phase == MusicPhase.idle) {
      if (position > Duration.zero) resumePosition = position;
      await _load(autoplay: true);
      return;
    }
    _startPlaying();
  }

  Future<void> pause() async {
    _wantsPlayback = false;
    try {
      await _driver.pause();
      playing = false;
      _notify();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> stop() async {
    ++_generation;
    _operation?.cancel();
    _discardPrefetch();
    _positionTimer?.cancel();
    _positionTimer = null;
    _pendingPosition = null;
    _settingSource = false;
    _wantsPlayback = false;
    try {
      await _driver.stop();
    } catch (failure) {
      _fail(failure);
    }
    playing = false;
    phase = MusicPhase.idle;
    _position.value = Duration.zero;
    _lyricLine.value = -1;
    _notify();
  }

  Future<void> togglePlayback() => playing ? pause() : play();
  Future<void> retry() => _load(autoplay: true);
  Future<void> seek(Duration target) async {
    if (current?.live == true) return;
    var safe = target < Duration.zero ? Duration.zero : target;
    if (duration > Duration.zero && safe > duration) safe = duration;
    try {
      await _driver.seek(safe);
      _position.value = safe;
      final line = lyrics.indexAt(safe - Duration(milliseconds: lyricOffset));
      if (line != _lyricLine.value) _lyricLine.value = line;
      _notify();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> skip(int seconds) => seek(position + Duration(seconds: seconds));
  Future<void> setSpeed(double value) async {
    try {
      final safe = value.clamp(0.5, 3.0);
      await _driver.setSpeed(safe);
      speed = safe;
      _notify();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> setVolume(double value) async {
    try {
      final safe = value.clamp(0.0, 1.0);
      await _driver.setVolume(safe);
      volume = safe;
      _notify();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> clearQueue() async {
    await stop();
    final retired = List<MusicTrack>.from(_queue);
    _queue.clear();
    index = -1;
    previousChapter = nextChapter = null;
    _releaseRetired(retired);
    _notify();
  }

  void setLyricOffset(int ms) {
    if (current != null) _queue[index] = current!.copyWith(lyricOffset: ms);
    lyricOffset = ms;
    _lyricLine.value = lyrics.indexAt(lyricPosition);
    _notify();
  }

  void moveQueue(int from, int to) {
    if (from < 0 || from >= _queue.length || to < 0 || to >= _queue.length) {
      return;
    }
    final currentId = current?.id;
    final item = _queue.removeAt(from);
    _queue.insert(to, item);
    index = _queue.indexWhere((t) => t.id == currentId);
    _notify();
  }

  Future<void> playNext(MusicTrack track) async {
    _queue.insert(index < 0 ? 0 : index + 1, track);
    _notify();
    if (index < 0) await select(0);
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _notify();
  }

  void cycleRepeat() {
    repeat = MusicRepeat.values[(repeat.index + 1) % MusicRepeat.values.length];
    _notify();
  }

  void setLyrics(String text) {
    if (current == null) return;
    _queue[index] = current!.withLyric(text);
    lyrics = LyricDocument.parse(text);
    _lyricLine.value = lyrics.indexAt(
      position - Duration(milliseconds: lyricOffset),
    );
    _notify();
  }

  Future<void> removeAt(int removedIndex) async {
    if (removedIndex < 0 || removedIndex >= _queue.length) return;
    final wasCurrent = removedIndex == index;
    final removed = _queue[removedIndex];
    _queue.removeAt(removedIndex);
    if (_queue.isEmpty) {
      index = -1;
      lyrics = LyricDocument.parse('');
      await stop();
      removed.release?.call();
      return;
    }
    if (removedIndex < index) index--;
    if (wasCurrent) {
      index = index.clamp(0, _queue.length - 1);
      await _load(autoplay: playing);
    }
    removed.release?.call();
    _notify();
  }

  Future<void> next() async {
    if (nextChapter != null) {
      nextChapter!();
      return;
    }
    if (_queue.length > 1 && shuffle) {
      final delta = 1 + _random.nextInt(_queue.length - 1);
      await select((index + delta) % _queue.length);
    } else if (index < _queue.length - 1) {
      await select(index + 1);
    } else if (repeat == MusicRepeat.all && _queue.isNotEmpty) {
      await select(0);
    }
  }

  Future<void> previous() async {
    if (previousChapter != null) {
      previousChapter!();
      return;
    }
    if (index > 0) {
      await select(index - 1);
    } else if (repeat == MusicRepeat.all && _queue.isNotEmpty) {
      await select(_queue.length - 1);
    }
  }

  Future<void> _onCompleted() async {
    if (stopAtEnd) {
      stopAtEnd = false;
      await pause();
      return;
    }
    if (repeat == MusicRepeat.one) {
      await seek(Duration.zero);
      _completedHandled = false;
      _startPlaying();
    } else if (hasNext) {
      _automatic = true;
      failedTracks.clear();
      _refreshAttempted.clear();
      if (_queue.length > 1 && shuffle) {
        index =
            (index + 1 + _random.nextInt(_queue.length - 1)) % _queue.length;
      } else {
        index = (index + 1) % _queue.length;
      }
      await _load(autoplay: true);
    }
  }

  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    sleepUntil = after == null ? null : DateTime.now().add(after);
    if (after != null) {
      _sleepTimer = Timer(after, () {
        sleepUntil = null;
        _sleepTimer = null;
        unawaited(pause());
      });
    }
    _notify();
  }

  void _releaseRetired(List<MusicTrack> tracks) {
    for (final track in tracks) {
      if (!_queue.any(
        (retained) => identical(retained.release, track.release),
      )) {
        track.release?.call();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operation?.cancel();
    _discardPrefetch();
    AudioFocusCoordinator.instance.unregister('music');
    ++_generation;
    _positionTimer?.cancel();
    _position.dispose();
    _duration.dispose();
    _lyricLine.dispose();
    _sleepTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(
      _driver.dispose().whenComplete(() {
        for (final track in _queue) {
          track.release?.call();
        }
      }),
    );
    super.dispose();
  }
}

class MusicPlaybackCoordinator extends MusicController {
  MusicPlaybackCoordinator({required super.driver});
}
