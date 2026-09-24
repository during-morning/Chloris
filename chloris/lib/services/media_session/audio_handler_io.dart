import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// 媒体会话处理器（后台 + 锁屏/通知栏控制）。
class ChlorisAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  ChlorisAudioHandler() {
    mediaItem.add(MediaItem(id: '', title: 'Chloris'));
    _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: state.processingState == ProcessingState.completed
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
      ));
    });
    _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
  }

  Future<void> playUrl(String url, String title) async {
    mediaItem.add(MediaItem(id: url, title: title));
    await _player.setUrl(url);
    _player.play();
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

Future<void> initMediaSession() async {
  await AudioService.init<ChlorisAudioHandler>(
    builder: () => ChlorisAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.during.chloris.channel',
      androidNotificationChannelName: '播放',
    ),
  );
}
