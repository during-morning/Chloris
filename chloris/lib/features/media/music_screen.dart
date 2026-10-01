import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_icons.dart';
import 'media_player_screen.dart';
import 'media_resource.dart';
import 'music_controller.dart';
import 'local_audio_url.dart';

/// 音乐入口：导入本地文件，解析 URL、网页/HTML 或 JSON，管理播放队列。
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key, this.controller});
  final MusicController? controller;
  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  final _input = TextEditingController();
  late final MusicController _controller;
  bool _resolving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sharedMusicController();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final input = _input.text.trim();
    if (input.isEmpty || _resolving) return;
    setState(() {
      _resolving = true;
      _message = null;
    });
    try {
      final resource = await MediaResourceResolver(
        http: ref.read(httpPortProvider),
      ).resolve(input);
      if (!mounted) return;
      await _controller.addTracks([
        MusicTrack.fromResource(resource),
      ], playFirst: true);
      if (mounted) setState(() => _message = '已加入播放队列');
    } catch (failure) {
      if (mounted) setState(() => _message = '音频解析失败：$failure');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _importAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'mp3',
          'm4a',
          'aac',
          'ogg',
          'opus',
          'wav',
          'flac',
          'wma',
        ],
        allowMultiple: true,
        withData: kIsWeb,
      );
      if (result == null || !mounted) return;
      final tracks = <MusicTrack>[];
      for (final file in result.files) {
        final path = kIsWeb ? null : file.path;
        if ((!kIsWeb && path != null) || file.bytes != null) {
          final mimeType = _audioMimeType(file.extension);
          final local = kIsWeb ? LocalAudioUrl(file.bytes!, mimeType) : null;
          tracks.add(
            MusicTrack(
              url: !kIsWeb && path != null
                  ? Uri.file(path).toString()
                  : local?.url ?? 'local:${file.name}',
              title: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
              bytes: !kIsWeb && path == null ? file.bytes : null,
              mimeType: mimeType,
              release: local?.release,
            ),
          );
        }
      }
      if (tracks.isEmpty) throw const FormatException('无法读取选中的音频文件');
      await _controller.addTracks(tracks);
      if (mounted) setState(() => _message = '已导入 ${tracks.length} 首音频');
    } catch (failure) {
      if (mounted) setState(() => _message = '导入失败：$failure');
    }
  }

  Future<void> _importLyrics() async {
    if (_controller.current == null) {
      setState(() => _message = '请先添加并选择一首音频');
      return;
    }
    final track = _controller.current;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['lrc', 'txt'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) throw const FormatException('无法读取歌词文件');
      if (_controller.current != track) {
        setState(() => _message = '歌曲已切换，请重新选择要导入歌词的歌曲');
        return;
      }
      _controller.setLyrics(utf8.decode(bytes, allowMalformed: true));
      setState(() => _message = '歌词已导入');
    } catch (failure) {
      if (mounted) setState(() => _message = '歌词导入失败：$failure');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('音乐播放器')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.all(constraints.maxWidth < 360 ? 12 : 24),
          children: [
            TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '音频地址 / 网页 / HTML / JSON',
                hintText: '粘贴音频链接或包含音频与歌词的内容',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _resolve(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _resolving ? null : _resolve,
                  icon: const AppIcon(AppIcons.play),
                  label: Text(_resolving ? '正在解析' : '解析并播放'),
                ),
                OutlinedButton.icon(
                  onPressed: _importAudio,
                  icon: const AppIcon(AppIcons.folder),
                  label: const Text('导入本地音频'),
                ),
                OutlinedButton.icon(
                  onPressed: _importLyrics,
                  icon: const AppIcon(AppIcons.file),
                  label: const Text('导入歌词'),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 16),
            if (constraints.maxWidth >= 850)
              SizedBox(
                height: (constraints.maxHeight - 170).clamp(400.0, 740.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: MusicPlayerPanel(controller: _controller),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(flex: 2, child: _queue(scrollable: true)),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: (constraints.maxHeight * .8).clamp(360.0, 680.0),
                child: MusicPlayerPanel(controller: _controller),
              ),
              const Divider(),
              _queue(scrollable: false),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _queue({required bool scrollable}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
    children: [
      Text(
        '播放队列 · ${_controller.queue.length}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (_controller.queue.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('添加音频后，可在这里切换和移除歌曲'),
        )
      else if (scrollable)
        Expanded(child: _queueList(scrollable: true))
      else
        _queueList(scrollable: false),
    ],
  );
  Widget _queueList({required bool scrollable}) => ListView.builder(
    shrinkWrap: !scrollable,
    physics: scrollable ? null : const NeverScrollableScrollPhysics(),
    itemCount: _controller.queue.length,
    itemBuilder: (context, index) {
      final track = _controller.queue[index];
      return ListTile(
        selected: index == _controller.index,
        leading: const AppIcon(AppIcons.album),
        title: Text(
          track.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artist == null
            ? null
            : Text(track.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _controller.select(index),
        trailing: IconButton(
          tooltip: '移出队列',
          onPressed: () => _controller.removeAt(index),
          icon: const AppIcon(AppIcons.delete),
        ),
      );
    },
  );
}

String _audioMimeType(String? extension) => switch (extension?.toLowerCase()) {
  'wav' => 'audio/wav',
  'flac' => 'audio/flac',
  'ogg' || 'opus' => 'audio/ogg',
  'm4a' => 'audio/mp4',
  'aac' => 'audio/aac',
  'wma' => 'audio/x-ms-wma',
  _ => 'audio/mpeg',
};
