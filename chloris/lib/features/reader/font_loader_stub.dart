import 'font_loader.dart';

class StubReaderFontLoader implements ReaderFontLoader {
  @override
  Future<bool> register(String family, List<int> bytes) async => false;

  @override
  Future<void> remove(String family) async {}
}

ReaderFontLoader get readerFontLoader => StubReaderFontLoader();
