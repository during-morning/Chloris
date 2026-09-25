import 'dart:typed_data';

/// Everything the HTTP API needs from the application layer.
///
/// The server owns sockets and JSON; it must not reach into Riverpod, the
/// engine or the database itself. Each method maps to one route in
/// [ChlorisApiRoute], which keeps the wire surface and the application surface
/// in step instead of letting routes grow their own logic.
///
/// A server started without a backend answers the state-dependent routes with
/// an explicit "capability missing" error rather than an empty success — a
/// client must be able to tell "no books" from "this server cannot list books".
abstract interface class ServerBackend {
  /// `/getBookshelf`
  Future<List<Map<String, dynamic>>> bookshelf();

  /// `/saveBook`
  Future<void> saveBook(Map<String, dynamic> book);

  /// `/deleteBook`
  Future<void> deleteBook(String bookUrl);

  /// `/saveBookProgress`
  Future<void> saveProgress(Map<String, dynamic> progress);

  /// `/getChapterList` and `/refreshToc`
  Future<List<Map<String, dynamic>>> chapterList(
    String bookUrl, {
    bool refresh = false,
  });

  /// `/getBookContent`
  Future<Map<String, dynamic>> bookContent(String bookUrl, int chapterIndex);

  /// WebSocket `/searchBook` search stream.
  ///
  /// Older backend implementations may omit this optional capability; the
  /// server turns the explicit error into a 501 capability response.
  Future<List<Map<String, dynamic>>> search(
    String sourceUrl,
    String query, {
    int page = 1,
  }) async {
    throw DomainError(
      code: 'capability_missing',
      stage: DomainErrorStage.search,
      message: '搜索功能未装配',
      recoverable: false,
      retryable: false,
    );
  }

  Future<Uint8List?> cover(String bookUrl);

  /// `/image` — raw bytes for a remote image URL.
  Future<Uint8List?> image(String url);
}
