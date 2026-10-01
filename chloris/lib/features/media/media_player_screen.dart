import 'music_artwork.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_icons.dart';
import 'lyrics_view.dart';
import 'music_controller.dart';
import 'video_engine/video_engine_factory.dart';

export 'media_resource.dart' show playableUrlFromContent;

/// 章节音频与独立音乐页共用同一前台/系统媒体会话。
class MediaPlayerView extends StatefulWidget {
  const MediaPlayerView({
    super.key,
    required this.url,
    this.title = '',
    this.artist,
    this.coverUrl,
    this.lyric,
    this.headers = const {},
    this.isVideo = false,
    this.onPrev,
    this.onNext,
    this.hasPrev = false,
    this.hasNext = false,
    this.controller,
  });
  final String url;
  final String title;
  final String? artist;
  final String? coverUrl;
  final String? lyric;
  final Map<String, String> headers;
  final bool isVideo;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool hasPrev;
  final bool hasNext;
  final MusicController? controller;

  @override
  State<MediaPlayerView> createState() => _MediaPlayerViewState();
}

class _MediaPlayerViewState extends State<MediaPlayerView> {
  late MusicController _controller;
  @override
  void initState() {
    super.initState();
    if (!widget.isVideo) {
      _controller = widget.controller ?? sharedMusicController();
      _open();
    }
  }

