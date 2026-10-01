import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:chloris/data/database/app_database.dart';
import 'package:chloris/features/media/audio_types.dart';
import 'package:chloris/features/media/audio_resolver.dart';
import 'package:chloris/features/media/audio_metadata.dart';
import 'package:chloris/features/media/audio_file_store_io.dart';
import 'package:chloris/features/media/audio_download_manager.dart';
import 'package:chloris/features/media/lyrics.dart';
import 'package:chloris/features/media/music_controller.dart';
import 'package:chloris/features/media/music_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> until(bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 10)) throw StateError('等待任务超时');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('章节字符串数组保留分段，通用数组和曲目列表要求选择', () {
    const input = '["https://example.com/1.mp3","https://example.com/2.mp3"]';
    expect(parseAudio(input, chapter: true).variants.single.segments.length, 2);
    expect(() => parseAudio(input), throwsA(isA<AudioSelectionRequired>()));
    expect(
      () => parseAudio(
        '{"data":{"tracks":[{"url":"https://example.com/1.mp3"}]}}',
      ),
      throwsA(isA<AudioSelectionRequired>()),
    );
    expect(() => parseAudio('[]', chapter: true), throwsFormatException);
  });
  test('音质、POST、相对分段、请求头与选择元数据完整往返', () {
    final audio = parseAudio(
      '{"headers":{"Referer":"https://example.com"},"variants":[{"label":"高音质","segments":[{"url":"../play","method":"POST","body":"token=fixture","durationMs":1500}]}]}',
      baseUrl: 'https://example.com/a/b',
    );
    final segment = audio.variants.single.segments.single;
    expect(segment.request.url, 'https://example.com/play');
    expect(segment.request.method, 'POST');
    expect(segment.request.body, 'token=fixture');
    expect(segment.request.headers['Referer'], 'https://example.com');
    expect(segment.duration, const Duration(milliseconds: 1500));
    final direct = parseAudio(
      '{"url":"https://example.com/play","method":"POST","body":"id=1"}',
    );
    expect(direct.variants.first.segments.first.request.method, 'POST');
    const ref = TrackRef(
      id: 'stable',
      address: 'input',
      variant: 2,
      continuous: true,
    );
    final copy = TrackRef.fromJson(ref.toJson());
    expect(copy.variant, 2);
    expect(copy.continuous, true);
  });
  test('逐字双语、字幕结束、偏移、未匹配内容和 GB18030', () {
    final enhanced = LyricDocument.parse(
      '[offset:100]\n[00:01]<00:01>你<00:01.500>好\n[00:01]Hello\n未匹配的说明',
    );
    expect(enhanced.lines.first.words.length, 2);
    expect(
      enhanced.lines.first.words.last.time,
      const Duration(milliseconds: 1600),
    );
    expect(enhanced.lines.first.translation, 'Hello');
    expect(enhanced.lines.last.text, '未匹配的说明');
    expect(enhanced.indexAt(const Duration(seconds: 2)), 0);
    final vtt = LyricDocument.parse(
      'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n第一行\n第二行',
    );
    expect(vtt.lines.single.original, '第一行\n第二行');
    expect(vtt.indexAt(const Duration(seconds: 3)), -1);
    expect(
      decodeLyricBytes(Uint8List.fromList([0xc4, 0xe3, 0xba, 0xc3])),
      '你好',
    );
    expect(
      decodeLyricBytes(Uint8List.fromList([0x94, 0x39, 0xfc, 0x36])),
      '😀',
    );
  });
  test('数据库收藏、歌单去重排序、歌词偏移、历史与删除引用', () async {
    final repo = MusicRepository(database: AppDatabase(NativeDatabase.memory()));
    final database = await repo.database;
    addTearDown(() async {
      repo.dispose();
      await database.close();
    });
    const a = MusicTrack(url: 'https://example.com/a.mp3', title: 'A'),
        b = MusicTrack(url: 'https://example.com/b.mp3', title: 'B');
    final list = await repo.createPlaylist('测试');
    await repo.addToPlaylist(list, [a, a, b]);
    expect((await repo.playlists()).single.count, 2);
    await repo.reorderPlaylist(list, [b.id, a.id]);
    expect((await repo.tracks(playlist: list)).first.id, b.id);
    await repo.toggleFavorite(a);
    expect((await repo.tracks(favorites: true)).single.id, a.id);
    await repo.saveLyrics(a.id, '[00:01]歌词', offset: 500);
    await repo.saveLyrics(a.id, '[00:02]更新');
    expect((await repo.lyrics(a.id))!.offset, 500);
    await repo.saveHistory(
      a,
      const Duration(seconds: 12),
      const Duration(seconds: 90),
    );
    expect(await repo.progress(a.id), const Duration(seconds: 12));
    await repo.remove(a.id);
    expect((await repo.tracks(playlist: list)).length, 1);
    expect(await repo.lyrics(a.id), isNull);
  });
  for (final version in [7, 8]) {
    test('数据库 $version → 9 保留书架并增加音乐表', () async {
      final dir = await Directory.systemTemp.createTemp('chloris-migration-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/books.db');
      var db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        "INSERT INTO books(book_url,name,author) VALUES('fixture','旧书','作者')",
      );
      for (final table in [
        'music_playlist_tracks',
        'music_lyrics',
        'music_history',
        'music_playlists',
        'music_tracks',
        'music_state',
        'music_downloads',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      if (version == 7) {
        await db.customStatement('DROP TABLE blob_entries');
        await db.customStatement('DROP TABLE local_book_descriptors');
        await db.customStatement('DROP INDEX books_identity_key');
        await db.customStatement('DROP INDEX search_books_identity_key');
        await db.customStatement('ALTER TABLE books DROP COLUMN identity_key');
        await db.customStatement(
          'ALTER TABLE search_books DROP COLUMN identity_key',
        );
      }
      await db.customStatement('PRAGMA user_version=$version');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(
        (await db.customSelect('SELECT name FROM books').get()).single
            .read<String>('name'),
        '旧书',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').get()).single.read<int>(
          'user_version',
        ),
        9,
      );
      final repo = MusicRepository(database: db);
      await repo.saveTrack(const MusicTrack(url: 'https://example.com/a.mp3'));
      expect((await repo.tracks()).length, 1);
      repo.dispose();
      await db.close();
    });
  }
  test('大于 8 MiB 原生导入持久化、去重、删除原文件及续传提交', () async {
    final dir = await Directory.systemTemp.createTemp('chloris-audio-');
    addTearDown(() => dir.delete(recursive: true));
    final store = AudioFileStore(directory: Directory('${dir.path}/managed'));
    final source = File('${dir.path}/source.mp3');
    final sink = source.openWrite();
    for (var i = 0; i < 9; i++) {
      sink.add(Uint8List(1024 * 1024)..[0] = i);
    }
    await sink.close();
    final first = await store.importFile(source.path, 'mp3'),
        second = await store.importFile(source.path, 'mp3');
    expect(first.key, second.key);
    expect(first.size, 9 * 1024 * 1024);
    await source.delete();
    expect((await store.open(first.key)).size, first.size);
    await store.write('part.mp3', Stream.value([1, 2]), partial: true);
    await store.write(
      'part.mp3',
      Stream.value([3, 4]),
      partial: true,
      append: true,
    );
    expect(await store.partialSize('part.mp3'), 4);
    await store.commit('part.mp3');
    expect(await store.read('part.mp3'), [1, 2, 3, 4]);
  });
  test('普通文件 Range 续传保留分文件校验信息', () async {
    final dir = await Directory.systemTemp.createTemp('chloris-range-');
    addTearDown(() => dir.delete(recursive: true));
    final store = AudioFileStore(directory: dir);
    final repo = MusicRepository(database: AppDatabase(NativeDatabase.memory()));
    final database = await repo.database;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ranges = <String?>[];
    server.listen((r) async {
      final range = r.headers.value('range');
      ranges.add(range);
      var offset = range == null
          ? 0
          : int.parse(RegExp(r'bytes=(\d+)').firstMatch(range)![1]!);
      r.response.statusCode = range == null ? 200 : 206;
      r.response.headers.set('etag', 'fixture');
      r.response.headers.contentLength = 8 - offset;
      if (range != null)
        r.response.headers.set('content-range', 'bytes $offset-7/8');
      r.response.add(List.generate(8 - offset, (i) => i + offset));
      await r.response.close();
    });
    final track = MusicTrack(url: 'http://127.0.0.1:${server.port}/song.mp3');
    await store.write(
      '${track.id}-0.mp3',
      Stream.value([0, 1, 2]),
      partial: true,
    );
    final manager = AudioDownloadManager(
      repository: repo,
      store: store,
      resolve: (t, o) async => t,
    );
    addTearDown(() async {
      await manager.close();
      repo.dispose();
      await database.close();
      await server.close(force: true);
    });
    await manager.enqueue([track]);
    await until(
      () =>
          manager.tasks.single.status == AudioDownloadStatus.complete ||
          manager.tasks.single.status == AudioDownloadStatus.failed,
    );
    expect(manager.tasks.single.error, isNull);
    expect(ranges.single, 'bytes=3-');
    expect(
      await store.read(manager.tasks.single.files.single),
      List.generate(8, (i) => i),
    );
  });
  test('HLS AES-128 点播保存密钥初始化片段和相对分片，直播明确失败', () async {
    final dir = await Directory.systemTemp.createTemp('chloris-hls-');
    addTearDown(() => dir.delete(recursive: true));
    final store = AudioFileStore(directory: dir),
        repo = MusicRepository(database: AppDatabase(NativeDatabase.memory()));
    final database = await repo.database;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      if (r.uri.path.endsWith('.m3u8')) {
        r.response.write(
          '#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:10,\nsegment.ts\n${r.uri.path.contains('live') ? '' : '#EXT-X-ENDLIST\n'}',
        );
      } else {
        r.response.add(Uint8List(16));
      }
      await r.response.close();
    });
    final manager = AudioDownloadManager(
      repository: repo,
      store: store,
      resolve: (t, o) async => t,
    );
    addTearDown(() async {
      await manager.close();
      repo.dispose();
      await database.close();
      await server.close(force: true);
    });
    await manager.enqueue([
      MusicTrack(url: 'http://127.0.0.1:${server.port}/audio/list.m3u8'),
    ]);
    await until(
      () =>
          manager.tasks.first.status == AudioDownloadStatus.complete ||
          manager.tasks.first.status == AudioDownloadStatus.failed,
    );
    expect(manager.tasks.first.error, isNull);
    final task = manager.tasks.first;
    expect(task.files.length, 4);
    final playlist = utf8.decode(await store.read(task.files.first));
    expect(playlist, contains('${task.track.id}-0-h'));
    expect(playlist, contains('METHOD=AES-128'));
    await manager.enqueue([
      MusicTrack(url: 'http://127.0.0.1:${server.port}/live.m3u8'),
    ]);
    await until(() => manager.tasks.last.status == AudioDownloadStatus.failed);
    expect(manager.tasks.last.error, contains('直播'));
  });
}
