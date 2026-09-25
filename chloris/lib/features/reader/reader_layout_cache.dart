import 'dart:collection';

/// Stable inputs that affect chapter pagination. Menu visibility is deliberately
/// absent because the reader menu is an overlay, not part of the text geometry.
final class ReaderLayoutKey {
  const ReaderLayoutKey({
    required this.contentHash,
    required this.chapterTitle,
    required this.bookTitle,
    required this.bookAuthor,
    required this.replaceFingerprint,
    required this.enableReplace,
    required this.chineseConvert,
    required this.paragraphIndent,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.pagePadding,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.fontFamily,
    required this.textScaler,
    required this.paragraphSpacing,
    required this.doublePage,
  });

  static const algorithmVersion = 2;

  final int contentHash;
  final String chapterTitle;
  final String bookTitle;
  final String bookAuthor;
  final int replaceFingerprint;
  final bool enableReplace;
  final bool chineseConvert;
  final int paragraphIndent;
  final int viewportWidth;
  final int viewportHeight;
  final int pagePadding;
  final int fontSize;
  final int lineHeight;
  final int letterSpacing;
  final String? fontFamily;
  final int textScaler;
  final int paragraphSpacing;
  final bool doublePage;

  @override
  bool operator ==(Object other) =>
      other is ReaderLayoutKey &&
      other.contentHash == contentHash &&
      other.chapterTitle == chapterTitle &&
      other.bookTitle == bookTitle &&
      other.bookAuthor == bookAuthor &&
      other.replaceFingerprint == replaceFingerprint &&
      other.enableReplace == enableReplace &&
      other.chineseConvert == chineseConvert &&
      other.paragraphIndent == paragraphIndent &&
      other.viewportWidth == viewportWidth &&
      other.viewportHeight == viewportHeight &&
      other.pagePadding == pagePadding &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.letterSpacing == letterSpacing &&
      other.fontFamily == fontFamily &&
      other.textScaler == textScaler &&
      other.paragraphSpacing == paragraphSpacing &&
      other.doublePage == doublePage;

  @override
  int get hashCode => Object.hash(
    algorithmVersion,
    contentHash,
    chapterTitle,
    bookTitle,
    bookAuthor,
    replaceFingerprint,
    enableReplace,
    chineseConvert,
    paragraphIndent,
    viewportWidth,
    viewportHeight,
    pagePadding,
    fontSize,
    lineHeight,
    letterSpacing,
    fontFamily,
    textScaler,
    paragraphSpacing,
    doublePage,
  );
}

class ReaderLayoutCache<T> {
  ReaderLayoutCache({this.maxEntries = 8, this.maxWeight = 4 * 1024 * 1024})
    : assert(maxEntries > 0),
      assert(maxWeight > 0);

  final int maxEntries;
  final int maxWeight;
  final _entries = LinkedHashMap<ReaderLayoutKey, _Entry<T>>();
  int _weight = 0;
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int invalidations = 0;

  T? get(ReaderLayoutKey key) {
    final value = _entries.remove(key);
    if (value == null) {
      misses++;
      return null;
    }
    _entries[key] = value;
    hits++;
    return value.value;
  }

  void put(ReaderLayoutKey key, T value, {int weight = 1}) {
    if (weight <= 0) return;
    final old = _entries.remove(key);
    if (old != null) _weight -= old.weight;
    _entries[key] = _Entry(value, weight);
    _weight += weight;
    while (_entries.length > maxEntries || _weight > maxWeight) {
      final first = _entries.keys.first;
      final removed = _entries.remove(first)!;
      _weight -= removed.weight;
      evictions++;
    }
  }

  void invalidate(ReaderLayoutKey key) {
    final removed = _entries.remove(key);
    if (removed == null) return;
    _weight -= removed.weight;
    invalidations++;
  }

  void clear() {
    if (_entries.isNotEmpty) invalidations += _entries.length;
    _entries.clear();
    _weight = 0;
  }

  int get length => _entries.length;
  int get weight => _weight;
}

final class _Entry<T> {
  const _Entry(this.value, this.weight);
  final T value;
  final int weight;
}
