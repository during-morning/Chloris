import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class LocalAudioUrl {
  LocalAudioUrl(Uint8List bytes, String mimeType)
    : url = web.URL.createObjectURL(
        web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType)),
      );
  final String url;
  bool _released = false;
  void release() {
    if (_released) return;
    _released = true;
    web.URL.revokeObjectURL(url);
  }
}
