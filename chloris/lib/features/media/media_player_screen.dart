import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'video_engine/video_engine_factory.dart';
import '../../app/theme/app_icons.dart';

String? playableUrlFromContent(String text) {
  final t = text.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    return t.split(RegExp(r'\s')).first;
  }
  final m = RegExp(r'https?://[^\s"<>]+').firstMatch(t);
  return m?.group(0);
}

/// 音频/视频播放。音频控制对齐 legado AudioPlay：进度、±15s、倍速、上一章/下一章。
class MediaPlayerView extends StatefulWidget {
  const MediaPlayerView({
    super.key,
    required this.url,
    this.title = '',
    this.isVideo = false,
    this.onPrev,
    this.onNext,
    this.hasPrev = false,
    this.hasNext = false,
  });

  final String url;
  final String title;
  final bool isVideo;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool hasPrev;
  final bool hasNext;

  @override
  State<MediaPlayerView> createState() => _MediaPlayerViewState();
}

class _MediaPlayerViewState extends State<MediaPlayerView> {
  AudioPlayer? _audio;
  bool _ready = false;
  String? _error;
  double _speed = 1;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (!widget.isVideo) {
        final audio = AudioPlayer();
        _audio = audio;
        await audio.setUrl(widget.url);
        await audio.setSpeed(_speed);
        await audio.play();
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _skip(int seconds) async {
    final a = _audio;
    if (a == null) return;
    final next = a.position + Duration(seconds: seconds);
    final dur = a.duration ?? next;
    await a.seek(
      next < Duration.zero ? Duration.zero : (next > dur ? dur : next),
    );
  }

  Future<void> _cycleSpeed() async {
    final i = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    _speed = _speeds[i];
    await _audio?.setSpeed(_speed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text('播放失败：' + _error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());
    if (widget.isVideo) return VideoEngineView(url: widget.url);
    return _buildAudio(context);
  }

  Widget _buildAudio(BuildContext context) {
    final audio = _audio!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const AppIcon(AppIcons.album, size: 96),
          const SizedBox(height: 16),
          Text(
            widget.title.isEmpty ? '音频' : widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          StreamBuilder<Duration>(
            stream: audio.positionStream,
            builder: (ctx, posSnap) {
              final pos = posSnap.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: audio.durationStream,
                builder: (ctx, durSnap) {
                  final dur = durSnap.data ?? Duration.zero;
                  final ms = dur.inMilliseconds;
                  return Column(
                    children: [
                      Slider(
                        value: ms > 0
                            ? pos.inMilliseconds.clamp(0, ms).toDouble()
                            : 0,
                        max: ms > 0 ? ms.toDouble() : 1,
                        onChanged: (v) =>
                            audio.seek(Duration(milliseconds: v.round())),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(_fmt(pos)), Text(_fmt(dur))],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<PlayerState>(
            stream: audio.playerStateStream,
            builder: (ctx, snap) {
              final playing = snap.data?.playing ?? audio.playing;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '上一章',
                    onPressed: widget.hasPrev ? widget.onPrev : null,
                    icon: const AppIcon(AppIcons.skipPrevious, size: 32),
                  ),
                  IconButton(
                    tooltip: '-15s',
                    onPressed: () => _skip(-15),
                    icon: const AppIcon(AppIcons.replay),
                  ),
                  IconButton.filled(
                    iconSize: 36,
                    onPressed: () => playing ? audio.pause() : audio.play(),
                    icon: AppIcon(playing ? AppIcons.pause : AppIcons.play),
                  ),
                  IconButton(
                    tooltip: '+15s',
                    onPressed: () => _skip(15),
                    icon: const AppIcon(AppIcons.forward10),
                  ),
                  IconButton(
                    tooltip: '下一章',
                    onPressed: widget.hasNext ? widget.onNext : null,
                    icon: const AppIcon(AppIcons.skipNext, size: 32),
                  ),
                ],
              );
            },
          ),
          TextButton(
            onPressed: _cycleSpeed,
            child: Text(_speed.toStringAsFixed(2) + 'x'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return m + ':' + s;
  }
}

class MediaPlayerScreen extends StatelessWidget {
  const MediaPlayerScreen({
    super.key,
    required this.url,
    this.title = '',
    this.isVideo = false,
    this.onPrev,
    this.onNext,
    this.hasPrev = false,
    this.hasNext = false,
  });

  final String url;
  final String title;
  final bool isVideo;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool hasPrev;
  final bool hasNext;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title.isEmpty ? '播放' : title)),
    body: MediaPlayerView(
      url: url,
      title: title,
      isVideo: isVideo,
      onPrev: onPrev,
      onNext: onNext,
      hasPrev: hasPrev,
      hasNext: hasNext,
    ),
  );
}
