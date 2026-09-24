import 'dart:html' as html;
import 'dart:typed_data';

import 'font_loader.dart';

class WebReaderFontLoader implements ReaderFontLoader {
  final Map<String, String> _urls = {};

  @override
  Future<bool> register(String family, List<int> bytes) async {
    final old = _urls[family];
    if (old != null) html.Url.revokeObjectUrl(old);
    final url = html.Url.createObjectUrl(
      html.Blob([Uint8List.fromList(bytes)], 'font/ttf'),
    );
    final face = html.FontFace(family, 'url("$url")');
    try {
      await face.load();
      html.document.fonts?.add(face);
      _urls[family] = url;
      return true;
    } catch (_) {
      html.Url.revokeObjectUrl(url);
      return false;
    }
  }

  @override
  Future<void> remove(String family) async {
    final url = _urls.remove(family);
    if (url != null) html.Url.revokeObjectUrl(url);
  }
}

ReaderFontLoader get readerFontLoader => WebReaderFontLoader();
