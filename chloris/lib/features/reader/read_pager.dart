import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'page_curl_layout.dart';

enum ReadPagerStyle { slide, cover, simulation, none }

/// legado-E style pager: only prev/cur/next, drag clamped to one screen,
/// release snaps to adjacent page or back. Never skips pages.
/// Pointer-driven so mouse, trackpad and touch all follow the finger.
class ReadPager extends StatefulWidget {
  const ReadPager({
    super.key,
    required this.pages,
    required this.index,
    required this.onIndex,
    required this.pageBuilder,
    this.onPrevChapter,
    this.onNextChapter,
    this.onTap,
    this.background,
    this.controller,
    this.style = ReadPagerStyle.slide,
    this.placeholder,
    this.contentKey,
  });

  final List<String> pages;
  final int index;
  final ValueChanged<int> onIndex;
  final Widget Function(BuildContext context, String text, int index)
  pageBuilder;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;
  final void Function(Offset local, Size size)? onTap;
  final Color? background;
  final ReadPagerController? controller;
  final ReadPagerStyle style;
  final Widget? placeholder;

  /// Changes when the page set belongs to another chapter or layout.
  ///
  /// The list is rebuilt by the parent on every frame, so list identity cannot
  /// be used here. Resetting the drag state on this key prevents a completed
  /// chapter transition from leaving the next chapter translated off-screen.
  final Object? contentKey;

  @override
  State<ReadPager> createState() => _ReadPagerState();
}

class ReadPagerController {
  _ReadPagerState? _state;
  void next() => _state?.turn(1);
  void prev() => _state?.turn(-1);
}

