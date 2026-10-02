import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_icons.dart';
import '../../app/widgets/app_motion.dart';
import 'music_artwork.dart';
export 'music_artwork.dart' show MusicArtwork;
import 'music_services.dart';
import 'music_controller.dart';
import 'music_repository.dart';
import 'music_screen.dart';
import 'audio_download_manager.dart';
import 'audio_resolver.dart';
import 'audio_types.dart';
import 'music_source_screens.dart';
import 'media_player_screen.dart';
import 'lyrics_view.dart';
import 'music_export.dart';

void musicMessage(BuildContext context, Object message) {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$message')));
  }
}

Future<T?> musicAction<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } catch (e) {
    musicMessage(context, e);
    return null;
  }
}

Future<String?> musicInput(
  BuildContext context,
  String title, {
  String value = '',
}) async {
  final c = TextEditingController(text: value);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (s) => Navigator.pop(context, s),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  c.dispose();
  return result;
}

class MusicLanding extends StatefulWidget {
  const MusicLanding({super.key, required this.services});
  final MusicServices services;
  @override
  State<MusicLanding> createState() => _MusicLandingState();
}

class _MusicLandingState extends State<MusicLanding> {
  MusicServices get services => widget.services;
  late Future<List<MusicTrack>> _recent;
  late Future<List<MusicPlaylist>> _playlists;
  void _reload() {
    _recent = services.repository.recent(limit: 12);
    _playlists = services.repository.playlists();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _reload();
    services.repository.addListener(_reload);
  }

