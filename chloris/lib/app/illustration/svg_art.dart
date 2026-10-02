import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// A tiny SVG reader for the hand-drawn illustration set in
/// `assets/illustrations/`.
///
/// The artwork is authored as plain SVG (open any file in a browser to see
/// it). Reading it ourselves rather than through an SVG package keeps every
/// shape as a Flutter [Path], so ink lines can be *written on* with
/// [PathMetric.extractPath] while colour fills bloom in underneath.
///
/// Supported: `path`, `circle`, `ellipse`, `rect`, `line`, `polyline`,
/// `polygon`, nested `g`; `fill`, `stroke`, `stroke-width`, `opacity`,
/// `fill-opacity`, `stroke-opacity`; `translate` / `rotate` / `scale`
/// transforms. That is the whole contract the artwork is drawn against.
class SvgArt {
  SvgArt._(this.viewBox, this.shapes);

  final Rect viewBox;
  final List<ArtShape> shapes;

  factory SvgArt.parse(String source) {
    final doc = XmlDocument.parse(source);
    final root = doc.rootElement;
    final vb = (root.getAttribute('viewBox') ?? '0 0 24 24')
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.parse)
        .toList();
    final shapes = <ArtShape>[];
    _walk(root, _Style.root, Matrix4.identity(), shapes);
    return SvgArt._(Rect.fromLTWH(vb[0], vb[1], vb[2], vb[3]), shapes);
  }

  static void _walk(
    XmlElement el,
    _Style inherited,
    Matrix4 parent,
    List<ArtShape> out,
  ) {
    final style = inherited.merge(el);
    final transform = el.getAttribute('transform');
    final matrix = transform == null
        ? parent
        : (parent.clone()..multiply(_parseTransform(transform)));
    for (final child in el.childElements) {
      final name = child.name.local;
      if (name == 'g') {
        _walk(child, style, matrix, out);
        continue;
      }
      var path = _shapePath(child);
      if (path == null) continue;
      final own = style.merge(child);
      final t = child.getAttribute('transform');
      final m = t == null
          ? matrix
          : (matrix.clone()..multiply(_parseTransform(t)));
      path = path.transform(m.storage);
      final shape = own.toShape(path);
      if (shape != null) out.add(shape);
    }
  }

  static Path? _shapePath(XmlElement el) {
    double a(String n) => double.tryParse(el.getAttribute(n) ?? '') ?? 0;
    switch (el.name.local) {
      case 'path':
        return parseSvgPathData(el.getAttribute('d') ?? '');
      case 'circle':
        return Path()..addOval(
          Rect.fromCircle(center: Offset(a('cx'), a('cy')), radius: a('r')),
        );
      case 'ellipse':
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(a('cx'), a('cy')),
            width: a('rx') * 2,
            height: a('ry') * 2,
          ),
        );
      case 'rect':
        final r = Rect.fromLTWH(a('x'), a('y'), a('width'), a('height'));
        final rx = a('rx');
        return rx > 0
            ? (Path()..addRRect(RRect.fromRectXY(r, rx, rx)))
            : (Path()..addRect(r));
      case 'line':
        return Path()
          ..moveTo(a('x1'), a('y1'))
          ..lineTo(a('x2'), a('y2'));
      case 'polyline':
      case 'polygon':
        final n = _numbers(el.getAttribute('points') ?? '');
        final pts = [
          for (var i = 0; i + 1 < n.length; i += 2) Offset(n[i], n[i + 1]),
        ];
        return Path()..addPolygon(pts, el.name.local == 'polygon');
    }
    return null;
  }
}

/// One drawable: an optional fill and an optional ink line on the same path.
class ArtShape {
  ArtShape({
    required this.path,
    this.fill,
    this.fillOpacity = 1,
    this.stroke,
    this.strokeOpacity = 1,
    this.strokeWidth = 1,
  }) : metrics = stroke == null
           ? const []
           : path.computeMetrics().toList(growable: false) {
    length = metrics.fold(0.0, (s, m) => s + m.length);
  }

  final Path path;
  final Color? fill;
  final double fillOpacity;
  final Color? stroke;
  final double strokeOpacity;
  final double strokeWidth;
  final List<PathMetric> metrics;
  late final double length;
}

class _Style {
  const _Style({
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.opacity = 1,
    this.fillOpacity = 1,
    this.strokeOpacity = 1,
  });

