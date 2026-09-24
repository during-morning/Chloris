import 'dart:async';

/// Bounded parallel chapter fetch. Pure Dart so the app and tests share it.
class ChapterFetchSnapshot {
  const ChapterFetchSnapshot({
    required this.total,
    required this.done,
    required this.failed,
    required this.running,
    this.title,
  });

  final int total;
  final int done;
  final int failed;
  final int running;
  final String? title;

  int get finished => done + failed;

  double get ratio {
    if (total <= 0) return 1;
    return (finished / total).clamp(0, 1);
  }
}

class ParallelChapterFetch {
  ParallelChapterFetch._();

  static Future<ChapterFetchSnapshot> run({
    required List<({int index, String title})> chapters,
    required Future<bool> Function(int index) isDone,
    required Future<bool> Function(int index) fetch,
    required int pool,
    required bool Function() isCancelled,
    void Function(ChapterFetchSnapshot snap)? onProgress,
    int retries = 1,
  }) async {
    final workers = pool.clamp(1, 32);
    final pending = <({int index, String title})>[];
    var done = 0;
    var failed = 0;
    var running = 0;
    String? title;

    void emit() {
      onProgress?.call(
        ChapterFetchSnapshot(
          total: chapters.length,
          done: done,
          failed: failed,
          running: running,
          title: title,
        ),
      );
    }

    for (final ch in chapters) {
      if (isCancelled()) break;
      if (await isDone(ch.index)) {
        done++;
      } else {
        pending.add(ch);
      }
    }
    emit();

    Future<void> drain(List<({int index, String title})> queue) async {
      var cursor = 0;
      var active = 0;
      final doneGate = Completer<void>();

      void kick() {
        if (isCancelled()) {
          if (active == 0 && !doneGate.isCompleted) doneGate.complete();
          return;
        }
        while (active < workers && cursor < queue.length) {
          final ch = queue[cursor++];
          active++;
          running++;
          title = ch.title;
          emit();
          () async {
            var ok = false;
            try {
              ok = await fetch(ch.index);
            } catch (_) {
              ok = false;
            }
            running--;
            active--;
            if (ok) {
              done++;
            } else {
              failed++;
            }
            title = ch.title;
            emit();
            kick();
            if (active == 0 && cursor >= queue.length && !doneGate.isCompleted) {
              doneGate.complete();
            }
          }();
        }
        if (queue.isEmpty && active == 0 && !doneGate.isCompleted) {
          doneGate.complete();
        }
      }

      kick();
      await doneGate.future;
    }

    if (!isCancelled() && pending.isNotEmpty) {
      await drain(pending);
    }

    if (!isCancelled() && retries > 0 && failed > 0) {
      final again = <({int index, String title})>[];
      for (final ch in pending) {
        if (isCancelled()) break;
        if (await isDone(ch.index)) continue;
        again.add(ch);
      }
      if (again.isNotEmpty) {
        failed = (failed - again.length).clamp(0, failed);
        await drain(again);
      }
    }

    emit();
    return ChapterFetchSnapshot(
      total: chapters.length,
      done: done,
      failed: failed,
      running: running,
      title: title,
    );
  }
}
