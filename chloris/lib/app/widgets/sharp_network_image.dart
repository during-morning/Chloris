import 'package:flutter/material.dart';

/// Network image that decodes at device pixels so CanvasKit does not
/// upscale a 1× bitmap (the usual “everything looks soft on web” cause).
class SharpNetworkImage extends StatelessWidget {
  const SharpNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.cacheScale = 1,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Extra decode resolution, e.g. 2 when the image can be pinch-zoomed.
  final double cacheScale;

  static int? cacheExtent(double? logical, double dpr, double scale) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    final px = (logical * dpr * scale).round();
    if (px < 1) return 1;
    if (px > 4096) return 4096;
    return px;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final specified = width != null && width!.isFinite && width! > 0;
    if (specified) {
      return _image(dpr, width, height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        final h = height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : null);
        return _image(dpr, w, h);
      },
    );
  }

  Widget _image(double dpr, double? w, double? h) {
    // One axis only — keeps the codec's aspect ratio.
    final cacheW = cacheExtent(w, dpr, cacheScale);
    final cacheH = cacheW == null ? cacheExtent(h, dpr, cacheScale) : null;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: errorBuilder,
    );
  }
}
