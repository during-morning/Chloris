export 'font_loader_stub.dart'
    if (dart.library.html) 'font_loader_web.dart';

abstract class ReaderFontLoader {
  Future<bool> register(String family, List<int> bytes);
  Future<void> remove(String family);
}

ReaderFontLoader get readerFontLoader => throw UnsupportedError('Font loading unavailable');
