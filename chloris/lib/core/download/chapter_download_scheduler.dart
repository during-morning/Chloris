import 'dart:async';
import 'package:chloris_engine/chloris_engine.dart';

class ChapterDownloadCancelled implements Exception {
  const ChapterDownloadCancelled();
}

/// Shared by book caching and exports: the limit applies across all jobs.
class ChapterDownloadScheduler {
  ChapterDownloadScheduler({
    int Function()? concurrency,
    int Function()? hostConcurrency,
  }) : _concurrency = concurrency ?? (() => EngineLimits.downloadPool),
       _hostConcurrency =
           hostConcurrency ?? (() => EngineLimits.downloadHostCap);
  static final instance = ChapterDownloadScheduler();
  final int Function() _concurrency, _hostConcurrency;
  final _pending = <_Work>[];
  final _hosts = <String, int>{};
  int _active = 0;
  Future<T> run<T>({
    required String host,
    required Future<T> Function() action,
    bool Function()? cancelled,
  }) {
    final completer = Completer<T>();
    _pending.add(
      _Work(
        host,
        cancelled ?? (() => false),
        () =>
            action().then(completer.complete, onError: completer.completeError),
        () => completer.completeError(const ChapterDownloadCancelled()),
      ),
    );
    _pump();
    return completer.future;
  }

  void cancelPending() => _pump();
  void _pump() {
    for (final work in List<_Work>.of(_pending)) {
      if (work.cancelled()) {
        _pending.remove(work);
        work.cancel();
      }
    }
    while (_active < _concurrency().clamp(1, 16)) {
      final cap = _hostConcurrency();
      final index = _pending.indexWhere(
        (w) => w.host.isEmpty || cap <= 0 || (_hosts[w.host] ?? 0) < cap,
      );
      if (index < 0) return;
      final work = _pending.removeAt(index);
      _active++;
      _hosts[work.host] = (_hosts[work.host] ?? 0) + 1;
      unawaited(
        Future<void>.sync(work.run).whenComplete(() {
          _active--;
          final count = (_hosts[work.host] ?? 1) - 1;
          if (count <= 0) {
            _hosts.remove(work.host);
          } else {
            _hosts[work.host] = count;
          }
          _pump();
        }),
      );
    }
  }
}

class _Work {
  _Work(this.host, this.cancelled, this.run, this.cancel);
  final String host;
  final bool Function() cancelled;
  final Future<void> Function() run;
  final void Function() cancel;
}
