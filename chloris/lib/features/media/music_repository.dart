import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/persist/app_db.dart';
import '../../data/database/app_database.dart';
import 'music_controller.dart';

class MusicPlaylist {
  const MusicPlaylist(this.id, this.name, {this.cover, this.count = 0});
  final String id, name;
  final String? cover;
  final int count;
}

/// Queries metadata only. Audio files are owned by AudioFileStore.
class MusicRepository extends ChangeNotifier {
  MusicRepository({this._database});
  AppDatabase? _database;
  Future<AppDatabase> get database async {
    final db = _database ??= await AppDb.open();
    if (db == null) throw StateError('音乐数据库无法打开，请检查存储权限');
    return db;
  }

  Future<List<QueryRow>> _select(
    String sql, [
    List<Object> args = const [],
  ]) async => (await database)
      .customSelect(sql, variables: [for (final a in args) Variable(a)])
      .get();
  Future<void> _execute(String sql, List<Object?> args) async =>
      (await database).customStatement(sql, args);
  int get _now => DateTime.now().millisecondsSinceEpoch;
  MusicTrack _track(QueryRow r) => MusicTrack.fromJson(
    Map<String, dynamic>.from(jsonDecode(r.read<String>('payload')) as Map),
  );
  void publish() => notifyListeners();
  Future<void> saveTrack(MusicTrack track, {bool notify = true}) async {
    await _execute(
      '''INSERT INTO music_tracks(id,payload,title,artist,album,updated) VALUES(?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,title=excluded.title,artist=excluded.artist,album=excluded.album,updated=excluded.updated''',
      [
        track.id,
        jsonEncode(track.toJson()),
        track.displayTitle,
        track.artist ?? '',
        track.album ?? '',
        _now,
      ],
    );
    if (notify) notifyListeners();
  }

