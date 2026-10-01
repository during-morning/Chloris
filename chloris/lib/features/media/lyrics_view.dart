import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'lyrics.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.document,
    required this.position,
    required this.onSeek,
    this.currentLine,
    this.positionListenable,
    this.offset = Duration.zero,
    this.showTranslation = true,
    this.showRomanization = true,
    this.fontSize = 18,
    this.textAlign = TextAlign.center,
    this.immersive = false,
  });
  final LyricDocument document;
  final Duration position, offset;
  final ValueChanged<Duration> onSeek;
  final int? currentLine;
  final ValueListenable<Duration>? positionListenable;
  final bool showTranslation, showRomanization;
  final double fontSize;
  final TextAlign textAlign;

  /// Uses the subdued foreground and transparent active row of an album-art
  /// player, while keeping the regular library lyric styling unchanged.
  final bool immersive;
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _scroll = ScrollController();
  Timer? _resume;
  bool _following = true;
  bool _hasTranslation = false, _hasRomanization = false;
  void _languages() {
    _hasTranslation = widget.document.lines.any(
      (line) => line.translation?.isNotEmpty == true,
    );
    _hasRomanization = widget.document.lines.any(
      (line) => line.romanization?.isNotEmpty == true,
    );
  }

  double get _height =>
      (MediaQuery.textScalerOf(context).scale(widget.fontSize) *
                  (4.8 +
                      (widget.showTranslation && _hasTranslation ? 2.6 : 0) +
                      (widget.showRomanization && _hasRomanization ? 1.3 : 0)) +
              16)
          .clamp(80, double.infinity);
  int get _current =>
      widget.currentLine ??
      widget.document.indexAt(widget.position - widget.offset);
  @override
  void initState() {
    super.initState();
    _languages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(covariant LyricsView old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document) _languages();
    if (old.document != widget.document ||
        old.currentLine != widget.currentLine ||
        old.position != widget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  void _follow() {
    if (!mounted || !_following || !_scroll.hasClients || _current < 0) return;
    final p =
        (_current * _height -
                _scroll.position.viewportDimension / 2 +
                _height / 2)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(p);
    } else {
      unawaited(
        _scroll.animateTo(
          p,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _manual() {
    _resume?.cancel();
    if (_following) setState(() => _following = false);
    _resume = Timer(const Duration(seconds: 5), _return);
  }

  void _return() {
    if (!mounted) return;
    _resume?.cancel();
    setState(() => _following = true);
    _follow();
  }

  @override
  void dispose() {
    _resume?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Widget _line(LyricLine line, bool active, Duration pos) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: widget.fontSize,
      color: widget.immersive
          ? (active ? Colors.white : Colors.white.withValues(alpha: .48))
          : active
          ? cs.onPrimaryContainer
          : cs.onSurfaceVariant,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
    );
    final original = line.words.isEmpty
        ? Text(
            line.original,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: style,
          )
        : Text.rich(
            TextSpan(
              children: [
                for (final w in line.words)
                  TextSpan(
                    text: w.text,
                    style: style.copyWith(
                      color: active && pos >= w.time
                          ? (widget.immersive
                                ? const Color(0xFFFF916D)
                                : cs.primary)
                          : style.color,
                    ),
                  ),
              ],
            ),
            textAlign: widget.textAlign,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        original,
        if (widget.showTranslation && line.translation?.isNotEmpty == true)
          Text(
            line.translation!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: style.copyWith(
              fontSize: widget.fontSize * .8,
              fontWeight: FontWeight.normal,
            ),
          ),
        if (widget.showRomanization && line.romanization?.isNotEmpty == true)
          Text(
            line.romanization!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: style.copyWith(
              fontSize: widget.fontSize * .7,
              fontWeight: FontWeight.normal,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.document.lines.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词，可导入 LRC、VTT、SRT 或纯文本歌词',
          textAlign: TextAlign.center,
          style: widget.immersive
              ? const TextStyle(color: Colors.white70)
              : null,
        ),
      );
    }
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.direction != ScrollDirection.idle) _manual();
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            itemExtent: _height,
            itemCount: widget.document.lines.length,
            itemBuilder: (context, index) {
              final line = widget.document.lines[index],
                  active = index == _current;
              final content =
                  active &&
                      line.words.isNotEmpty &&
                      widget.positionListenable != null
                  ? ValueListenableBuilder<Duration>(
                      valueListenable: widget.positionListenable!,
                      builder: (c, p, _) =>
                          _line(line, true, p - widget.offset),
                    )
                  : _line(line, active, widget.position - widget.offset);
              return Semantics(
                selected: active,
                button: line.time != null,
                child: InkWell(
                  key: ValueKey('lyric-$index'),
                  onTap: line.time == null
                      ? null
                      : () => widget.onSeek(line.time! + widget.offset),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: active && !widget.immersive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: content,
                  ),
                ),
              );
            },
          ),
        ),
        if (!_following)
          Positioned(
            bottom: 8,
            right: 12,
            child: FilledButton.tonal(
              onPressed: _return,
              child: const Text('回到当前歌词'),
            ),
          ),
      ],
    );
  }
}
