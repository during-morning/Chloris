import 'dart:collection';
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
  static const _maxBytes = 16 * 1024 * 1024;
  static final _cache = LinkedHashMap<String, Uint8List>();
  static final _inFlight = <String, Future<Uint8List>>{};
  static int _cacheBytes = 0;
  static bool _imageCacheBounded = false;
  Future<Uint8List>? _future;

  String get _key {
    final cookie = ref.read(cookieStoreProvider).get(widget.url);
    return '${widget.url}|${widget.source?.bookSourceUrl}|${widget.book?.bookUrl}|${widget.source?.header}|$cookie|$_decodeScript|${widget.isCover}';
  }

  String? get _decodeScript =>
      ImageDecoder.decodeJs(widget.source, isCover: widget.isCover);
  bool get _needsDecode => _decodeScript != null;

  @override
  void initState() {
    super.initState();
    if (!_imageCacheBounded) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
      _imageCacheBounded = true;
    }
    if (_needsDecode) _future = _load();
  }

  @override
  void didUpdateWidget(covariant DecodedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCookie = ref.read(cookieStoreProvider).get(oldWidget.url);
    final cookie = ref.read(cookieStoreProvider).get(widget.url);
    final wasDecoding =
        ImageDecoder.decodeJs(oldWidget.source, isCover: oldWidget.isCover) !=
        null;
    final oldScript = ImageDecoder.decodeJs(
      oldWidget.source,
      isCover: oldWidget.isCover,
    );
    if (oldWidget.url != widget.url ||
        oldWidget.source?.bookSourceUrl != widget.source?.bookSourceUrl ||
        oldWidget.source?.header != widget.source?.header ||
        oldWidget.book?.bookUrl != widget.book?.bookUrl ||
        oldCookie != cookie ||
        oldWidget.isCover != widget.isCover ||
        oldScript != _decodeScript ||
        wasDecoding != _needsDecode) {
      _future = _needsDecode ? _load() : null;
    }
  }

  Future<Uint8List> _load() async {
    final hit = _cache[_key];
    if (hit != null) {
      _cache.remove(_key);
      _cache[_key] = hit;
      return hit;
    }
    final shared = _inFlight[_key];
    if (shared != null) return shared;
    final key = _key;
    final future = ref
        .read(engineImageLoaderProvider)
        .load(
          url: widget.url,
          source: widget.source,
          book: widget.book,
          isCover: widget.isCover,
        );
    _inFlight[key] = future;
    try {
      final bytes = await future;
      if (bytes.lengthInBytes <= _maxBytes) {
        _cache[key] = bytes;
        _cacheBytes += bytes.lengthInBytes;
        while (_cacheBytes > _maxBytes && _cache.isNotEmpty) {
          final oldest = _cache.keys.first;
          _cacheBytes -= _cache.remove(oldest)!.lengthInBytes;
        }
      }
      return bytes;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsDecode) {
      return SharpNetworkImage(
        url: widget.url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheScale: widget.cacheScale,
        errorBuilder: widget.errorBuilder,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData) {
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final layoutWidth =
                widget.width != null &&
                    widget.width!.isFinite &&
                    widget.width! > 0
                ? widget.width
                : constraints.maxWidth;
            final cacheWidth = SharpNetworkImage.cacheExtent(
              layoutWidth,
              dpr,
              widget.cacheScale,
            );
            final cacheHeight = cacheWidth == null
                ? SharpNetworkImage.cacheExtent(
                    widget.height ??
                        (constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : null),
                    dpr,
                    widget.cacheScale,
                  )
                : null;
            return Image.memory(
              snap.data!,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
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
      ),
    );
  }
}
