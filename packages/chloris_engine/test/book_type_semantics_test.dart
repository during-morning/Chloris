import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

Book _book({int type = BookType.text, String origin = 'https://src.test'}) =>
    Book(bookUrl: 'https://book.test/1', name: 'n', type: type, origin: origin);

void main() {
  group('BookType flags mirror Legado', () {
    test('the bit values match io.legado.app.constant.BookType', () {
      expect(BookType.video, 0x04);
      expect(BookType.text, 0x08);
      expect(BookType.updateError, 0x10);
      expect(BookType.audio, 0x20);
      expect(BookType.image, 0x40);
      expect(BookType.webFile, 0x80);
      expect(BookType.local, 0x100);
      expect(BookType.archive, 0x200);
      expect(BookType.notShelf, 0x400);
    });

    test('has() tests a single bit', () {
      expect(BookType.has(BookType.local | BookType.text, BookType.local), isTrue);
      expect(BookType.has(BookType.local | BookType.text, BookType.text), isTrue);
      expect(BookType.has(BookType.text, BookType.local), isFalse);
      expect(BookType.has(0, BookType.local), isFalse);
    });

    test('fromSourceType maps every source type', () {
      expect(BookType.fromSourceType(BookSourceType.audio), BookType.audio);
      expect(BookType.fromSourceType(BookSourceType.image), BookType.image);
      expect(BookType.fromSourceType(BookSourceType.file), BookType.webFile);
      expect(BookType.fromSourceType(BookSourceType.video), BookType.video);
      expect(BookType.fromSourceType(BookSourceType.text), BookType.text);
    });

    test('fromSourceType never marks a scraped book as local', () {
      for (final t in const [
        BookSourceType.text,
        BookSourceType.audio,
        BookSourceType.image,
        BookSourceType.file,
        BookSourceType.video,
      ]) {
        expect(
          BookType.has(BookType.fromSourceType(t), BookType.local),
          isFalse,
          reason: 'source type $t',
        );
      }
    });
  });

  group('Book.isLocal', () {
    test('a local flag makes a book local regardless of origin', () {
      expect(
        _book(type: BookType.local | BookType.text, origin: 'https://src.test')
            .isLocal,
        isTrue,
      );
    });

    test('an origin tag alone also counts', () {
      expect(
        _book(type: BookType.text, origin: BookType.localTag).isLocal,
        isTrue,
      );
    });

    test('a WebDAV-backed book is local, not online', () {
      // The library filter used to compare `origin` against the local tag only,
      // which filed every WebDAV book under "online".
      expect(
        _book(type: BookType.text, origin: '${BookType.webDavTag}https://dav/x')
            .isLocal,
        isTrue,
      );
    });

    test('a scraped book is not local', () {
      expect(_book().isLocal, isFalse);
      expect(_book(type: BookType.audio).isLocal, isFalse);
      expect(_book(type: BookType.image).isLocal, isFalse);
      expect(_book(type: BookType.video).isLocal, isFalse);
    });

    test('local composes with the media flags', () {
      final b = _book(type: BookType.local | BookType.image);
      expect(b.isLocal, isTrue);
      expect(b.isImage, isTrue);
    });

    test('local txt and epub are still recognised by extension', () {
      final txt = Book(
        bookUrl: 'u',
        name: 'n',
        type: BookType.local | BookType.text,
        originName: 'a.txt',
      );
      expect(txt.isLocalTxt, isTrue);
      expect(txt.isEpub, isFalse);

      final epub = Book(
        bookUrl: 'u',
        name: 'n',
        type: BookType.local | BookType.text,
        originName: 'a.epub',
      );
      expect(epub.isEpub, isTrue);
      expect(epub.isLocalTxt, isFalse);
    });
  });
}
