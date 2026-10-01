import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'audio_types.dart';
import 'music_services.dart';
import 'music_controller.dart';
import 'media_player_screen.dart';

class MusicChapterView extends ConsumerStatefulWidget {
  const MusicChapterView({
    super.key,
    required this.source,
    required this.book,
    required this.chapter,
    required this.chapters,
    required this.content,
  });
  final BookSource source;
  final Book book;
  final BookChapter chapter;
  final List<BookChapter> chapters;
  final String content;
  @override
  ConsumerState<MusicChapterView> createState() => _MusicChapterViewState();
}

class _MusicChapterViewState extends ConsumerState<MusicChapterView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_open);
  }

  @override
  void didUpdateWidget(covariant MusicChapterView old) {
    super.didUpdateWidget(old);
    if (old.chapter.url != widget.chapter.url) Future.microtask(_open);
  }

  Future<void> _open() async {
    if (!mounted) return;
    final s = ref.read(musicServicesProvider);
    final book = widget.book;
    final chapters = widget.chapters.isEmpty
        ? [widget.chapter]
        : widget.chapters;
    final tracks = [
      for (final ch in chapters)
        MusicTrack(
          url: '',
          title: ch.title,
          artist: book.author,
          album: book.name,
          coverUrl: book.coverUrl,
          ref: TrackRef(
            id: TrackRef.identity(
              '${widget.source.bookSourceUrl}\u0000${book.bookUrl}\u0000${ch.url}',
            ),
            origin: TrackOrigin.source,
            sourceId: widget.source.bookSourceUrl,
            book: book.toJson(),
            chapter: (ch.url == widget.chapter.url ? widget.chapter : ch)
                .toJson(),
            title: ch.title,
            artist: book.author,
            album: book.name,
          ),
        ),
    ];
    final index = chapters
        .indexWhere((c) => c.url == widget.chapter.url)
        .clamp(0, chapters.length - 1);
    if (s.controller.current?.id == tracks[index].id) return;
    s.seedContent[tracks[index].id] = widget.content;
    try { await s.play(tracks, index: index); } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('播放失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) =>
      MusicPlayerPanel(controller: ref.watch(musicServicesProvider).controller);
}
