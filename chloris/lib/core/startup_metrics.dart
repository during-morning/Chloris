import 'dart:developer' as developer;

/// Small DevTools timeline marks for comparing startup on the same machine.
class StartupMetrics {
  StartupMetrics._();

  static final Stopwatch _clock = Stopwatch()..start();
  static final Set<String> _recorded = {};

  static void mark(String name) {
    if (!_recorded.add(name)) return;
    developer.Timeline.instantSync(
      'chloris.startup.$name',
      arguments: {'elapsedMs': _clock.elapsedMilliseconds},
    );
  }
}
