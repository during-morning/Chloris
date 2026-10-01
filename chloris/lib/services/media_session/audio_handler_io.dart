import 'package:flutter/services.dart';
import 'package:audio_service_mpris/audio_service_mpris.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../../features/media/music_controller.dart';

/// 锁屏、通知栏与应用内界面操作同一个音乐控制器。
class CholrisAudioHandler extends BaseAudioHandler {
  CholrisAudioHandler({MusicController? controller})
    : _controller = controller ?? sharedMusicController() {
    _controller.addListener(_sync);
    _controller.positionListenable.addListener(_syncPosition);
    _controller.durationListenable.addListener(_sync);
    _sync();
  }
  final MusicController _controller;
  String? _publishedTrack;
  String? _publishedQueue;

  int _lastPositionSecond = -1;
  void _syncPosition() {
    final second = _controller.position.inSeconds;
    if (second != _lastPositionSecond) {
      _lastPositionSecond = second;
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: _controller.position,
          speed: _controller.speed,
        ),
      );
    }
  }

  void _sync() {
    final track = _controller.current;
    final queueKey = _controller.queue
        .map((t) => '${t.id}:${t.title}')
        .join('\n');
    if (_publishedQueue != queueKey) {
      _publishedQueue = queueKey;
      queue.add(
        _controller.queue
            .map(
              (t) => MediaItem(
                id: t.id,
                title: t.displayTitle,
                artist: t.artist,
                artUri: t.coverUrl == null ? null : Uri.tryParse(t.coverUrl!),
              ),
            )
            .toList(),
      );
    }
    final trackKey =
        '${track?.id}:${track?.title}:${track?.artist}:${track?.coverUrl}:${_controller.duration}';
    if (_publishedTrack != trackKey) {
      _publishedTrack = trackKey;
      mediaItem.add(
        track == null
            ? const MediaItem(id: '', title: 'Cholris')
            : MediaItem(
                id: track.id,
                title: track.displayTitle,
                artist: track.artist,
                artUri: track.coverUrl == null
                    ? null
                    : Uri.tryParse(track.coverUrl!),
                duration: _controller.duration > Duration.zero
                    ? _controller.duration
                    : null,
              ),
      );
    }
    playbackState.add(
      PlaybackState(
        controls: [
          if (_controller.hasPrevious) MediaControl.skipToPrevious,
          _controller.playing ? MediaControl.pause : MediaControl.play,
          if (_controller.hasNext) MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: switch (_controller.phase) {
          MusicPhase.idle || MusicPhase.error => AudioProcessingState.idle,
          MusicPhase.loading ||
          MusicPhase.resolving => AudioProcessingState.loading,
          MusicPhase.buffering => AudioProcessingState.buffering,
          MusicPhase.ready => AudioProcessingState.ready,
          MusicPhase.completed => AudioProcessingState.completed,
        },
        playing: _controller.playing,
        updatePosition: _controller.position,
        speed: _controller.speed,
        queueIndex: _controller.index < 0 ? null : _controller.index,
      ),
    );
  }

  @override
  Future<void> play() => _controller.play();
  @override
  Future<void> pause() => _controller.pause();
  @override
  Future<void> stop() => _controller.stop();
  @override
  Future<void> seek(Duration position) => _controller.seek(position);
  @override
  Future<void> skipToNext() => _controller.next();
  @override
  Future<void> skipToPrevious() => _controller.previous();
  @override
  Future<void> skipToQueueItem(int index) => _controller.select(index);
  @override
  Future<void> fastForward() => _controller.skip(15);
  @override
  Future<void> rewind() => _controller.skip(-15);
  @override
  Future<void> setSpeed(double speed) => _controller.setSpeed(speed);
  @override
  Future<void> onTaskRemoved() async {
    if (!_controller.playing) await stop();
  }

  void detach() {
    _controller.removeListener(_sync);
    _controller.positionListenable.removeListener(_syncPosition);
    _controller.durationListenable.removeListener(_sync);
  }
}

CholrisAudioHandler? _handler;
Future<void> initMediaSession() async {
  if (_handler != null) return;
  // audio_service has native notification support on Android/iOS/macOS.
  // Other platforms retain the same foreground controller and queue.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await _initWindows();
    return;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)
    AudioServiceMpris.registerWith();
  if (!kIsWeb &&
      !const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform)) {
    return;
  }
  CholrisAudioHandler? candidate;
  try {
    _handler = await AudioService.init<CholrisAudioHandler>(
      builder: () => candidate = CholrisAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.during.chloris.channel',
        androidNotificationChannelName: '音乐播放',
        androidNotificationOngoing: true,
      ),
    );
  } catch (_) {
    candidate?.detach();
    _handler = null;
    rethrow;
  }
}

const _windowsChannel = MethodChannel('chloris/media_session');
Future<void> _initWindows() async {
  if (_handler != null) return;
  final c = sharedMusicController();
  await _windowsChannel.invokeMethod<void>('initialize');
  _windowsChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'play':
        await c.play();
      case 'pause':
        await c.pause();
      case 'stop':
        await c.stop();
      case 'next':
        await c.next();
      case 'previous':
        await c.previous();
      case 'seek':
        await c.seek(Duration(milliseconds: (call.arguments as num).toInt()));
    }
  });
  final handler = CholrisAudioHandler();
  _handler = handler;
  void publish() {
    _windowsChannel
        .invokeMethod<void>('update', {
          'title': c.current?.displayTitle ?? '',
          'artist': c.current?.artist ?? '',
          'album': c.current?.album ?? '',
          'playing': c.playing,
          'position': c.position.inMilliseconds,
          'duration': c.duration.inMilliseconds,
          'speed': c.speed,
          'hasNext': c.hasNext,
          'hasPrevious': c.hasPrevious,
        })
        .catchError((Object _) {});
  }

  c.addListener(publish);
  c.durationListenable.addListener(publish);
  var last = -1;
  c.positionListenable.addListener(() {
    if (c.position.inSeconds != last) {
      last = c.position.inSeconds;
      publish();
    }
  });
  publish();
}
