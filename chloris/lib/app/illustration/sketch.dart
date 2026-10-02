import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'svg_art.dart';

/// The Absolutely illustration set — hand-drawn SVGs in
/// `assets/illustrations/`, painted with the live theme palette.
///
/// Every mark is one object in a single ink line, drawn loosely by hand:
/// strokes round off, and a closed shape leaves a small gap where the pen
/// lifts. Empty-state marks are 48×48; navigation glyphs are 24×24.
enum SketchArt {
  library('library', Size(48, 48)),
  search('search', Size(48, 48)),
  music('music', Size(48, 48)),
  offline('offline', Size(48, 48)),
  explore('explore', Size(48, 48)),
  bookStack('book_stack', Size(48, 48)),
  navBook('nav_book', Size(24, 24)),
  navSearch('nav_search', Size(24, 24)),
  navCompass('nav_compass', Size(24, 24)),
  navPerson('nav_person', Size(24, 24));

  const SketchArt(this.file, this.box);

  final String file;

  /// Authored viewBox size; fixes the widget's aspect before the file loads.
  final Size box;

  String get asset => 'assets/illustrations/$file.svg';

  /// Navigation glyphs in [AppIcons.navPairs] order: 书库 / 寻找 / 探索 /
  /// 我的.
  static const nav = [navBook, navSearch, navCompass, navPerson];

  static final _cache = <SketchArt, SvgArt>{};
  static final _pending = <SketchArt, Future<SvgArt>>{};

  /// The parsed artwork if it is already loaded.
  SvgArt? get cached => _cache[this];

  Future<SvgArt> load([AssetBundle? bundle]) {
    final hit = _cache[this];
    if (hit != null) return SynchronousFuture(hit);
    return _pending[this] ??= (bundle ?? rootBundle)
        .loadString(asset)
        .then((src) => _cache[this] = SvgArt.parse(src))
        // A block body: returning the removed Future from the callback would
        // make whenComplete wait on itself.
        .whenComplete(() {
          _pending.remove(this);
        });
  }

  /// Warm the cache so illustrations paint on their first frame.
  static Future<void> preloadAll([AssetBundle? bundle]) =>
      Future.wait([for (final a in values) a.load(bundle)]);
}

/// A hand-drawn illustration that writes itself onto the page once when it
/// first appears: ink lines are drawn in order and each colour fill blooms
/// as the pen reaches it. With animations disabled it is shown complete.
class SketchIllustration extends StatefulWidget {
  const SketchIllustration(
    this.art, {
    super.key,
    this.width,
    this.height,
    this.palette,
    this.animate = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1100),
    this.semanticLabel,
    this.idle = false,
    this.popIn = false,
  }) : assert(width != null || height != null);

  final SketchArt art;
  final double? width;
  final double? height;

  /// Defaults to [ArtPalette.of] the ambient colour scheme.
  final ArtPalette? palette;
  final bool animate;
  final Duration delay;
  final Duration duration;
  final String? semanticLabel;

  /// After it has been drawn, let the illustration breathe: a slow 3px bob,
  /// like paper lifted by a draught. Stops with animations disabled.
  final bool idle;

  /// Grow from 88% while drawing — for glyphs that are selected.
  final bool popIn;

  @override
  State<SketchIllustration> createState() => _SketchIllustrationState();
}

class _SketchIllustrationState extends State<SketchIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  AnimationController? _float;
  SvgArt? _art;
  Timer? _timer;
  bool _wantsRun = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _art = widget.art.cached;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_art == null && !_loading) {
      _loading = true;
      widget.art.load(DefaultAssetBundle.of(context)).then((art) {
        if (!mounted) return;
        setState(() => _art = art);
        if (_wantsRun) _run();
      });
    }
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _controller.value = 1;
      _float
        ?..stop()
        ..value = 0;
      if (!MediaQuery.disableAnimationsOf(context)) _startFloat(rebuild: false);
      return;
    }
    if (_wantsRun) return;
    _wantsRun = true;
    if (_art != null) _run();
  }

  void _startFloat({bool rebuild = true}) {
    if (!widget.idle) return;
    if (_float == null) {
      _float = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3600),
      );
      if (rebuild) setState(() {});
    }
    if (!_float!.isAnimating) _float!.repeat(reverse: true);
  }

  void _run() {
    if (_controller.value > 0 || _timer != null) return;
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _startFloat();
    });
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _float?.dispose();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _paint(context);
    Widget out = body;
    if (widget.popIn) {
      out = ScaleTransition(
        scale: _curve.drive(Tween(begin: .88, end: 1.0)),
        child: out,
      );
    }
    final float = _float;
    if (float != null) {
      out = AnimatedBuilder(
        animation: float,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -3 * Curves.easeInOutSine.transform(float.value)),
          child: child,
        ),
        child: out,
      );
    }
    return out;
  }

  Widget _paint(BuildContext context) {
    final box = widget.art.box;
    final w = widget.width ?? widget.height! * box.width / box.height;
    final h = widget.height ?? widget.width! * box.height / box.width;
    final art = _art;
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: SizedBox(
        width: w,
        height: h,
        child: art == null
            ? null
            : RepaintBoundary(
                child: CustomPaint(
                  painter: SvgArtPainter(
                    art: art,
                    palette:
                        widget.palette ??
                        ArtPalette.of(Theme.of(context).colorScheme),
                    progress: _curve,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A hand-drawn glyph that follows the ambient [IconTheme] for size and
/// colour, so it drops into navigation bars and rails like an [Icon].
/// [animate] writes it in once when it mounts (e.g. a newly selected tab).
class SketchIcon extends StatelessWidget {
  const SketchIcon(
    this.art, {
    super.key,
    this.size,
    this.color,
    this.animate = false,
  });

  final SketchArt art;
  final double? size;
  final Color? color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final s = size ?? icon.size ?? 24;
    return SketchIllustration(
      art,
      width: s,
      height: s,
      animate: animate,
      popIn: animate,
      duration: const Duration(milliseconds: 460),
      palette: ArtPalette.mono(
        color ?? icon.color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Loading mark: the book glyph draws itself, rests, fades, and is drawn
/// again. Shown complete and still with animations disabled.
class SketchLoader extends StatefulWidget {
  const SketchLoader({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  State<SketchLoader> createState() => _SketchLoaderState();
}

class _SketchLoaderState extends State<SketchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _draw = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .55, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _fade = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1), weight: 78),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: AppTokens.curveOut)),
      weight: 22,
    ),
  ]).animate(_controller);
  SvgArt? _art = SketchArt.navBook.cached;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_art == null && !_loading) {
      _loading = true;
      SketchArt.navBook.load(DefaultAssetBundle.of(context)).then((a) {
        if (mounted) setState(() => _art = a);
      });
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = .6; // drawn, before the fade
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    return Semantics(
      label: '加载中',
      child: SizedBox.square(
        dimension: widget.size,
        child: art == null
            ? null
            : RepaintBoundary(
                child: CustomPaint(
                  painter: SvgArtPainter(
                    art: art,
                    palette: ArtPalette.mono(
                      widget.color ?? Theme.of(context).colorScheme.onSurface,
                    ),
                    progress: _draw,
                    fade: _fade,
                  ),
                ),
              ),
      ),
    );
  }
}