  @override
  void dispose() {
    services.repository.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: AnimatedBuilder(
          animation: services.controller,
          builder: (context, _) => services.controller.current == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        services.controller.play();
                        context.go('/music');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            MusicArtwork(
                              url: services.controller.current!.coverUrl,
                              size: 56,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '继续播放',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    services.controller.current!.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (services
                                          .controller
                                          .current!
                                          .artist
                                          ?.isNotEmpty ==
                                      true)
                                    Text(
                                      services.controller.current!.artist!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: services.controller.playing
                                  ? '暂停'
                                  : '继续播放',
                              onPressed: services.controller.togglePlayback,
                              icon: AppIcon(
                                services.controller.playing
                                    ? AppIcons.pause
                                    : AppIcons.play,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
      SliverToBoxAdapter(
        child: FutureBuilder<List<MusicTrack>>(
          future: _recent,
          builder: (context, snapshot) => snapshot.data?.isNotEmpty != true
              ? const SizedBox.shrink()
              : SizedBox(
                  height:
                      184 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 16, 8),
                        child: Text('最近播放'),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, i) {
                            final t = snapshot.data![i];
                            return SizedBox(
                              width: 142,
                              child: Card(
                                margin: const EdgeInsets.only(right: 10),
                                elevation: 0,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => musicAction(
                                    context,
                                    () => services.play([t], resume: true),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(9),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: MusicArtwork(
                                              url: t.coverUrl,
                                              size: 82,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          t.displayTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                        Text(
                                          t.artist?.isNotEmpty == true
                                              ? t.artist!
                                              : '最近播放',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      SliverToBoxAdapter(
        child: FutureBuilder<List<MusicPlaylist>>(
          future: _playlists,
          builder: (context, snapshot) {
            final items = snapshot.data;
            if (items == null || items.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height:
                  100 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 3),
              child: AppEntrance(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final playlist = items[i];
                    return SizedBox(
                      width: 240,
                      child: Card(
                        child: AppPressable(
                          child: ListTile(
                            leading: MusicArtwork(url: playlist.cover),
                            title: Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('${playlist.count} 集 · 播放列表'),
                            onTap: () => musicAction(context, () async {
                              final tracks = await services.repository.tracks(
                                playlist: playlist.id,
                                limit: 10000,
                              );
                              if (tracks.isEmpty) {
                                throw const FormatException('播放列表为空，请先添加音频');
                              }
                              await services.play(tracks);
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      const MusicDiscovery(sliver: true),
    ],
  );
}

class MusicWorkspace extends StatelessWidget {
  const MusicWorkspace({super.key});
  @override
  Widget build(BuildContext context) => const MusicScreen();
}

class MusicLibrary extends StatefulWidget {
  const MusicLibrary({
    super.key,
    required this.services,
    this.playlist,
    this.title,
  });
  final MusicServices services;
  final String? playlist, title;
  @override
  State<MusicLibrary> createState() => _MusicLibraryState();
}

class _MusicLibraryState extends State<MusicLibrary> {
  final _search = TextEditingController();
  final _selected = <String>{};
  final _scroll = ScrollController();
  Timer? _debounce;
  List<MusicTrack> _tracks = [];
  String? _error;
  bool _busy = false, _more = true, _favorite = false, _local = false;
  String _sort = 'title';
  String? _artist, _album;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.services.repository.addListener(_reload);
    _scroll.addListener(_nearEnd);
    _reload();
  }

  @override
  void dispose() {
    widget.services.repository.removeListener(_reload);
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _nearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _load();
  }

  void _reload() {
    _generation++;
    _tracks = [];
    _more = true;
    _busy = false;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_busy || !_more) return;
    _busy = true;
    final g = _generation;
    if (mounted) setState(() {});
    try {
      final data = await widget.services.repository.tracks(
        query: _search.text,
        playlist: widget.playlist,
        favorites: _favorite,
        artist: _artist,
        album: _album,
        offset: _tracks.length,
        sort: _sort,
        localOnly: _local,
      );
      if (!mounted || g != _generation) return;
      setState(() {
        _tracks.addAll(data);
        _more = data.length == 100;
        _error = null;
      });
    } catch (e) {
      if (mounted && g == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && g == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _batch(String action) async {
    final selected = _tracks.where((t) => _selected.contains(t.id)).toList();
    await musicAction(context, () async {
      if (action == 'play') {
        await widget.services.play(selected);
      }
      if (action == 'queue') {
        await widget.services.controller.addTracks(selected);
      }
      if (action == 'playlist') {
        if (!mounted) return;
        await choosePlaylist(context, widget.services, selected);
      }
      if (action == 'download') {
        await widget.services.downloads.enqueue(selected);
      }
      if (action == 'delete') {
        for (final t in selected) {
          if (widget.playlist != null) {
            await widget.services.repository.removeFromPlaylist(
              widget.playlist!,
              t.id,
            );
          } else {
            await widget.services.repository.remove(t.id);
          }
        }
      }
      if (mounted) setState(() => _selected.clear());
    });
  }

  Future<void> _group(bool artist) async {
    final names = await widget.services.repository.groups(artist);
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(artist ? '主播' : '专辑'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, ''),
            child: const Text('全部'),
          ),
          for (final n in names)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, n),
              child: Text(n),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (artist) {
        _artist = selected.isEmpty ? null : selected;
      } else {
        _album = selected.isEmpty ? null : selected;
      }
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: AppIcon(AppIcons.search),
            labelText: '搜索标题、主播、专辑',
          ),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 200), _reload);
          },
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('收藏'),
              selected: _favorite,
              onSelected: (v) {
                _favorite = v;
                _reload();
              },
            ),
            FilterChip(
              label: const Text('本地文件'),
              selected: _local,
              onSelected: (v) {
                _local = v;
                _reload();
              },
            ),
            PopupMenuButton<String>(
              tooltip: '排序',
              onSelected: (sort) {
                _sort = sort;
                _reload();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'title', child: Text('按名称')),
                PopupMenuItem(value: 'artist', child: Text('按主播')),
                PopupMenuItem(value: 'album', child: Text('按专辑')),
                PopupMenuItem(value: 'recent', child: Text('最近添加')),
              ],
              icon: const Icon(Icons.sort),
            ),
            TextButton(
              onPressed: () => _group(true),
              child: Text(_artist ?? '主播'),
            ),
            TextButton(
              onPressed: () => _group(false),
              child: Text(_album ?? '专辑'),
            ),
            if (_selected.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: _batch,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'play', child: Text('播放所选')),
                  PopupMenuItem(value: 'queue', child: Text('加入队列')),
                  PopupMenuItem(value: 'playlist', child: Text('加入播放列表')),
                  PopupMenuItem(value: 'download', child: Text('下载所选')),
                  PopupMenuItem(value: 'delete', child: Text('移除所选')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('已选 ${_selected.length} 项'),
                ),
              ),
          ],
        ),
      ),
      if (_error != null) Text(_error!),
      Expanded(
        child: _tracks.isEmpty && !_busy
            ? const Center(child: Text('音频库为空，请导入音频或从音频书源添加'))
            : ListView.builder(
                controller: _scroll,
                itemCount: _tracks.length + (_busy ? 1 : 0),
                itemBuilder: (c, i) {
                  if (i == _tracks.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final t = _tracks[i];
                  final selected = _selected.contains(t.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        minLeadingWidth: 96,
                        horizontalTitleGap: 10,
                        selected: selected,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 48,
                              child: Checkbox(
                                value: selected,
                                onChanged: (v) => setState(
                                  () => v == true
                                      ? _selected.add(t.id)
                                      : _selected.remove(t.id),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            MusicArtwork(url: t.coverUrl, size: 44),
                          ],
                        ),
                        title: Text(
                          t.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          [t.artist, t.album]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onLongPress: () => setState(() => _selected.add(t.id)),
                        onTap: () => musicAction(
                          context,
                          () => widget.services.play(_tracks, index: i),
                        ),
                        trailing: MusicTrackMenu(
                          track: t,
                          services: widget.services,
                          playlist: widget.playlist,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

Future<void> choosePlaylist(
  BuildContext context,
  MusicServices services,
  List<MusicTrack> tracks,
) async {
  final lists = await services.repository.playlists();
  if (!context.mounted) return;
  final id = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('加入播放列表'),
      children: [
        for (final p in lists)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, p.id),
            child: Text(p.name),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, 'new'),
          child: const Text('新建播放列表'),
        ),
      ],
    ),
  );
  if (id == null || !context.mounted) return;
  var target = id;
  if (id == 'new') {
    final name = await musicInput(context, '新建播放列表');
    if (name == null) return;
    target = await services.repository.createPlaylist(name);
  }
  await services.repository.addToPlaylist(target, tracks);
}

class MusicTrackMenu extends StatelessWidget {
  const MusicTrackMenu({
    super.key,
    required this.track,
    required this.services,
    this.playlist,
  });
  final MusicTrack track;
  final MusicServices services;
  final String? playlist;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '音频操作',
    onSelected: (a) => musicAction(context, () async {
      switch (a) {
        case 'next':
          await services.controller.playNext(track);
        case 'queue':
          await services.controller.addTracks([track]);
        case 'favorite':
          await services.repository.toggleFavorite(track);
        case 'playlist':
          await choosePlaylist(context, services, [track]);
        case 'download':
          await services.downloads.enqueue([track]);
        case 'delete':
          if (playlist != null) {
            await services.repository.removeFromPlaylist(playlist!, track.id);
          } else {
            await services.repository.remove(track.id);
          }
        case 'export':
          final key = track.ref?.localKey;
          if (key == null) throw const FormatException('请先下载到本地');
          final render = context.findRenderObject();
          await exportStoredMusic(
            services.store,
            key,
            key,
            origin: render is RenderBox
                ? render.localToGlobal(Offset.zero) & render.size
                : null,
          );
      }
    }),
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'next', child: Text('下一集播放')),
      const PopupMenuItem(value: 'queue', child: Text('加入队列')),
      const PopupMenuItem(value: 'favorite', child: Text('收藏／取消收藏')),
      const PopupMenuItem(value: 'playlist', child: Text('加入播放列表')),
      const PopupMenuItem(value: 'download', child: Text('离线下载')),
      if (track.ref?.localKey != null)
        const PopupMenuItem(value: 'export', child: Text('导出音频')),
      PopupMenuItem(
        value: 'delete',
        child: Text(playlist == null ? '移出音频库' : '移出播放列表'),
      ),
    ],
  );
}

class MusicPlaylists extends StatefulWidget {
  const MusicPlaylists({super.key, required this.services});
  final MusicServices services;
  @override
  State<MusicPlaylists> createState() => _MusicPlaylistsState();
}

class _MusicPlaylistsState extends State<MusicPlaylists> {
  late Future<List<MusicPlaylist>> _items;
  @override
  void initState() {
    super.initState();
    widget.services.repository.addListener(_reload);
    _items = widget.services.repository.playlists();
  }

  void _reload() {
    if (mounted) {
      setState(() => _items = widget.services.repository.playlists());
    }
  }

  @override
  void dispose() {
    widget.services.repository.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => musicAction(context, () async {
            final n = await musicInput(context, '新建播放列表');
            if (n != null) await widget.services.repository.createPlaylist(n);
          }),
          icon: const Icon(Icons.add),
          label: const Text('新建播放列表'),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<MusicPlaylist>>(
          future: _items,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.isEmpty) {
              return const Center(child: Text('暂无播放列表，创建后可添加音频'));
            }
            return ListView.builder(
              itemCount: s.data!.length,
              itemBuilder: (c, i) {
                final p = s.data![i];
                return ListTile(
                  leading: MusicArtwork(url: p.cover),
                  title: Text(p.name),
                  subtitle: Text('${p.count} 集'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(p.name),
                          actions: [
                            IconButton(
                              tooltip: '随机播放',
                              onPressed: () => musicAction(context, () async {
                                final tracks = await widget.services.repository
                                    .tracks(playlist: p.id, limit: 10000);
                                widget.services.controller.shuffle = true;
                                await widget.services.play(tracks);
                              }),
                              icon: const Icon(Icons.shuffle),
                            ),
                          ],
                        ),
                        body: MusicLibrary(
                          services: widget.services,
                          playlist: p.id,
                        ),
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) => musicAction(context, () async {
                      if (a == 'reorder') {
                        if (!mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MusicPlaylistOrder(
                              services: widget.services,
                              playlist: p,
                            ),
                          ),
                        );
                      } else if (a == 'delete') {
                        await widget.services.repository.deletePlaylist(p.id);
                      } else if (a == 'export') {
                        final tracks = await widget.services.repository.tracks(
                          playlist: p.id,
                          limit: 10000,
                        );
                        final bytes = Uint8List.fromList(
                          utf8.encode(
                            jsonEncode({
                              'name': p.name,
                              'tracks': [for (final t in tracks) t.toJson()],
                            }),
                          ),
                        );
                        await saveMusicBytes(bytes, '${p.name}.json');
                      } else {
                        final v = await musicInput(
                          context,
                          a == 'cover' ? '封面地址' : '重命名',
                          value: a == 'cover' ? p.cover ?? '' : p.name,
                        );
                        if (v != null) {
                          await widget.services.repository.renamePlaylist(
                            p.id,
                            a == 'cover' ? p.name : v,
                            cover: a == 'cover' ? v : null,
                          );
                        }
                      }
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'reorder', child: Text('调整顺序')),
                      PopupMenuItem(value: 'rename', child: Text('重命名')),
                      PopupMenuItem(value: 'cover', child: Text('编辑封面')),
                      PopupMenuItem(value: 'export', child: Text('导出播放列表')),
                      PopupMenuItem(value: 'delete', child: Text('删除播放列表')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class MusicDownloads extends StatelessWidget {
  const MusicDownloads({super.key, required this.services});
  final MusicServices services;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: services.downloads,
    builder: (c, _) => services.downloads.tasks.isEmpty
        ? const Center(child: Text('暂无下载，在音频菜单中选择“离线下载”'))
        : ListView.builder(
            itemCount: services.downloads.tasks.length,
            itemBuilder: (c, i) {
              final t = services.downloads.tasks[i];
              return ListTile(
                title: Text(t.track.displayTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${switch (t.status) {
                        AudioDownloadStatus.queued => '等待下载',
                        AudioDownloadStatus.downloading => '下载中',
                        AudioDownloadStatus.paused => '已暂停',
                        AudioDownloadStatus.complete => '已完成',
                        AudioDownloadStatus.failed => '失败',
                      }} · ${(t.completed / 1048576).toStringAsFixed(1)} MiB'
                      '${t.total > 0 ? ' / ${(t.total / 1048576).toStringAsFixed(1)} MiB' : ''}'
                      '${t.status == AudioDownloadStatus.downloading ? ' · ${(t.bytesPerSecond / 1024).toStringAsFixed(0)} KiB/s' : ''}',
                    ),
                    if (t.status == AudioDownloadStatus.downloading)
                      LinearProgressIndicator(
                        value: t.total == 0 ? null : t.progress,
                      ),
                    if (t.error != null)
                      Text(
                        t.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                onTap: t.status == AudioDownloadStatus.complete
                    ? () => musicAction(context, () => services.play([t.track]))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.status == AudioDownloadStatus.complete)
                      IconButton(
                        tooltip: '导出离线资源包',
                        icon: const AppIcon(AppIcons.open),
                        onPressed: () => musicAction(context, () async {
                          final render = context.findRenderObject();
                          await exportMusicBundle(
                            services.store,
                            t.files,
                            {
                              'version': 1,
                              'track': t.track.toJson(),
                              'files': t.files,
                            },
                            t.track.displayTitle,
                            origin: render is RenderBox
                                ? render.localToGlobal(Offset.zero) &
                                      render.size
                                : null,
                          );
                        }),
                      ),
                    if (t.status != AudioDownloadStatus.complete)
                      IconButton(
                        tooltip: t.status == AudioDownloadStatus.downloading
                            ? '暂停'
                            : '继续／重试',
                        onPressed: () =>
                            t.status == AudioDownloadStatus.downloading
                            ? services.downloads.pause(t)
                            : services.downloads.resume(t),
                        icon: Icon(
                          t.status == AudioDownloadStatus.downloading
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                    IconButton(
                      tooltip: '删除下载文件',
                      onPressed: () => musicAction(
                        context,
                        () => services.downloads.remove(t),
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}

final readerMusicControlsVisible = ValueNotifier<bool>(true);

class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(musicServicesProvider).controller;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => c.current == null
          ? const SizedBox.shrink()
          : Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: c.positionListenable,
                    builder: (_, p, _) => LinearProgressIndicator(
                      minHeight: 2,
                      value: c.duration > Duration.zero
                          ? (p.inMilliseconds / c.duration.inMilliseconds)
                                .clamp(0, 1)
                          : 0,
                    ),
                  ),
                  SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        MusicArtwork(url: c.current!.coverUrl),
                        Expanded(
                          child: InkWell(
                            onTap: () => context.go('/music'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.current!.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    c.error != null
                                        ? '播放失败，点击重试'
                                        : c.loading
                                        ? '解析／加载中…'
                                        : c.current!.artist ?? '音频',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: c.playing ? '暂停' : '播放',
                          onPressed: c.togglePlayback,
                          icon: AppIcon(
                            c.playing ? AppIcons.pause : AppIcons.play,
                          ),
                        ),
                        IconButton(
                          tooltip: '下一集',
                          onPressed: c.hasNext ? c.next : null,
                          icon: const AppIcon(AppIcons.skipNext),
                        ),
                        IconButton(
                          tooltip: '播放队列',
                          onPressed: () => showMusicQueue(context, c),
                          icon: const AppIcon(AppIcons.queue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

void showMusicQueue(BuildContext context, MusicController c) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: MusicQueue(controller: c),
      ),
    );

class MusicQueue extends StatelessWidget {
  const MusicQueue({super.key, required this.controller});
  final MusicController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      children: [
        ListTile(
          title: Text('播放队列 · ${controller.queue.length} 集'),
          trailing: TextButton(
            onPressed: controller.clearQueue,
            child: const Text('停止并清空'),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: controller.queue.length,
            onReorderItem: controller.moveQueue,
            itemBuilder: (c, i) {
              final t = controller.queue[i];
              return ListTile(
                key: ValueKey('queue-$i-${t.id}'),
                selected: i == controller.index,
                title: Text(
                  t.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(t.artist ?? ''),
                leading: AppIcon(
                  i == controller.index ? AppIcons.equalizer : AppIcons.music,
                ),
                onTap: () => controller.select(i),
                trailing: IconButton(
                  tooltip: '移出队列',
                  onPressed: () => controller.removeAt(i),
                  icon: const Icon(Icons.close),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class MusicFullPlayer extends ConsumerStatefulWidget {
  const MusicFullPlayer({super.key});
  @override
  ConsumerState<MusicFullPlayer> createState() => _MusicFullPlayerState();
}

class _MusicFullPlayerState extends ConsumerState<MusicFullPlayer> {
  bool _queue = false, _translation = true, _romanization = true;
  @override
  void initState() {
    super.initState();
    final settings = ref.read(musicServicesProvider).settings;
    _translation = settings['lyricTranslation'] != false;
    _romanization = settings['lyricRomanization'] != false;
    _font = (settings['lyricFont'] as num? ?? 20).toDouble();
  }

  double _font = 20;
  Future<void> _lyrics(MusicServices s) async {
    final t = s.controller.current;
    if (t == null) return;
    await musicAction(context, () async {
      final chosen = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['lrc', 'txt', 'srt', 'vtt', 'json'],
        withData: true,
      );
      if (chosen?.files.single.bytes != null) {
        await s.importLyrics(t, chosen!.files.single.bytes!);
      }
    });
  }

  bool get _editing {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus?.widget is EditableText ||
        focus?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Widget _lyricView(MusicController c, {bool immersive = false}) =>
      ValueListenableBuilder<int>(
        valueListenable: c.lyricLineListenable,
        builder: (_, line, _) => LyricsView(
          document: c.lyrics,
          position: c.position,
          currentLine: line,
          positionListenable: c.positionListenable,
          offset: Duration(milliseconds: c.lyricOffset),
          onSeek: c.seek,
          showTranslation: _translation,
          showRomanization: _romanization,
          fontSize: _font,
          immersive: immersive,
        ),
      );

  Widget _backdrop(String? coverUrl) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.32),
            radius: 1.35,
            colors: [
              Color(0xFF30212A),
              Color(0xFF171317),
              Color(0xFF100D11),
            ],
            stops: [0, .62, 1],
          ),
        ),
      ),
      if (coverUrl?.isNotEmpty == true)
        ClipRect(
          child: Opacity(
            opacity: .42,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: FittedBox(
                fit: BoxFit.cover,
                child: MusicArtwork(url: coverUrl, size: 900),
              ),
            ),
          ),
        ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xA6100E12), Color(0x75120E13), Color(0xB30B090C)],
            stops: [0, .48, 1],
          ),
        ),
      ),
    ],
  );

  Widget _roundArtwork(String? coverUrl, double size) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFE56542), width: 2.4),
      boxShadow: const [
        BoxShadow(color: Color(0x55000000), blurRadius: 34, spreadRadius: 3),
      ],
    ),
    child: ClipOval(
      child: MusicArtwork(url: coverUrl, size: size - 6),
    ),
  );

  Widget _lyricPanel(MusicController c, MusicServices services) {
    if (c.lyrics.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '这段音频还没有字幕',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .88),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '字幕会在这里随播放进度滚动',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: .56),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _lyrics(services),
                icon: const AppIcon(AppIcons.file, size: 18),
                label: const Text('导入字幕'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .2, .8, 1],
      ).createShader(bounds),
      child: _lyricView(c, immersive: true),
    );
  }

  Future<void> _showVolume(MusicController c) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF211E21),
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '音量',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                children: [
                  AppIcon(
                    c.volume == 0 ? AppIcons.volumeOff : AppIcons.volume,
                    color: Colors.white70,
                  ),
                  Expanded(
                    child: Slider(value: c.volume, onChanged: c.setVolume),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text('${(c.volume * 100).round()}%'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _transport(
    MusicController c,
    double width, {
    required bool compact,
    required bool ultraCompact,
  }) {
    final duration = c.duration;
    final canSeek =
        !c.loading && c.current?.live != true && duration > Duration.zero;
    final roomy = width >= 390 && !compact;
    final iconColor = Colors.white.withValues(alpha: .86);
    Widget iconButton({
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
    }) => IconButton(
      tooltip: label,
      onPressed: onPressed,
      color: iconColor,
      disabledColor: Colors.white.withValues(alpha: .3),
      icon: AppIcon(icon, size: 23),
      constraints: BoxConstraints(minWidth: 44, minHeight: compact ? 44 : 48),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 12,
        compact ? 0 : 4,
        compact ? 6 : 12,
        compact ? 0 : 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton.icon(
                onPressed: c.retry,
                icon: const AppIcon(AppIcons.refresh, size: 18),
                label: const Text('播放失败，点此重试'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            )
          else if (c.loading || c.phase == MusicPhase.buffering)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF916D),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.loading ? '正在加载音频' : '正在缓冲',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (!ultraCompact)
            ValueListenableBuilder<Duration>(
              valueListenable: c.positionListenable,
              builder: (context, currentPosition, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    key: const ValueKey('music-progress'),
                    value: duration > Duration.zero
                        ? currentPosition.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble()
                        : 0,
                    max: duration > Duration.zero
                        ? duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: canSeek
                        ? (value) =>
                              c.seek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatMusicTime(currentPosition),
                              style: TextStyle(
                                fontSize: compact ? 11 : 14,
                                color: Colors.white70,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerRight,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              c.current?.live == true
                                  ? '直播'
                                  : duration == Duration.zero
                                  ? '时长未知'
                                  : formatMusicTime(duration),
                              style: TextStyle(
                                fontSize: compact ? 11 : 14,
                                color: Colors.white70,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (roomy)
                iconButton(
                  label: '后退15秒',
                  icon: AppIcons.replay,
                  onPressed: canSeek ? () => c.skip(-15) : null,
                ),
              iconButton(
                label: '上一集',
                icon: AppIcons.skipPrevious,
                onPressed: c.hasPrevious ? c.previous : null,
              ),
              SizedBox.square(
                dimension: compact ? 48 : 64,
                child: IconButton.filled(
                  tooltip: c.playing ? '暂停' : '播放',
                  onPressed: c.loading ? null : c.togglePlayback,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF171416),
                    disabledBackgroundColor: Colors.white70,
                    disabledForegroundColor: Colors.black45,
                    shape: const CircleBorder(),
                  ),
                  iconSize: compact ? 21 : 28,
                  icon: AppIcon(
                    c.playing ? AppIcons.pause : AppIcons.play,
                    color: const Color(0xFF171416),
                  ),
                ),
              ),
              iconButton(
                label: '下一集',
                icon: AppIcons.skipNext,
                onPressed: c.hasNext ? c.next : null,
              ),
              if (roomy)
                iconButton(
                  label: '前进15秒',
                  icon: AppIcons.forward10,
                  onPressed: canSeek ? () => c.skip(15) : null,
                ),
            ],
          ),
          if (!compact && !ultraCompact)
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PopupMenuButton<double>(
                    tooltip: '播放速度',
                    initialValue: c.speed,
                    onSelected: c.setSpeed,
                    itemBuilder: (_) =>
                        const <double>[.5, .75, 1, 1.25, 1.5, 2, 2.5, 3].map((
                          speed,
                        ) {
                          final label = speed == 1 ? '正常速度' : '$speed 倍速';
                          return PopupMenuItem(
                            value: speed,
                            child: Text(label),
                          );
                        }).toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${c.speed.toStringAsFixed(c.speed % 1 == 0 ? 0 : 2)}×',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const AppIcon(
                            AppIcons.arrowDown,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (width >= 350) ...[
                    IconButton(
                      tooltip: '音量 ${(c.volume * 100).round()}%',
                      onPressed: () => _showVolume(c),
                      color: Colors.white70,
                      icon: AppIcon(
                        c.volume == 0 ? AppIcons.volumeOff : AppIcons.volume,
                        size: 19,
                      ),
                    ),
                    if (width >= 570)
                      SizedBox(
                        width: math.min(130.0, width * .16),
                        child: Slider(value: c.volume, onChanged: c.setVolume),
                      ),
                  ],
                  IconButton(
                    tooltip: switch (c.repeat) {
                      MusicRepeat.off => '顺序播放',
                      MusicRepeat.all => '列表循环',
                      MusicRepeat.one => '单集循环',
                    },
                    onPressed: c.cycleRepeat,
                    color: c.repeat == MusicRepeat.off
                        ? Colors.white70
                        : const Color(0xFFFF916D),
                    icon: AppIcon(
                      c.repeat == MusicRepeat.one
                          ? AppIcons.restart
                          : AppIcons.refresh,
                      size: 19,
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: '定时停止',
                    onSelected: (minutes) => c.setSleepTimer(
                      minutes == 0 ? null : Duration(minutes: minutes),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: Text('取消定时')),
                      PopupMenuItem(value: 15, child: Text('15分钟后停止')),
                      PopupMenuItem(value: 30, child: Text('30分钟后停止')),
                      PopupMenuItem(value: 60, child: Text('60分钟后停止')),
                    ],
                    child: IconButton(
                      tooltip: '定时停止',
                      onPressed: null,
                      color: c.sleepUntil == null
                          ? Colors.white70
                          : const Color(0xFFFF916D),
                      icon: const AppIcon(AppIcons.timer, size: 19),
                    ),
                  ),
                  IconButton(
                    tooltip: '播放队列',
                    onPressed: () => showMusicQueue(context, c),
                    color: Colors.white70,
                    icon: const AppIcon(AppIcons.queue, size: 19),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _menu(String action, MusicServices s) async {
    await musicAction(context, () async {
      final c = s.controller;
      switch (action) {
        case 'lyrics':
          await _lyrics(s);
        case 'bookSettings':
          final intro = await musicInput(
            context,
            '跳过片头（秒）',
            value: '${c.skipIntroSeconds}',
          );
          if (intro == null || !mounted) return;
          final outro = await musicInput(
            context,
            '跳过片尾（秒）',
            value: '${c.skipOutroSeconds}',
          );
          if (outro != null) {
            c.skipIntroSeconds = int.parse(intro).clamp(0, 3600);
            c.skipOutroSeconds = int.parse(outro).clamp(0, 3600);
            await s.flush();
          }
        case 'offset':
          final value = await musicInput(
            context,
            '字幕偏移（毫秒，正数延后）',
            value: '${c.lyricOffset}',
          );
          if (value != null) await s.offset(int.parse(value));
        case 'lyricStyle':
          if (!mounted) return;
          await showModalBottomSheet<void>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, refresh) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('显示翻译'),
                    value: _translation,
                    onChanged: (v) {
                      setState(() => _translation = v);
                      refresh(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('显示音译'),
                    value: _romanization,
                    onChanged: (v) {
                      setState(() => _romanization = v);
                      refresh(() {});
                    },
                  ),
                  Slider(
                    value: _font,
                    min: 14,
                    max: 36,
                    onChanged: (v) {
                      setState(() => _font = v);
                      refresh(() {});
                    },
                  ),
                ],
              ),
            ),
          );
          await s.updateSettings({
            'lyricTranslation': _translation,
            'lyricRomanization': _romanization,
            'lyricFont': _font,
          });
        case 'fullLyrics':
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('字幕')),
                body: _lyricView(c),
              ),
            ),
          );
        case 'download':
          if (c.current != null) await s.downloads.enqueue([c.current!]);
        case 'playlist':
          if (c.current != null) await choosePlaylist(context, s, [c.current!]);
        case 'favorite':
          if (c.current != null) await s.repository.toggleFavorite(c.current!);
        case 'exportLyrics':
          final text = c.current?.lyric;
          if (text != null) {
            await saveMusicBytes(
              Uint8List.fromList(utf8.encode(text)),
              '${c.current!.displayTitle}.lrc',
            );
          }
        case 'retry':
          await c.retry();
        case 'customTimer':
          final n = await musicInput(context, '停止计时（分钟）', value: '30');
          if (n != null) {
            final minutes = int.parse(n);
            if (minutes < 1 || minutes > 1440) {
              throw const FormatException('请输入 1–1440 分钟');
            }
            c.setSleepTimer(Duration(minutes: minutes));
          }
        case 'endTimer':
          c.stopAtEnd = true;
          c.setSleepTimer(null);
          musicMessage(context, '当前一集播完后停止');
        case 'info':
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('资源详情'),
              content: SelectableText(
                '${c.current?.displayTitle ?? ''}\n${c.current?.artist ?? ''}\n${c.current?.album ?? ''}\n来源：${c.current?.ref?.origin.name ?? '地址'}\n分段：${c.current?.segments.length ?? 1}\n${c.current?.live == true ? '直播' : '点播'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(musicServicesProvider), c = s.controller;
    const accent = Color(0xFFFF916D);
    final base = Theme.of(context);
    final playerTheme = base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF111013),
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: const Color(0xFF21110C),
        surface: const Color(0xFF211E21),
        surfaceContainerHighest: const Color(0xFF342F32),
        onSurface: const Color(0xFFF8F2F1),
        onSurfaceVariant: const Color(0xFFC5BDBF),
        primaryContainer: const Color(0xFF542A1F),
        onPrimaryContainer: const Color(0xFFFFD5C8),
        outline: Colors.white38,
        outlineVariant: Colors.white24,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFF8F2F1),
        displayColor: const Color(0xFFF8F2F1),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white30,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: .16),
        trackHeight: 2.2,
      ),
    );
    return Theme(
      data: playerTheme,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (!_editing) c.togglePlayback();
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (!_editing) c.skip(-15);
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (!_editing) c.skip(15);
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: const Color(0xFF111013),
            appBar: AppBar(
              titleSpacing: 0,
              title: AnimatedBuilder(
                animation: c,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.current?.displayTitle ?? '正在播放',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: '播放队列',
                  onPressed: () {
                    if (MediaQuery.sizeOf(context).width >=
                        AppTokens.bpExtended) {
                      setState(() => _queue = !_queue);
                    } else {
                      showMusicQueue(context, c);
                    }
                  },
                  icon: const AppIcon(AppIcons.queue),
                ),
                AnimatedBuilder(
                  animation: c,
                  builder: (context, _) => IconButton(
                    tooltip: c.shuffle ? '关闭随机播放' : '随机播放',
                    onPressed: c.toggleShuffle,
                    color: c.shuffle ? accent : Colors.white,
                    icon: const AppIcon(AppIcons.shuffle),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多播放操作',
                  onSelected: (a) => _menu(a, s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'favorite', child: Text('收藏／取消收藏')),
                    PopupMenuItem(value: 'playlist', child: Text('加入播放列表')),
                    PopupMenuItem(value: 'download', child: Text('离线下载')),
                    PopupMenuItem(value: 'lyrics', child: Text('导入字幕')),
                    PopupMenuItem(value: 'offset', child: Text('字幕偏移')),
                    PopupMenuItem(
                      value: 'bookSettings',
                      child: Text('音频书片头／片尾'),
                    ),
                    PopupMenuItem(value: 'lyricStyle', child: Text('字幕显示设置')),
                    PopupMenuItem(value: 'fullLyrics', child: Text('全屏字幕')),
                    PopupMenuItem(value: 'exportLyrics', child: Text('导出字幕')),
                    PopupMenuItem(value: 'customTimer', child: Text('自定义定时停止')),
                    PopupMenuItem(value: 'endTimer', child: Text('当前一集播完后停止')),
                    PopupMenuItem(value: 'retry', child: Text('重新解析')),
                    PopupMenuItem(value: 'info', child: Text('资源详情')),
                  ],
                  icon: const AppIcon(AppIcons.more),
                ),
              ],
            ),
            body: AnimatedBuilder(
              animation: c,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  _backdrop(c.current?.coverUrl),
                  SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, _) {
                        final topClearance =
                            MediaQuery.paddingOf(context).top + kToolbarHeight;
                        return Padding(
                          padding: EdgeInsets.only(top: topClearance),
                          child: LayoutBuilder(
                            builder: (context, inner) {
                              final compact = inner.maxHeight < 360;
                              final wide = inner.maxWidth >= AppTokens.bpRail;
                              final track = c.current;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  2,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: track == null
                                          ? _emptyPlayer()
                                          : wide
                                          ? _wideStage(
                                              c,
                                              s,
                                              inner.maxWidth,
                                              compact: compact,
                                            )
                                          : _mobileStage(
                                              c,
                                              s,
                                              inner.maxWidth,
                                              compact: compact,
                                            ),
                                    ),
                                    if (track != null)
                                      _transport(
                                        c,
                                        inner.maxWidth,
                                        compact: compact,
                                        ultraCompact: inner.maxHeight < 150,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPlayer() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(AppIcons.album, size: 54, color: Colors.white54),
        const SizedBox(height: 14),
        const Text('播放队列还是空的', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        const Text('从音频库、书源或本地文件选择音频'),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const AppIcon(AppIcons.back, size: 18),
          label: const Text('返回音频库'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ],
    ),
  );

  Widget _compactStage(MusicController c) => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundArtwork(c.current?.coverUrl, 44),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.current?.displayTitle ?? '正在播放',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mobileStage(
    MusicController c,
    MusicServices services,
    double width, {
    required bool compact,
  }) {
    if (compact) {
      return LayoutBuilder(
        builder: (context, box) =>
            box.maxHeight < 80 ? const SizedBox.shrink() : _compactStage(c),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final artworkSize = math
            .min(width * .72, box.maxHeight * .49)
            .clamp(120.0, 380.0)
            .toDouble();
        return Column(
          children: [
            SizedBox(
              height: artworkSize,
              child: Center(
                child: _roundArtwork(c.current?.coverUrl, artworkSize),
              ),
            ),
            if (c.current?.artist?.isNotEmpty == true ||
                c.current?.album?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  [c.current?.artist, c.current?.album]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .58),
                  ),
                ),
              ),
            Expanded(child: _lyricPanel(c, services)),
          ],
        );
      },
    );
  }

  Widget _wideStage(
    MusicController c,
    MusicServices services,
    double width, {
    required bool compact,
  }) {
    if (compact) {
      return LayoutBuilder(
        builder: (context, box) =>
            box.maxHeight < 80 ? const SizedBox.shrink() : _compactStage(c),
      );
    }
    final showQueue = _queue && width >= AppTokens.bpExtended;
    final queueWidth = showQueue ? 290.0 : 0.0;
    final stageWidth = width - queueWidth;
    return Row(
      children: [
        SizedBox(
          width: math.min(stageWidth * .43, 490),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math
                  .min(box.maxWidth * .78, box.maxHeight * .58)
                  .clamp(150.0, 420.0)
                  .toDouble();
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roundArtwork(c.current?.coverUrl, size),
                    if (c.current?.artist?.isNotEmpty == true ||
                        c.current?.album?.isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      Text(
                        [c.current?.artist, c.current?.album]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
            child: _lyricPanel(c, services),
          ),
        ),
        if (showQueue)
          SizedBox(
            width: queueWidth,
            child: Material(
              color: Colors.black.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: MusicQueue(controller: c),
            ),
          ),
      ],
    );
  }
}

class MusicResolveScreen extends ConsumerStatefulWidget {
  const MusicResolveScreen({super.key});
  @override
  ConsumerState<MusicResolveScreen> createState() => _MusicResolveState();
}

class _MusicResolveState extends ConsumerState<MusicResolveScreen> {
  final _input = TextEditingController();
  ResolvedAudio? _resolved;
  int _variant = 0;
  bool _busy = false;
  String? _error;
  MusicOperation? _op;
  bool _continuous = false;
  @override
  void dispose() {
    _op?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    _op?.cancel();
    final op = _op = MusicOperation();
    setState(() {
      _busy = true;
      _error = null;
      _resolved = null;
      _variant = 0;
      _continuous = false;
    });
    try {
      final refTrack = TrackRef(
        id: TrackRef.identity(_input.text.trim()),
        address: _input.text.trim(),
      );
      final audio = await ref
          .read(musicServicesProvider)
          .resolver
          .resolve(refTrack, op);
      if (mounted && !op.cancelled) setState(() => _resolved = audio);
    } on AudioSelectionRequired catch (selection) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('选择音频'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'segments'),
              child: const Text('作为一首音频的连续分段'),
            ),
            for (var i = 0; i < selection.choices.length; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, selection.choices[i]),
                child: Text(
                  '音轨 ${i + 1}：${selection.choices[i]}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
      if (choice != null && mounted) {
        if (choice == 'segments') {
          setState(() {
            _continuous = true;
            _resolved = parseAudio(_input.text, chapter: true);
          });
        } else {
          _input.text = choice;
          await _resolve();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(bool play) async {
    if (_resolved == null) return;
    final s = ref.read(musicServicesProvider);
    await musicAction(context, () async {
      final track = await s.preparedTrack(
        TrackRef(
          id: TrackRef.identity(_input.text.trim()),
          address: _input.text.trim(),
          title: _resolved!.title ?? '音频',
          variant: _variant,
          continuous: _continuous,
        ),
        _resolved!,
        variant: _variant,
      );
      await s.repository.saveTrack(track);
      await s.controller.addTracks([track], playFirst: play);
      if (mounted) musicMessage(context, play ? '开始播放' : '已加入队列');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('音频解析')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _input,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: '音频地址、网页、HTML 或 JSON'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _resolve,
          child: Text(_busy ? '解析中…' : '解析并预览'),
        ),
        if (_busy)
          TextButton(
            onPressed: () {
              _op?.cancel();
              setState(() => _busy = false);
            },
            child: const Text('取消'),
          ),
        if (_error != null) Text(_error!),
        if (_resolved != null) ...[
          const SizedBox(height: 24),
          MusicArtwork(url: _resolved!.coverUrl, size: 120),
          Text(
            _resolved!.title ?? '音频',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(_resolved!.artist ?? ''),
          DropdownButton<int>(
            value: _variant.clamp(0, _resolved!.variants.length - 1),
            items: [
              for (var i = 0; i < _resolved!.variants.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${_resolved!.variants[i].label} · ${_resolved!.variants[i].segments.length} 个分段',
                  ),
                ),
            ],
            onChanged: (i) => setState(() => _variant = i ?? 0),
          ),
          Text(_resolved!.lyric == null ? '暂无字幕' : '已解析字幕'),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => _add(true),
                child: const Text('播放'),
              ),
              OutlinedButton(
                onPressed: () => _add(false),
                child: const Text('加入队列'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class MusicSettingsScreen extends ConsumerWidget {
  const MusicSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(musicServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('音频设置')),
      body: AnimatedBuilder(
        animation: s.controller,
        builder: (c, _) => ListView(
          children: [
            ListTile(
              title: const Text('默认播放速度'),
              subtitle: Text('${s.controller.speed}×'),
              trailing: DropdownButton<double>(
                value:
                    const [
                      .5,
                      .75,
                      1.0,
                      1.25,
                      1.5,
                      2.0,
                      2.5,
                      3.0,
                    ].contains(s.controller.speed)
                    ? s.controller.speed
                    : 1.0,
                items: [
                  for (final speed in const [
                    .5,
                    .75,
                    1.0,
                    1.25,
                    1.5,
                    2.0,
                    2.5,
                    3.0,
                  ])
                    DropdownMenuItem(value: speed, child: Text('$speed×')),
                ],
                onChanged: (v) {
                  if (v != null) s.controller.setSpeed(v);
                },
              ),
            ),
            const ListTile(
              title: Text('重启恢复'),
              subtitle: Text('恢复队列和进度，保持暂停，点击播放后继续'),
            ),
            const ListTile(
              title: Text('下载策略'),
              subtitle: Text('并发 2 项，单主机 1 项；支持文件、分段及 HLS 点播'),
            ),
            const ListTile(
              title: Text('持久保存'),
              subtitle: Text('本地导入及下载内容不会随缓存清理删除'),
            ),
            ListTile(
              title: const Text('播放状态'),
              subtitle: Text(
                s.controller.error ??
                    '${s.controller.phase.name} · 系统媒体控制随首次播放初始化',
              ),
            ),
            ListTile(
              title: const Text('停止并清空播放队列'),
              onTap: s.controller.clearQueue,
              leading: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicPlaylistOrder extends StatefulWidget {
  const MusicPlaylistOrder({
    super.key,
    required this.services,
    required this.playlist,
  });
  final MusicServices services;
  final MusicPlaylist playlist;
  @override
  State<MusicPlaylistOrder> createState() => _MusicPlaylistOrderState();
}

class _MusicPlaylistOrderState extends State<MusicPlaylistOrder> {
  List<MusicTrack>? _tracks;
  String? _error;
  @override
  void initState() {
    super.initState();
    widget.services.repository
        .tracks(playlist: widget.playlist.id, limit: 10000)
        .then((tracks) {
          if (mounted) setState(() => _tracks = tracks);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = '$e');
        });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.playlist.name} · 排序')),
    body: _error != null
        ? Center(child: Text(_error!))
        : _tracks == null
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView.builder(
            itemCount: _tracks!.length,
            onReorderItem: (from, to) {
              setState(() {
                final t = _tracks!.removeAt(from);
                _tracks!.insert(to, t);
              });
              musicAction(
                context,
                () => widget.services.repository.reorderPlaylist(
                  widget.playlist.id,
                  _tracks!.map((t) => t.id).toList(),
                ),
              );
            },
            itemBuilder: (context, i) => ListTile(
              key: ValueKey(_tracks![i].id),
              title: Text(_tracks![i].displayTitle),
              leading: const Icon(Icons.drag_handle),
            ),
          ),
  );
}
