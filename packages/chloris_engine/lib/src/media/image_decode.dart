import 'dart:convert';
import 'dart:typed_data';

import '../js/java_host.dart';
import '../js/js_runtime.dart';
import '../models/book.dart';
import '../models/book_source.dart';

/// Decrypt cover / chapter images with legado `coverDecodeJs` / `imageDecode`.
///
/// JS sees `result` as base64 of the raw bytes and `src` as the URL.
/// Return value may be base64, a data URI, or unchanged input.
class ImageDecoder {
  static Future<Uint8List> decode({
    required Uint8List bytes,
    required String src,
    required String js,
    required JsRuntime jsRuntime,
    JavaHost? javaHost,
    Book? book,
    BookSource? source,
  }) async {
    final script = js.trim();
    if (script.isEmpty || bytes.isEmpty) return bytes;
    final input = base64.encode(bytes);
    try {
      final out = await jsRuntime.eval(
        script,
        JsScope(
          variables: {
            'result': input,
            'src': src,
            'book': book,
            'source': source,
            'java': javaHost,
          },
        ),
      );
      final decoded = bytesFromJs(out, input);
      return decoded ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  static String? decodeJs(BookSource? source, {required bool isCover}) {
    if (source == null) return null;
    if (isCover) {
      final js = source.coverDecodeJs?.trim();
      return (js == null || js.isEmpty) ? null : js;
    }
    final js = source.getContentRule().imageDecode?.trim();
    return (js == null || js.isEmpty) ? null : js;
  }

  static Uint8List? bytesFromJs(Object? out, String originalB64) {
    if (out == null) return null;
    if (out is Uint8List) return out.isEmpty ? null : out;
    if (out is List<int>) return Uint8List.fromList(out);
    var s = out.toString().trim();
    if (s.isEmpty || s == originalB64) return null;
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      if (comma > 0) s = s.substring(comma + 1);
    }
    s = s.replaceAll(RegExp(r'\s+'), '');
    try {
      final bytes = base64.decode(s);
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }
}
