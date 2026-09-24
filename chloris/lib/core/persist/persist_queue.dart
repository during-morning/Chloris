import 'dart:async';

/// Coalesce best-effort Drift/vault writes so shelf/progress/source toggles
/// do not each open SQLite on the UI path.
class PersistQueue {
  PersistQueue._();
  static final instance = PersistQueue._();

  final _jobs = <String, Future<void> Function()>{};
  Timer? _timer;

  void schedule(String key, Future<void> Function() job) {
    _jobs[key] = job;
    _timer ??= Timer(const Duration(milliseconds: 240), flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_jobs.isEmpty) return;
    final jobs = List<Future<void> Function()>.from(_jobs.values);
    _jobs.clear();
    for (final job in jobs) {
      try {
        await job();
      } catch (_) {}
    }
  }
}