  Future<List<MusicTrack>> tracks({
    String query = '',
    String? playlist,
    bool favorites = false,
    String? artist,
    String? album,
    int limit = 100,
    int offset = 0,
    String sort = 'title',
    bool localOnly = false,
  }) async {
    final filter = <String>[], args = <Object>[];
    if (query.isNotEmpty) {
      filter.add('(t.title LIKE ? OR t.artist LIKE ? OR t.album LIKE ?)');
      args.addAll(List.filled(3, '%$query%'));
    }
    if (favorites) filter.add('t.favorite=1');
    if (localOnly) {
      filter.add(r"json_extract(t.payload,'$.ref.origin')='local'");
    }
    if (artist != null) {
      filter.add('t.artist=?');
      args.add(artist);
    }
    if (album != null) {
      filter.add('t.album=?');
      args.add(album);
    }
    if (playlist != null) {
      filter.add('p.playlist_id=?');
      args.add(playlist);
    }
    final rows = await _select(
      'SELECT t.payload FROM music_tracks t ${playlist == null ? '' : 'JOIN music_playlist_tracks p ON p.track_id=t.id'} '
      '${filter.isEmpty ? '' : 'WHERE ${filter.join(' AND ')}'} ORDER BY ${playlist == null
          ? sort == 'recent'
                ? 't.updated DESC,t.id'
                : sort == 'artist'
                ? 't.artist COLLATE NOCASE,t.title'
                : sort == 'album'
                ? 't.album COLLATE NOCASE,t.title'
                : 't.title COLLATE NOCASE,t.id'
          : 'p.position'} LIMIT ? OFFSET ?',
      [...args, limit.clamp(1, 10000), offset],
    );
    return rows.map(_track).toList(growable: false);
  }

  Future<MusicTrack?> track(String id) async {
    final r = await _select('SELECT payload FROM music_tracks WHERE id=?', [
      id,
    ]);
    return r.isEmpty ? null : _track(r.first);
  }

  Future<List<String>> groups(bool byArtist) async {
    final col = byArtist ? 'artist' : 'album';
    return (await _select(
      'SELECT DISTINCT $col AS name FROM music_tracks WHERE $col<>\'\' ORDER BY $col',
    )).map((r) => r.read<String>('name')).toList();
  }

  Future<bool> favorite(String id) async {
    final r = await _select('SELECT favorite FROM music_tracks WHERE id=?', [
      id,
    ]);
    return r.isNotEmpty && r.first.read<int>('favorite') != 0;
  }

  Future<void> toggleFavorite(MusicTrack track) async {
    await saveTrack(track);
    await _execute('UPDATE music_tracks SET favorite=1-favorite WHERE id=?', [
      track.id,
    ]);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _execute('DELETE FROM music_tracks WHERE id=?', [id]);
    notifyListeners();
  }

  Future<List<MusicPlaylist>> playlists() async =>
      (await _select(
            '''SELECT p.*,COUNT(t.track_id) AS count FROM music_playlists p
    LEFT JOIN music_playlist_tracks t ON t.playlist_id=p.id GROUP BY p.id ORDER BY p.updated DESC''',
          ))
          .map(
            (r) => MusicPlaylist(
              r.read<String>('id'),
              r.read<String>('name'),
              cover: r.readNullable<String>('cover'),
              count: r.read<int>('count'),
            ),
          )
          .toList();
  Future<String> createPlaylist(String name) async {
    if (name.trim().isEmpty) throw const FormatException('请输入歌单名称');
    final id = 'playlist-${DateTime.now().microsecondsSinceEpoch}';
    await _execute(
      'INSERT INTO music_playlists(id,name,updated) VALUES(?,?,?)',
      [id, name.trim(), _now],
    );
    notifyListeners();
    return id;
  }

  Future<void> renamePlaylist(String id, String name, {String? cover}) async {
    if (name.trim().isEmpty) throw const FormatException('请输入歌单名称');
    await _execute(
      'UPDATE music_playlists SET name=?,cover=COALESCE(?,cover),updated=? WHERE id=?',
      [name.trim(), cover, _now, id],
    );
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _execute('DELETE FROM music_playlists WHERE id=?', [id]);
    notifyListeners();
  }

  Future<void> addToPlaylist(String id, List<MusicTrack> tracks) async {
    final db = await database;
    await db.transaction(() async {
      var pos =
          (await _select(
            'SELECT COALESCE(MAX(position),-1) AS n FROM music_playlist_tracks WHERE playlist_id=?',
            [id],
          )).first.read<int>('n') +
          1;
      for (final t in tracks) {
        await saveTrack(t, notify: false);
        await _execute(
          'INSERT OR IGNORE INTO music_playlist_tracks(playlist_id,track_id,position) VALUES(?,?,?)',
          [id, t.id, pos++],
        );
      }
      await _execute('UPDATE music_playlists SET updated=? WHERE id=?', [
        _now,
        id,
      ]);
    });
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String id, String trackId) async {
    await _execute(
      'DELETE FROM music_playlist_tracks WHERE playlist_id=? AND track_id=?',
      [id, trackId],
    );
    notifyListeners();
  }

  Future<void> reorderPlaylist(String id, List<String> ids) async {
    await (await database).transaction(() async {
      for (var i = 0; i < ids.length; i++) {
        await _execute(
          'UPDATE music_playlist_tracks SET position=? WHERE playlist_id=? AND track_id=?',
          [i, id, ids[i]],
        );
      }
    });
    notifyListeners();
  }

  Future<void> saveLyrics(
    String id,
    String text, {
    String source = 'user',
    int? offset,
  }) async {
    await _execute(
      '''INSERT INTO music_lyrics(track_id,text,source,offset_ms) VALUES(?,?,?,?) ON CONFLICT(track_id)
      DO UPDATE SET text=excluded.text,source=excluded.source,offset_ms=COALESCE(?,music_lyrics.offset_ms)''',
      [id, text, source, offset ?? 0, offset],
    );
    notifyListeners();
  }

  Future<void> setLyricOffset(String id, int offset) async {
    await _execute('UPDATE music_lyrics SET offset_ms=? WHERE track_id=?', [
      offset,
      id,
    ]);
    await putState('lyric-offset:$id', {'offset': offset});
  }

  Future<({String text, int offset})?> lyrics(String id) async {
    final r = await _select(
      'SELECT text,offset_ms FROM music_lyrics WHERE track_id=?',
      [id],
    );
    return r.isEmpty
        ? null
        : (
            text: r.first.read<String>('text'),
            offset: r.first.read<int>('offset_ms'),
          );
  }

  Future<void> saveHistory(
    MusicTrack t,
    Duration position,
    Duration duration,
  ) async {
    await saveTrack(t, notify: false);
    await _execute(
      '''INSERT INTO music_history(track_id,position_ms,duration_ms,played_at) VALUES(?,?,?,?)
      ON CONFLICT(track_id) DO UPDATE SET position_ms=excluded.position_ms,duration_ms=excluded.duration_ms,played_at=excluded.played_at''',
      [t.id, position.inMilliseconds, duration.inMilliseconds, _now],
    );
  }

  Future<Duration> progress(String id) async {
    final rows = await _select(
      'SELECT position_ms FROM music_history WHERE track_id=?',
      [id],
    );
    return rows.isEmpty
        ? Duration.zero
        : Duration(milliseconds: rows.first.read<int>('position_ms'));
  }

  Future<List<MusicTrack>> recent({int limit = 30}) async => (await _select(
    '''SELECT t.payload FROM music_history h
    JOIN music_tracks t ON h.track_id=t.id ORDER BY h.played_at DESC LIMIT ?''',
    [limit],
  )).map(_track).toList();
  Future<void> putState(String key, Map<String, dynamic> value) async {
    await _execute(
      'INSERT INTO music_state(key,payload) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload',
      [key, jsonEncode(value)],
    );
  }

  Future<Map<String, dynamic>?> state(String key) async {
    final r = await _select('SELECT payload FROM music_state WHERE key=?', [
      key,
    ]);
    return r.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(r.first.read<String>('payload')) as Map,
          );
  }

  Future<void> saveDownload(
    String id,
    Map<String, dynamic> payload,
    String status,
  ) async {
    await _execute(
      '''INSERT INTO music_downloads(track_id,payload,status,updated) VALUES(?,?,?,?)
      ON CONFLICT(track_id) DO UPDATE SET payload=excluded.payload,status=excluded.status,updated=excluded.updated''',
      [id, jsonEncode(payload), status, _now],
    );
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> downloads() async =>
      (await _select(
            'SELECT payload FROM music_downloads ORDER BY updated DESC',
          ))
          .map(
            (r) => Map<String, dynamic>.from(
              jsonDecode(r.read<String>('payload')) as Map,
            ),
          )
          .toList();
  Future<void> removeDownload(String id) async {
    await _execute('DELETE FROM music_downloads WHERE track_id=?', [id]);
    notifyListeners();
  }
}
