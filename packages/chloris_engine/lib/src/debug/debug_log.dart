import '../net/engine_limits.dart';

class DebugEvent {
  DebugEvent({
    required this.time,
    required this.tag,
    required this.message,
    this.state = 0,
    this.phase,
  });

  final DateTime time;
  final String tag;
  final String message;

  /// 0 info, 1 success, -1 error.
  final int state;
  final String? phase;

  String get stamp {
    final t = time;
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }
}

typedef DebugSink = void Function(String tag, String message, {int state});

class DebugLog {
  DebugLog._();

  static DebugSink? sink;
  static const int cap = 400;
  static final List<DebugEvent> buffer = [];

  static void log(
    String tag,
    String message, {
    int state = 0,
    String? phase,
  }) {
    if (state >= 0 && !EngineLimits.debugVerbose) return;
    final event = DebugEvent(
      time: DateTime.now(),
      tag: tag,
      message: message,
      state: state,
      phase: phase,
    );
    buffer.add(event);
    final overflow = buffer.length - cap;
    if (overflow > 0) {
      buffer.removeRange(0, overflow);
    }
    sink?.call(tag, message, state: state);
  }

  static void error(String tag, String message, [Object? err]) {
    final detail = err == null ? message : '$message: $err';
    log(tag, detail, state: -1);
  }

  static void clear() => buffer.clear();

  static void restore(Iterable<DebugEvent> events) {
    buffer
      ..clear()
      ..addAll(events);
    final overflow = buffer.length - cap;
    if (overflow > 0) buffer.removeRange(0, overflow);
  }

  static List<DebugEvent> forTag(String tag) {
    return [for (final e in buffer) if (e.tag == tag) e];
  }
}