  void _open() {
    unawaited(
      _controller.openChapter(
        MusicTrack(
          url: widget.url,
          title: widget.title,
          artist: widget.artist,
          coverUrl: widget.coverUrl,
          lyric: widget.lyric,
          headers: widget.headers,
        ),
        onPrevious: widget.hasPrev ? widget.onPrev : null,
        onNext: widget.hasNext ? widget.onNext : null,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant MediaPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVideo) {
      if (!oldWidget.isVideo) unawaited(_controller.stop());
      return;
    }
    if (oldWidget.isVideo || widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? sharedMusicController();
      _open();
    } else if (widget.url != oldWidget.url ||
        widget.title != oldWidget.title ||
        widget.lyric != oldWidget.lyric ||
        widget.artist != oldWidget.artist ||
        widget.coverUrl != oldWidget.coverUrl ||
        !_sameHeaders(widget.headers, oldWidget.headers)) {
      _open();
    } else {
      _controller.updateChapterControls(
        onPrevious: widget.hasPrev ? widget.onPrev : null,
        onNext: widget.hasNext ? widget.onNext : null,
      );
    }
  }

  bool _sameHeaders(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);
  @override
  void dispose() {
    if (!widget.isVideo && _controller.current?.url == widget.url) {
      _controller.updateChapterControls(notify: false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.isVideo
      ? VideoEngineView(key: ValueKey(widget.url), url: widget.url)
      : MusicPlayerPanel(controller: _controller);
}

class MusicPlayerPanel extends StatelessWidget {
  const MusicPlayerPanel({
    super.key,
    required this.controller,
    this.showLyrics = true,
    this.showArtwork = true,
  });
  final bool showLyrics, showArtwork;
  final MusicController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final track = controller.current;
        final narrow = constraints.maxWidth < 360;
        final padding = narrow ? 12.0 : 24.0;
        final lyricHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * .38).clamp(128.0, 340.0)
            : 240.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (track == null) ...[
                const AppIcon(AppIcons.album, size: 64),
                const SizedBox(height: 12),
                Text(
                  '添加音频开始播放',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ] else ...[
                if (showArtwork)
                  Center(
                    child: MusicArtwork(
                      url: track.coverUrl,
                      size: (constraints.maxWidth - padding * 2).clamp(96, 228),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  track.displayTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (track.artist?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(track.artist!, textAlign: TextAlign.center),
                ],
                if (controller.loading ||
                    controller.phase == MusicPhase.buffering) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  Text(
                    controller.loading ? '正在加载音频' : '正在缓冲',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text('播放失败：${controller.error}', textAlign: TextAlign.center),
                  TextButton.icon(
                    onPressed: controller.retry,
                    icon: const AppIcon(AppIcons.refresh),
                    label: const Text('重试播放'),
                  ),
                ],
                const SizedBox(height: 16),
                if (showLyrics)
                  SizedBox(
                    height: lyricHeight,
                    child: ValueListenableBuilder<int>(
                      valueListenable: controller.lyricLineListenable,
                      builder: (context, line, _) => LyricsView(
                        document: controller.lyrics,
                        position: controller.position,
                        positionListenable: controller.positionListenable,
                        offset: Duration(milliseconds: controller.lyricOffset),
                        currentLine: line,
                        onSeek: controller.seek,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Duration>(
                  valueListenable: controller.positionListenable,
                  builder: (context, position, _) => Column(
                    children: [
                      Slider(
                        key: const ValueKey('music-progress'),
                        value: controller.duration.inMilliseconds > 0
                            ? position.inMilliseconds
                                  .clamp(0, controller.duration.inMilliseconds)
                                  .toDouble()
                            : 0,
                        max: controller.duration.inMilliseconds > 0
                            ? controller.duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged:
                            controller.loading ||
                                controller.duration <= Duration.zero
                            ? null
                            : (value) => controller.seek(
                                Duration(milliseconds: value.round()),
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              formatMusicTime(position),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              controller.current?.live == true
                                  ? '直播'
                                  : controller.duration == Duration.zero
                                  ? '时长未知'
                                  : formatMusicTime(controller.duration),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: narrow ? 0 : 8,
                    children: [
                      IconButton(
                        tooltip: '上一首',
                        onPressed: controller.hasPrevious
                            ? controller.previous
                            : null,
                        icon: const AppIcon(AppIcons.skipPrevious),
                      ),
                      IconButton(
                        tooltip: '后退15秒',
                        onPressed: controller.loading
                            ? null
                            : () => controller.skip(-15),
                        icon: const AppIcon(AppIcons.replay),
                      ),
                      IconButton.filled(
                        tooltip: controller.playing ? '暂停' : '播放',
                        onPressed: controller.loading
                            ? null
                            : controller.togglePlayback,
                        icon: AppIcon(
                          controller.playing ? AppIcons.pause : AppIcons.play,
                        ),
                      ),
                      IconButton(
                        tooltip: '前进15秒',
                        onPressed: controller.loading
                            ? null
                            : () => controller.skip(15),
                        icon: const AppIcon(AppIcons.forward10),
                      ),
                      IconButton(
                        tooltip: '下一首',
                        onPressed: controller.hasNext ? controller.next : null,
                        icon: const AppIcon(AppIcons.skipNext),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('音量'),
                    Expanded(
                      child: Slider(
                        key: const ValueKey('music-volume'),
                        value: controller.volume,
                        onChanged: controller.setVolume,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${(controller.volume * 100).round()}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

String formatMusicTime(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class MediaPlayerScreen extends StatelessWidget {
  const MediaPlayerScreen({
    super.key,
    required this.url,
    this.title = '',
    this.artist,
    this.coverUrl,
    this.lyric,
    this.headers = const {},
    this.isVideo = false,
    this.onPrev,
    this.onNext,
    this.hasPrev = false,
    this.hasNext = false,
    this.controller,
  });
  final String url;
  final String title;
  final String? artist;
  final String? coverUrl;
  final String? lyric;
  final Map<String, String> headers;
  final bool isVideo;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool hasPrev;
  final bool hasNext;
  final MusicController? controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title.isEmpty ? '播放' : title)),
    body: MediaPlayerView(
      url: url,
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      lyric: lyric,
      headers: headers,
      isVideo: isVideo,
      onPrev: onPrev,
      onNext: onNext,
      hasPrev: hasPrev,
      hasNext: hasNext,
      controller: controller,
    ),
  );
}
