import '../../data/database/app_database.dart';

/// Best-effort Drift. Tests and Web stay on Kv if open fails.
class AppDb {
  AppDb._();
  static AppDatabase? _db;
  static Future<AppDatabase?>? _opening;

  /// The database after startup has opened it. Cache-only code may use this
  /// without causing plugin-backed storage initialization in tests or Web.
  static AppDatabase? get current => _db;

  static Future<AppDatabase?> open() {
    final active = _db;
    if (active != null) return Future.value(active);
    final opening = _opening;
    if (opening != null) return opening;
    final future = _open();
    _opening = future;
    return future;
  }

  static Future<AppDatabase?> _open() async {
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
    } finally {
      _opening = null;
    }
  }
}
