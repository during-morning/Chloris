import 'dart:typed_data';

class LocalAudioUrl {
  LocalAudioUrl(Uint8List bytes, String mimeType)
    : url = Uri.dataFromBytes(bytes, mimeType: mimeType).toString();
  final String url;
  void release() {}
}
