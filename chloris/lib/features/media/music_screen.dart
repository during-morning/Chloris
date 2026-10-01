import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_icons.dart';
import 'audio_resolver.dart';
import 'audio_types.dart';
import 'media_player_screen.dart';
import 'music_artwork.dart';
import 'music_controller.dart';
import 'music_services.dart';

/// One screen for resolving an audio address and controlling playback.
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  static const _segmentsChoice = '__continuous_segments__';

  final _input = TextEditingController();
  MusicOperation? _operation;
  bool _resolving = false;
  bool _importing = false;
  String? _message;

  @override
  void dispose() {
    _operation?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _resolveAndPlay() async {
    final input = _input.text.trim();
    if (input.isEmpty || _resolving) return;

    final operation = _operation = MusicOperation();
    setState(() {
      _resolving = true;
      _message = null;
    });

    try {
      final services = ref.read(musicServicesProvider);
      await services.startup;
      var address = input;
      var continuous = false;
      late ResolvedAudio audio;
      try {
        audio = await services.resolver.resolve(
          TrackRef(id: TrackRef.identity(input), address: input),
          operation,
        );
      } on AudioSelectionRequired catch (selection) {
        final choice = await _chooseAudio(selection);
        if (choice == null || !mounted) return;
        if (choice == _segmentsChoice) {
          continuous = true;
          audio = parseAudio(input, chapter: true);
        } else {
          address = choice;
          audio = await services.resolver.resolve(
            TrackRef(id: TrackRef.identity(address), address: address),
            operation,
          );
        }
      }

      operation.check();
      final reference = TrackRef(
        id: TrackRef.identity(address),
        address: address,
        title: audio.title ?? '音频',
        artist: audio.artist,
        continuous: continuous,
      );
      final track = await services.preparedTrack(
        reference,
        audio,
        op: operation,
      );
      operation.check();
      await services.repository.saveTrack(track);
      await services.controller.addTracks([track], playFirst: true);
      if (mounted) {
        setState(() => _message = '正在播放：${track.displayTitle}');
      }
    } catch (error) {
      if (mounted && !operation.cancelled) {
        setState(() => _message = '解析失败：$error');
      }
    } finally {
      if (identical(_operation, operation)) {
        _operation = null;
        if (mounted) setState(() => _resolving = false);
      }
    }
  }

  Future<String?> _chooseAudio(AudioSelectionRequired selection) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('选择要播放的音频'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _segmentsChoice),
              child: const Text('连续播放全部分段'),
            ),
            for (var i = 0; i < selection.choices.length; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, selection.choices[i]),
                child: Text(
                  selection.choices[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );

  Future<void> _importAudio() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'mp3',
          'm4a',
          'aac',
          'flac',
          'ogg',
          'opus',
          'wav',
          'wma',
        ],
        allowMultiple: true,
        withData: kIsWeb,
      );
      if (result == null || !mounted) return;

      final services = ref.read(musicServicesProvider);
      await services.startup;
      final tracks = <MusicTrack>[];
      for (final file in result.files) {
        final path = kIsWeb ? null : file.path;
        if (path == null && file.bytes == null) continue;
        tracks.add(
          await services.importAudio(
            path: path,
            bytes: file.bytes,
            name: file.name,
          ),
        );
      }
      if (tracks.isEmpty) throw const FormatException('无法读取选中的音频文件');
      await services.controller.addTracks(tracks, playFirst: true);
      if (mounted) setState(() => _message = '正在播放：${tracks.first.displayTitle}');
    } catch (error) {
      if (mounted) setState(() => _message = '导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _cancelResolve() {
    _operation?.cancel();
    if (mounted) setState(() => _resolving = false);
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(musicServicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('音频'),
        actions: [
          IconButton(
            tooltip: '播放队列',
            onPressed: () => _showQueue(context, services.controller),
            icon: const AppIcon(AppIcons.queue),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: services.startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (services.error != null) {
            return Center(child: Text('音频服务不可用：${services.error}'));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth < 400 ? 12.0 : 24.0;
              final input = _inputPanel();
              final player = MusicPlayerPanel(
                controller: services.controller,
                showLyrics: false,
              );
              if (constraints.maxWidth >= 900) {
                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 340, child: input),
                      const VerticalDivider(width: 32),
                      Expanded(child: player),
                    ],
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    input,
                    const Divider(height: 20),
                    Expanded(child: player),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _inputPanel() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _input,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '音频地址、网页、HTML 或 JSON',
          hintText: '粘贴音频链接或解析内容',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _resolveAndPlay(),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _resolving ? null : _resolveAndPlay,
              icon: const AppIcon(AppIcons.play),
              label: Text(_resolving ? '解析中…' : '解析并播放'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: _importing ? '正在导入' : '导入本地音频',
            onPressed: _importing ? null : _importAudio,
            icon: const AppIcon(AppIcons.folder),
          ),
          if (_resolving)
            IconButton(
              tooltip: '取消解析',
              onPressed: _cancelResolve,
              icon: const AppIcon(AppIcons.close),
            ),
        ],
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        Text(_message!, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ],
  );

  void _showQueue(BuildContext context, MusicController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AudioQueue(controller: controller),
    );
  }
}

class _AudioQueue extends StatelessWidget {
  const _AudioQueue({required this.controller});

  final MusicController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .68,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Column(
          children: [
            ListTile(
              title: Text('播放队列 · ${controller.queue.length}'),
              trailing: IconButton(
                tooltip: '清空队列',
                onPressed: controller.queue.isEmpty
                    ? null
                    : controller.clearQueue,
                icon: const AppIcon(AppIcons.delete),
              ),
            ),
            if (controller.queue.isEmpty)
              const Expanded(child: Center(child: Text('队列为空')))
            else
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: controller.queue.length,
                  onReorderItem: controller.moveQueue,
                  itemBuilder: (context, index) {
                    final track = controller.queue[index];
                    return ListTile(
                      key: ValueKey('audio-queue-${track.id}-$index'),
                      selected: index == controller.index,
                      leading: MusicArtwork(url: track.coverUrl, size: 42),
                      title: Text(
                        track.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: track.artist == null
                          ? null
                          : Text(
                              track.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () {
                        controller.select(index);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        tooltip: '移出队列',
                        onPressed: () => controller.removeAt(index),
                        icon: const AppIcon(AppIcons.remove),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
