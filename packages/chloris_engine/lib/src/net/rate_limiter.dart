import 'dart:async';

/// Per-source limiter. Use [RateLimiter.shared] so chapter/search/content
/// share the same window — constructing a new instance per request does not
/// enforce `concurrentRate`.
class RateLimiter {
  RateLimiter(this.spec);

  factory RateLimiter.shared(String? key, String? spec) {
    final k = '${key ?? ''}|${spec ?? ''}';
    return _shared.putIfAbsent(k, () => RateLimiter(spec));
  }

  static final Map<String, RateLimiter> _shared = {};

  static void resetShared() => _shared.clear();

  /// `1000` => 1s interval; `20/60000` => 20 calls per 60s.
  final String? spec;

  DateTime? _last;
  final List<DateTime> _window = [];
  int? _intervalMs;
  int? _count;
  int? _windowMs;
  Future<void>? _tail;

  void _parse() {
    if (_intervalMs != null || _count != null || spec == null || spec!.isEmpty) {
      return;
    }
    final s = spec!.trim();
    if (s.contains('/')) {
      final parts = s.split('/');
      _count = int.tryParse(parts[0]) ?? 20;
      _windowMs = int.tryParse(parts[1]) ?? 60000;
    } else {
      _intervalMs = int.tryParse(s) ?? 0;
    }
  }

  Future<void> acquire() {
    _parse();
    // No rate spec: do not serialize HTTP. Interval specs stay a queue.
    if ((_intervalMs == null || _intervalMs == 0) && _count == null) {
      _last = DateTime.now();
      return Future<void>.value();
    }
    if (_count != null && _windowMs != null) {
      return _acquireWindowed();
    }
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return () async {
      if (previous != null) await previous;
      try {
        await _acquireBody();
      } finally {
        gate.complete();
      }
    }();
  }

  Future<void> _acquireWindowed() async {
    while (true) {
      Duration? wait;
      final now = DateTime.now();
      _window.removeWhere(
        (t) => now.difference(t).inMilliseconds > _windowMs!,
      );
      if (_window.length < _count!) {
        _window.add(now);
        return;
      }
      wait = Duration(
        milliseconds: _windowMs! - now.difference(_window.first).inMilliseconds,
      );
      if (wait.inMilliseconds > 0) {
        await Future<void>.delayed(wait);
      }
    }
  }

  Future<void> _acquireBody() async {
    _parse();
    if (_intervalMs != null && _intervalMs! > 0 && _last != null) {
      final wait = _intervalMs! - DateTime.now().difference(_last!).inMilliseconds;
      if (wait > 0) {
        await Future<void>.delayed(Duration(milliseconds: wait));
      }
      _last = DateTime.now();
      return;
    }
    if (_count != null && _windowMs != null) {
      while (true) {
        final now = DateTime.now();
        _window.removeWhere(
          (t) => now.difference(t).inMilliseconds > _windowMs!,
        );
        if (_window.length < _count!) break;
        final wait = _windowMs! - now.difference(_window.first).inMilliseconds;
        if (wait > 0) {
          await Future<void>.delayed(Duration(milliseconds: wait));
        }
      }
      _window.add(DateTime.now());
      return;
    }
    _last = DateTime.now();
  }
}