  static const root = _Style(fill: Color(0xFF000000));

  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final double opacity;
  final double fillOpacity;
  final double strokeOpacity;

  _Style merge(XmlElement el) {
    double? n(String a) => double.tryParse(el.getAttribute(a) ?? '');
    final f = el.getAttribute('fill');
    final s = el.getAttribute('stroke');
    return _Style(
      fill: f == null ? fill : _color(f),
      stroke: s == null ? stroke : _color(s),
      strokeWidth: n('stroke-width') ?? strokeWidth,
      opacity: opacity * (n('opacity') ?? 1),
      fillOpacity: n('fill-opacity') ?? fillOpacity,
      strokeOpacity: n('stroke-opacity') ?? strokeOpacity,
    );
  }

  ArtShape? toShape(Path path) {
    if (fill == null && stroke == null) return null;
    return ArtShape(
      path: path,
      fill: fill,
      fillOpacity: fillOpacity * opacity,
      stroke: stroke,
      strokeOpacity: strokeOpacity * opacity,
      strokeWidth: strokeWidth,
    );
  }

  static Color? _color(String v) {
    v = v.trim();
    if (v == 'none' || v.isEmpty) return null;
    if (v.startsWith('#')) {
      var hex = v.substring(1);
      if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
      return Color(0xFF000000 | int.parse(hex, radix: 16));
    }
    return const Color(0xFF000000);
  }
}

Matrix4 _parseTransform(String source) {
  final m = Matrix4.identity();
  for (final match in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(source)) {
    final v = _numbers(match.group(2)!);
    switch (match.group(1)) {
      case 'translate':
        m.translateByDouble(v[0], v.length > 1 ? v[1] : 0, 0, 1);
      case 'scale':
        m.scaleByDouble(v[0], v.length > 1 ? v[1] : v[0], 1, 1);
      case 'rotate':
        final a = v[0] * math.pi / 180;
        if (v.length == 3) {
          m
            ..translateByDouble(v[1], v[2], 0, 1)
            ..rotateZ(a)
            ..translateByDouble(-v[1], -v[2], 0, 1);
        } else {
          m.rotateZ(a);
        }
    }
  }
  return m;
}

final _number = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');

List<double> _numbers(String s) =>
    _number.allMatches(s).map((m) => double.parse(m.group(0)!)).toList();

/// SVG path data (`d`) → [Path]. Handles every command, absolute and
/// relative, including smooth curves and elliptical arcs.
Path parseSvgPathData(String d) {
  final path = Path();
  final tokens = RegExp(
    r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
  ).allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  var cur = Offset.zero;
  var start = Offset.zero;
  Offset? lastCtrl; // reflected by S / T
  String prev = '';

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    Offset pt(double x, double y) => rel ? cur + Offset(x, y) : Offset(x, y);
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = pt(next(), next());
        start = cur;
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L'; // implicit lineto after the first pair
        lastCtrl = null;
      case 'L':
        cur = pt(next(), next());
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'H':
        final x = next();
        cur = Offset(rel ? cur.dx + x : x, cur.dy);
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'V':
        final y = next();
        cur = Offset(cur.dx, rel ? cur.dy + y : y);
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'C':
        final c1 = pt(next(), next());
        final c2 = pt(next(), next());
        final e = pt(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
      case 'S':
        final c1 = (lastCtrl != null && 'CS'.contains(prev.toUpperCase()))
            ? cur * 2 - lastCtrl
            : cur;
        final c2 = pt(next(), next());
        final e = pt(next(), next());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
      case 'Q':
        final c = pt(next(), next());
        final e = pt(next(), next());
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
        lastCtrl = c;
        cur = e;
      case 'T':
        final c = (lastCtrl != null && 'QT'.contains(prev.toUpperCase()))
            ? cur * 2 - lastCtrl
            : cur;
        final e = pt(next(), next());
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
        lastCtrl = c;
        cur = e;
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final large = next() != 0;
        final sweep = next() != 0;
        final e = pt(next(), next());
        path.arcToPoint(
          e,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
        lastCtrl = null;
        cur = e;
      case 'Z':
        path.close();
        cur = start;
        lastCtrl = null;
      default:
        i++; // unknown token: skip rather than loop forever
    }
    prev = cmd;
  }
  return path;
}

