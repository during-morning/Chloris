import 'dart:convert';
import 'dart:io';
import 'package:chloris/data/database/app_database.dart';
import 'package:chloris/features/media/music_repository.dart';
import 'package:chloris/features/media/music_controller.dart';
import 'package:chloris/features/media/audio_types.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('一万首曲目只查询首屏元数据并使用排序索引', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = MusicRepository(database: db);
    addTearDown(() async {
      repository.dispose();
      await db.close();
    });
    await repository.database;
    await db.transaction(() async {
      for (var i = 0; i < 10000; i++) {
        final track = MusicTrack(
          url: '',
          ref: TrackRef(
            id: 'bench-$i',
            origin: TrackOrigin.local,
            localKey: '$i.mp3',
          ),
          title: '歌曲${i.toString().padLeft(5, '0')}',
          artist: '歌手${i % 50}',
          album: '专辑${i % 100}',
        );
        await repository.saveTrack(track, notify: false);
      }
    });
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT payload FROM music_tracks ORDER BY title COLLATE NOCASE,id LIMIT 100',
        )
        .get();
    expect(
      plan.map((r) => r.read<String>('detail')).join(' '),
      contains('music_tracks_title_nocase'),
    );
    final timings = <int>[];
    for (var i = 0; i < 40; i++) {
      final watch = Stopwatch()..start();
      final tracks = await repository.tracks(limit: 100);
      timings.add(watch.elapsedMicroseconds);
      expect(tracks.length, 100);
    }
    timings.sort();
    final report = {
      'scenario': '10000 tracks, first 100 metadata rows',
      'database': 'SQLite in-memory; not a full UI startup measurement',
      'samples': timings.length,
      'p50_ms': timings[timings.length ~/ 2] / 1000,
      'p95_ms': timings[(timings.length * .95).ceil() - 1] / 1000,
      'max_ms': timings.last / 1000,
    };
    final file = File('build/music-evidence/library-query.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    // Record machine measurements without asserting a hardware-dependent target.
    print(jsonEncode(report));
  });
}
