import 'package:chloris_engine/chloris_engine.dart' show BookType;
import 'package:drift/drift.dart';

import 'app_database.dart';

/// Bit-mask shelf queries mirroring Legado's `BookDao`.
///
/// Legado filters the shelf with SQL bit operations, for example
/// `BookDao.flowRoot`: `type & 8 > 0 and type & 256 = 0`. Drift has no `&`
/// operator, so the predicates are expressed as [CustomExpression].
///
/// Doing this in Dart *after* fetching would change paging and counts — a
/// `.limit(20)` on an already-filtered list is not the same query — which is
/// why the predicate has to stay in SQL.
class BookQueries {
  const BookQueries(this._db);

  final AppDatabase _db;

  /// `type & flag != 0`
  static Expression<bool> hasFlag(int flag) =>
      CustomExpression<bool>('(type & ${_safeFlag(flag)}) != 0');

  /// `type & flag == 0`
  static Expression<bool> lacksFlag(int flag) =>
      CustomExpression<bool>('(type & ${_safeFlag(flag)}) = 0');

  /// The only values allowed to reach the generated SQL.
  ///
  /// drift's `CustomExpression` writes raw text and takes no bind parameters,
  /// so the flag has to be interpolated. Restricting it to the compile-time
  /// `BookType` bits keeps that interpolation free of any caller-supplied
  /// string, which is what makes it safe.
  static const _knownFlags = {
    BookType.video,
    BookType.text,
    BookType.updateError,
    BookType.audio,
    BookType.image,
    BookType.webFile,
    BookType.local,
    BookType.archive,
    BookType.notShelf,
  };

  static String _safeFlag(int flag) {
    if (!_knownFlags.contains(flag)) {
      throw ArgumentError.value(flag, 'flag', '不是已知的 BookType 位值');
    }
    return '$flag';
  }

  /// Legado assigns each user group a single bit (`BookGroupDao.getUnusedId`),
  /// so a mask with more than one bit set is not a group id.
  static String _safeGroupMask(int groupId) {
    if (groupId <= 0 || (groupId & (groupId - 1)) != 0) {
      throw ArgumentError.value(groupId, 'groupId', '分组 id 必须是单个正位标志');
    }
    return '$groupId';
  }

  /// `("group" & mask) != 0` — a book may belong to several groups.
  static Expression<bool> inGroup(int groupId) => CustomExpression<bool>(
    '("group" & ${_safeGroupMask(groupId)}) != 0',
  );

  /// Legado `BookDao.flowByUserGroup`.
  SimpleSelectStatement<$BooksTable, Book> flowByUserGroup(int groupId) =>
      _db.select(_db.books)..where((t) => inGroup(groupId));

  /// Legado's `flowRoot`: scraped text books that are on the shelf and not in
  /// any *user* group.
  ///
  /// `book_groups` rows with a negative id are virtual ("all", "local", …), so
  /// the subquery only sums positive ids. This clause needs `group` to be a bit
  /// mask; while the column held a single nullable id it would have compared
  /// against the wrong thing.
  SimpleSelectStatement<$BooksTable, Book> flowRoot() =>
      _db.select(_db.books)
        ..where(
          (t) =>
              hasFlag(BookType.text) &
              lacksFlag(BookType.local) &
              lacksFlag(BookType.notShelf) &
              CustomExpression<bool>(
                '((SELECT COALESCE(SUM(group_id), 0) FROM book_groups '
                'WHERE group_id > 0) & "group") = 0',
              ),
        );

  /// On-device books, matching Legado's `BookDao.flowLocal`.
  SimpleSelectStatement<$BooksTable, Book> flowLocal() =>
      _db.select(_db.books)..where((t) => hasFlag(BookType.local));

  /// Scraped books, i.e. everything without the local flag.
  SimpleSelectStatement<$BooksTable, Book> flowOnline() =>
      _db.select(_db.books)..where((t) => lacksFlag(BookType.local));

  SimpleSelectStatement<$BooksTable, Book> flowAudio() =>
      _db.select(_db.books)..where((t) => hasFlag(BookType.audio));

  SimpleSelectStatement<$BooksTable, Book> flowVideo() =>
      _db.select(_db.books)..where((t) => hasFlag(BookType.video));

  SimpleSelectStatement<$BooksTable, Book> flowImage() =>
      _db.select(_db.books)..where((t) => hasFlag(BookType.image));

  /// Books whose last refresh failed, matching `flowUpdateError`.
  SimpleSelectStatement<$BooksTable, Book> flowUpdateError() =>
      _db.select(_db.books)..where((t) => hasFlag(BookType.updateError));

  /// Legado's `flowRoot` minus the group clause: scraped text books that are
  /// not on the "not on shelf" list.
  ///
  /// Kept for callers that want the shelf scope without the group filter.
  SimpleSelectStatement<$BooksTable, Book> flowRootUngrouped() =>
      _db.select(_db.books)
        ..where(
          (t) =>
              hasFlag(BookType.text) &
              lacksFlag(BookType.local) &
              lacksFlag(BookType.notShelf),
        );

  /// A book is on the shelf unless the `notShelf` flag is set.
  SimpleSelectStatement<$BooksTable, Book> flowShelf() =>
      _db.select(_db.books)..where((t) => lacksFlag(BookType.notShelf));
}
