import '../../data/database/app_database.dart';

/// Best-effort Drift. Tests and Web stay on Kv if open fails.
class AppDb {
  AppDb._();
  static AppDatabase? _db;
  static bool _tried = false;

  static Future<AppDatabase?> open() async {
    if (_tried) return _db;
    _tried = true;
    try {
      final db = AppDatabase.connect();
      // Drift opens lazily: constructing the database touches nothing, so a
      // real failure (no path_provider, unreadable storage, missing sqlite3)
      // used to surface *later* as an unhandled asynchronous error that this
      // try/catch could not contain. Probing once makes the guard actually
      // guard, and keeps the "no database available" answer honest.
      await db.customSelect('SELECT 1').get();
      _db = db;
      return db;
    } catch (_) {
      _db = null;
      return null;
    }
  }
}