class _ReadPagerState extends State<ReadPager>
    with SingleTickerProviderStateMixin {
  final _dxn = ValueNotifier<double>(0);
  double get _dx => _dxn.value;
  set _dx(double v) => _dxn.value = v;
  late final AnimationController _anim;
  Animation<double>? _slide;
  bool _busy = false;
  int _pendingChapter = 0;
  int? _pointer;
  Offset? _down;
  bool _dragging = false;
  double _lastDx = 0;
  int _lastMs = 0;
  double _wheel = 0;
  int? _panPointer;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _anim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          final v = _slide?.value;
          if (v != null) _dx = v;
        });
  }

  @override
  void didUpdateWidget(ReadPager old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
    if (old.index != widget.index ||
        old.pages.length != widget.pages.length ||
        old.contentKey != widget.contentKey ||
        _currentPageText(old) != _currentPageText(widget)) {
      _interrupt();
      _dx = 0;
      _pendingChapter = 0;
    }
  }

  String? _currentPageText(ReadPager value) {
    if (value.pages.isEmpty) return null;
    final i = value.index.clamp(0, value.pages.length - 1);
    return value.pages[i];
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _anim.dispose();
    _dxn.dispose();
    super.dispose();
  }

  bool get _hasPrev => widget.index > 0 || widget.onPrevChapter != null;
  bool get _hasNext =>
      widget.index < widget.pages.length - 1 || widget.onNextChapter != null;

  void turn(int dir) {
    if (_busy) return;
    final box = context.findRenderObject() as RenderBox?;
    final w = box?.size.width ?? 0;
    if (w <= 0) return;
    _commit(dir, w);
  }

  void _interrupt() {
    if (_anim.isAnimating) {
      _anim.stop();
      _busy = false;
      _pendingChapter = 0;
    }
  }

  void _onDown(PointerDownEvent e) {
    _interrupt();
    _pointer = e.pointer;
    _down = e.localPosition;
    _dragging = false;
    _lastDx = e.localPosition.dx;
    _lastMs = e.timeStamp.inMilliseconds;
  }

  void _onMove(PointerMoveEvent e, double w) {
    if (_pointer != e.pointer || _down == null) return;
    _interrupt();
    final delta = e.localPosition.dx - _down!.dx;
    if (!_dragging && (e.localPosition - _down!).distance > 6) {
      _dragging = true;
    }
    if (!_dragging) return;
    var next = delta;
    if (next > 0 && !_hasPrev) next = 0;
    if (next < 0 && !_hasNext) next = 0;
    _lastDx = e.localPosition.dx;
    _lastMs = e.timeStamp.inMilliseconds;
    // _dx is a ValueNotifier consumed by the animation stack. Avoid a full
    // widget rebuild for every pointer event; rebuilding the Text widgets on
    // each touch move was the primary source of reader jank.
    _dx = next.clamp(-w, w);
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    _interrupt();
    _wheel = 0;
    _panPointer = e.pointer;
    _down = e.localPosition;
    _dragging = true;
    _lastDx = e.localPosition.dx;
    _lastMs = e.timeStamp.inMilliseconds;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e, double w) {
    if (_panPointer != e.pointer) return;
    _interrupt();
    var next = e.localPan.dx;
    if (next > 0 && !_hasPrev) next = 0;
    if (next < 0 && !_hasNext) next = 0;
    _dx = next.clamp(-w, w);
    _lastDx = e.localPosition.dx;
    _lastMs = e.timeStamp.inMilliseconds;
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent e, double w) {
    if (_panPointer != e.pointer) return;
    _panPointer = null;
    final dir = _dx <= -w * 0.08 ? 1 : (_dx >= w * 0.08 ? -1 : 0);
    _dragging = false;
    _down = null;
    _commit(dir, w);
  }

  void _onUp(PointerUpEvent e, double w) {
    if (_pointer != e.pointer) return;
    _pointer = null;
    if (!_dragging) {
      widget.onTap?.call(e.localPosition, _viewport == Size.zero ? Size(w, 1) : _viewport);
      _down = null;
      return;
    }
    final dt = (e.timeStamp.inMilliseconds - _lastMs).clamp(1, 80);
    final vx = (e.localPosition.dx - _lastDx) / dt * 1000;
    var dir = 0;
    if (_dx <= -w * 0.08 || vx < -240) dir = 1;
    if (_dx >= w * 0.08 || vx > 240) dir = -1;
    _down = null;
    _dragging = false;
    _commit(dir, w);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _busy || _panPointer != null) return;
    final dx = e.scrollDelta.dx;
    final dy = e.scrollDelta.dy;
    final delta = dx.abs() > dy.abs() ? dx : dy;
    _wheel += delta;
    if (_wheel > 72) {
      _wheel = 0;
      turn(1);
    } else if (_wheel < -72) {
      _wheel = 0;
      turn(-1);
    }
  }

  void _onCancel(PointerCancelEvent e, double w) {
    if (_pointer != e.pointer) return;
    _pointer = null;
    _down = null;
    _dragging = false;
    _animateTo(0, () {});
  }

  void _commit(int dir, double w) {
    if (dir == 1 && widget.index >= widget.pages.length - 1) {
      if (widget.onNextChapter != null) {
        _pendingChapter = 1;
        _animateTo(-w, () => widget.onNextChapter!.call());
        return;
      }
      dir = 0;
    }
    if (dir == -1 && widget.index <= 0) {
      if (widget.onPrevChapter != null) {
        _pendingChapter = -1;
        _animateTo(w, () => widget.onPrevChapter!.call());
        return;
      }
      dir = 0;
    }
    if (dir == 0) {
      _animateTo(0, () {});
      return;
    }
    final target = dir == 1 ? -w : w;
    final nextIndex = widget.index + dir;
    _animateTo(target, () {
      widget.onIndex(nextIndex);
      if (mounted) _dx = 0;
    });
  }

  void _animateTo(double target, VoidCallback done) {
    if (widget.style == ReadPagerStyle.none) {
      _dx = 0;
      _busy = false;
      done();
      return;
    }
    _busy = true;
    _slide = Tween<double>(
      begin: _dx,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0).whenComplete(() {
      _busy = false;
      done();
    });
  }

  Widget _page(
    BuildContext context,
    String? text,
    int index, {
    required bool placeholder,
  }) {
    return ColoredBox(
      color: widget.background ?? Theme.of(context).colorScheme.surface,
      child: placeholder
          ? (widget.placeholder ??
                const Center(child: CircularProgressIndicator()))
          : widget.pageBuilder(context, text ?? '', index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        _viewport = Size(w, h);
        final i = widget.index.clamp(
          0,
          widget.pages.isEmpty ? 0 : widget.pages.length - 1,
        );
        final cur = widget.pages.isEmpty ? '' : widget.pages[i];
        final prev = i > 0 ? widget.pages[i - 1] : null;
        final next = i + 1 < widget.pages.length ? widget.pages[i + 1] : null;
        final cover = widget.style == ReadPagerStyle.cover;
        final showPrevPh = prev == null && _pendingChapter < 0;
        final showNextPh = next == null && _pendingChapter > 0;

        Widget layer(double left, Widget child) =>
            Positioned(left: left, top: 0, width: w, height: h, child: child);

        final curPage = _page(context, cur, i, placeholder: false);
        final prevPage = (prev != null || showPrevPh)
            ? _page(context, prev, i - 1, placeholder: showPrevPh)
            : null;
        final nextPage = (next != null || showNextPh)
            ? _page(context, next, i + 1, placeholder: showNextPh)
            : null;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: (e) => _onMove(e, w),
          onPointerUp: (e) => _onUp(e, w),
          onPointerCancel: (e) => _onCancel(e, w),
          onPointerSignal: _onSignal,
          onPointerPanZoomStart: _onPanZoomStart,
          onPointerPanZoomUpdate: (e) => _onPanZoomUpdate(e, w),
          onPointerPanZoomEnd: (e) => _onPanZoomEnd(e, w),
          child: ClipRect(
            child: ValueListenableBuilder<double>(
              valueListenable: _dxn,
              builder: (context, dx, _) {
                if (widget.style == ReadPagerStyle.simulation) {
                  return _buildSimulation(
                    context,
                    width: w,
                    height: h,
                    dx: dx,
                    cur: curPage,
                    prev: prevPage,
                    next: nextPage,
                    i: i,
                  );
                }
                return Stack(
                  children: [
                    if (cover) ...[
                      if (dx < 0 && nextPage != null) layer(0, nextPage),
                      if (dx >= 0) layer(0, RepaintBoundary(child: curPage)),
                      if (dx < 0) layer(dx, RepaintBoundary(child: curPage)),
                      if (dx > 0 && prevPage != null) layer(dx - w, prevPage),
                    ] else ...[
                      if (prevPage != null) layer(-w + dx, prevPage),
                      layer(dx, RepaintBoundary(child: curPage)),
                      if (nextPage != null) layer(w + dx, nextPage),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 仿真翻页：前翻当前页卷起露出下一页，后翻上一页从左铺回。
  /// 几何由 [curlForward]/[curlBackward] 给出，纸背用渐变模拟。
  Widget _buildSimulation(
    BuildContext context, {
    required double width,
    required double height,
    required double dx,
    required Widget cur,
    Widget? prev,
    Widget? next,
    required int i,
  }) {
    final base = widget.background ?? Theme.of(context).colorScheme.surface;
    Widget full(Widget child) => RepaintBoundary(child: child);
    Widget layer(double left, Widget child) => Positioned(
          left: left,
          top: 0,
          width: width,
          height: height,
          child: child,
        );

    Widget clipped(Widget child, double visibleWidth) {
      if (visibleWidth >= width - 0.5) return full(child);
      return SizedBox(
        width: visibleWidth,
        height: height,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: width,
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );
    }

    List<Widget> flapAndShadow(CurlGeometry g, {required bool forward}) {
      final fold = g.visibleLeft + g.visibleWidth;
      return [
          // 下层页面折缝附近的软阴影
          if (g.hasShadow)
            Positioned(
              left: g.shadowLeft,
              top: 0,
              width: g.shadowWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          // 纸背：卷起部分的背面，靠折缝处最亮（受光），外缘渐暗
          if (g.hasFlap)
            Positioned(
              left: g.flapLeft,
              top: 0,
              width: g.flapWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: base,
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: forward ? 0.10 : 0.28),
                      Colors.black.withValues(alpha: forward ? 0.30 : 0.10),
                    ],
                    stops: const [0.0, 0.12, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          if (g.hasVisible)
            Positioned(
              left: fold - 1.5,
              top: 0,
              width: 1.5,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
    ];
  }

    if (dx < 0 && next != null) {
      final g = curlForward((-dx / width).clamp(0.0, 1.0), width);
      return Stack(
        children: [
          layer(0, full(next)),
          if (g.hasVisible) layer(0, clipped(cur, g.visibleWidth)),
          ...flapAndShadow(g, forward: true),
        ],
      );
    }
    if (dx > 0 && prev != null) {
      final g = curlBackward((dx / width).clamp(0.0, 1.0), width);
      return Stack(
        children: [
          layer(0, full(cur)),
          if (g.hasVisible) layer(0, clipped(prev, g.visibleWidth)),
          ...flapAndShadow(g, forward: false),
        ],
      );
    }
    return Stack(children: [layer(0, full(cur))]);
  }
}
