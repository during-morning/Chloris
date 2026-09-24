import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 桌面/移动用 media_kit 视频播放。
class VideoEngineView extends StatefulWidget {
  const VideoEngineView({super.key, required this.url});
  final String url;

  @override
  State<VideoEngineView> createState() => _VideoEngineViewState();
}

class _VideoEngineViewState extends State<VideoEngineView> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(controller: _controller);
}