/// Maps the artwork's authored colours onto the live theme.
///
/// The SVG files are drawn in the light-mode palette below, so they look
/// right in any viewer. At paint time each known colour is swapped for its
/// role in the current scheme; anything else is painted as authored.
class ArtPalette {
  const ArtPalette._(this._map) : mono = null;

  /// Paints every colour in [color], keeping each shape's own opacity —
  /// for navigation glyphs and other single-ink marks.
  const ArtPalette.mono(Color color) : _map = const {}, mono = color;

  final Map<int, Color> _map;
  final Color? mono;

  // Authored palette (light mode).
  static const ink = 0xFF191919;
  static const paper = 0xFFFAF9F5;
  static const clay = 0xFFD97757;
  static const blush = 0xFFF0B9A0;
  static const pollen = 0xFFF2C46D;
  static const sage = 0xFFA9B28A;
  static const olive = 0xFF6F7A4E;
  static const kraft = 0xFFD8C4A8;
  static const bark = 0xFFB89A7A;

  factory ArtPalette.of(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    return ArtPalette._({
      ink: cs.onSurface,
      // Paper stays a step lighter than the page so shapes keep their edge.
      paper: dark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
      clay: cs.primary,
      blush: dark ? const Color(0xFF9A5A45) : const Color(blush),
      pollen: dark ? const Color(0xFFC79A48) : const Color(pollen),
      sage: dark ? const Color(0xFF7D8663) : const Color(sage),
      olive: dark ? const Color(0xFFA3AE7C) : const Color(olive),
      kraft: dark ? const Color(0xFF4A4037) : const Color(kraft),
      bark: dark ? const Color(0xFF6E5A47) : const Color(bark),
    });
  }

  Color resolve(Color authored) =>
      mono ?? _map[authored.toARGB32()] ?? authored;

  @override
  bool operator ==(Object other) =>
      other is ArtPalette && other.mono == mono && _mapEquals(other._map, _map);

  static bool _mapEquals(Map<int, Color> a, Map<int, Color> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(mono, Object.hashAllUnordered(_map.values));
}

/// Paints [art] scaled into the canvas (contain), with ink written on up to
/// [progress] of its total line length. Each fill blooms in just as the pen
/// reaches it, so colour follows the drawing rather than preceding it.
class SvgArtPainter extends CustomPainter {
  SvgArtPainter({
    required this.art,
    required this.palette,
    required this.progress,
    this.fade,
  }) : super(repaint: Listenable.merge([progress, ?fade]));

  final SvgArt art;
  final ArtPalette palette;
  final Animation<double> progress;

  /// Optional whole-drawing opacity (used by the looping loader).
  final Animation<double>? fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final vb = art.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    canvas
      ..save()
      ..translate(
        (size.width - vb.width * scale) / 2,
        (size.height - vb.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-vb.left, -vb.top);

    final total = art.shapes.fold(0.0, (s, e) => s + e.length);
    final p = progress.value.clamp(0.0, 1.0);
    final alpha = (fade?.value ?? 1).clamp(0.0, 1.0);
    final budget = p * total;
    var travelled = 0.0;

    for (final shape in art.shapes) {
      if (shape.fill != null) {
        // Bloom window: starts as the pen arrives (scaled into the first 80%
        // of the run), lasts 30% of it.
        final at = total == 0 ? 0.0 : travelled / total * .8;
        final t = p >= 1 ? 1.0 : ((p - at) / .3).clamp(0.0, 1.0);
        if (t > 0) {
          canvas.drawPath(
            shape.path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = palette
                  .resolve(shape.fill!)
                  .withValues(alpha: shape.fillOpacity * t * alpha),
          );
        }
      }
      if (shape.stroke != null && travelled < budget) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = shape.strokeWidth
          ..color = palette
              .resolve(shape.stroke!)
              .withValues(alpha: shape.strokeOpacity * alpha);
        if (budget >= travelled + shape.length) {
          canvas.drawPath(shape.path, paint);
        } else {
          var left = budget - travelled;
          for (final m in shape.metrics) {
            if (left <= 0) break;
            canvas.drawPath(m.extractPath(0, math.min(left, m.length)), paint);
            left -= m.length;
          }
        }
      }
      travelled += shape.length;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgArtPainter old) =>
      old.art != art ||
      old.palette != palette ||
      old.progress != progress ||
      old.fade != fade;
}
