import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'sharp_network_image.dart';

/// Loads a remote image and optionally runs legado cover/content decode JS.
class DecodedNetworkImage extends ConsumerStatefulWidget {
  const DecodedNetworkImage({
    super.key,
    required this.url,
    this.source,
    this.book,
    this.isCover = true,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheScale = 1,
    this.errorBuilder,
  });

  final String url;
  final BookSource? source;
  final Book? book;
  final bool isCover;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double cacheScale;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  ConsumerState<DecodedNetworkImage> createState() =>
      _DecodedNetworkImageState();
}

class _DecodedNetworkImageState extends ConsumerState<DecodedNetworkImage> {
  static final _cache = <String, Uint8List>{};
  Future<Uint8List>? _future;

  String get _key =>
      '${widget.url}|${widget.source?.bookSourceUrl}|${widget.isCover}';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DecodedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.source?.bookSourceUrl != widget.source?.bookSourceUrl ||
        oldWidget.isCover != widget.isCover) {
      _future = _load();
    }
  }

  Future<Uint8List> _load() async {
    final hit = _cache[_key];
    if (hit != null) return hit;
    final bytes = await ref
        .read(engineImageLoaderProvider)
        .load(
          url: widget.url,
          source: widget.source,
          book: widget.book,
          isCover: widget.isCover,
        );
    if (_cache.length > 128) _cache.remove(_cache.keys.first);
    _cache[_key] = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final js = ImageDecoder.decodeJs(widget.source, isCover: widget.isCover);
    if (js == null) {
      return SharpNetworkImage(
        url: widget.url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheScale: widget.cacheScale,
        errorBuilder: widget.errorBuilder,
      );
    }
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: widget.errorBuilder,
          );
        }
        if (snap.hasError) {
          return widget.errorBuilder?.call(
                context,
                snap.error!,
                snap.stackTrace,
              ) ??
              const SizedBox.shrink();
        }
        return SizedBox(width: widget.width, height: widget.height);
      },
    );
  }
}
