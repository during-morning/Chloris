import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../audio_focus.dart';

/// Web 视频播放（video_player）。
class VideoEngineView extends StatefulWidget {
  const VideoEngineView({super.key, required this.url});
  final String url;

  @override
  State<VideoEngineView> createState() => _VideoEngineViewState();
}

class _VideoEngineViewState extends State<VideoEngineView> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    AudioFocusCoordinator.instance.register('video', _controller.pause);
    _controller
        .initialize()
        .then((_) async {
          if (!mounted ||
              !await AudioFocusCoordinator.instance.acquire('video')) {
            return;
          }
          _controller.play();
          if (mounted) setState(() => _ready = true);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    AudioFocusCoordinator.instance.unregister('video');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio > 0
          ? _controller.value.aspectRatio
          : 16 / 9,
      child: VideoPlayer(_controller),
    );
  }
}
