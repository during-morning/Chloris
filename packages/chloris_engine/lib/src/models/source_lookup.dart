import 'book_source.dart';

/// Resolve a book `origin` (usually `bookSourceUrl`) back to a [BookSource].
BookSource? sourceByOrigin(Iterable<BookSource> sources, String? origin) {
  final key = (origin ?? '').trim();
  if (key.isEmpty) return null;
  for (final s in sources) {
    if (s.bookSourceUrl == key) return s;
  }
  final host = Uri.tryParse(key)?.host ?? '';
  if (host.isEmpty) return null;
  BookSource? hostHit;
  var hits = 0;
  for (final s in sources) {
    final h = Uri.tryParse(s.bookSourceUrl)?.host ?? '';
    if (h == host) {
      hostHit = s;
      hits++;
    }
  }
  return hits == 1 ? hostHit : null;
}
