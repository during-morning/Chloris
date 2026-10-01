import 'package:drift/drift.dart';

Future<void> createMusicSchema(GeneratedDatabase db) async {
  for (final sql in const [
    '''CREATE TABLE IF NOT EXISTS music_tracks (
      id TEXT PRIMARY KEY, payload TEXT NOT NULL, title TEXT NOT NULL, artist TEXT NOT NULL DEFAULT '',
      album TEXT NOT NULL DEFAULT '', favorite INTEGER NOT NULL DEFAULT 0, updated INTEGER NOT NULL)''',
    'CREATE INDEX IF NOT EXISTS music_tracks_title ON music_tracks(title)',
    'CREATE INDEX IF NOT EXISTS music_tracks_artist ON music_tracks(artist)',
    'CREATE INDEX IF NOT EXISTS music_tracks_album ON music_tracks(album)',
    'CREATE INDEX IF NOT EXISTS music_tracks_title_nocase ON music_tracks(title COLLATE NOCASE,id)',
    'CREATE INDEX IF NOT EXISTS music_tracks_artist_nocase ON music_tracks(artist COLLATE NOCASE,title)',
    'CREATE INDEX IF NOT EXISTS music_tracks_album_nocase ON music_tracks(album COLLATE NOCASE,title)',
    'CREATE INDEX IF NOT EXISTS music_tracks_recent ON music_tracks(updated DESC,id)',
    'CREATE TABLE IF NOT EXISTS music_playlists (id TEXT PRIMARY KEY, name TEXT NOT NULL, cover TEXT, updated INTEGER NOT NULL)',
    '''CREATE TABLE IF NOT EXISTS music_playlist_tracks (playlist_id TEXT NOT NULL REFERENCES music_playlists(id) ON DELETE CASCADE,
      track_id TEXT NOT NULL REFERENCES music_tracks(id) ON DELETE CASCADE, position INTEGER NOT NULL,
      PRIMARY KEY(playlist_id, track_id))''',
    'CREATE INDEX IF NOT EXISTS music_playlist_order ON music_playlist_tracks(playlist_id, position)',
    '''CREATE TABLE IF NOT EXISTS music_lyrics (track_id TEXT PRIMARY KEY REFERENCES music_tracks(id) ON DELETE CASCADE,
      text TEXT NOT NULL, source TEXT NOT NULL, offset_ms INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS music_history (track_id TEXT PRIMARY KEY REFERENCES music_tracks(id) ON DELETE CASCADE,
      position_ms INTEGER NOT NULL, duration_ms INTEGER NOT NULL, played_at INTEGER NOT NULL)''',
    'CREATE TABLE IF NOT EXISTS music_state (key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    '''CREATE TABLE IF NOT EXISTS music_downloads (track_id TEXT PRIMARY KEY, payload TEXT NOT NULL,
      status TEXT NOT NULL, updated INTEGER NOT NULL)''',
  ]) {
    await db.customStatement(sql);
  }
}
