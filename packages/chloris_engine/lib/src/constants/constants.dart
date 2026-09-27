/// Mirrors `io.legado.app.constant.BookSourceType`.
abstract final class BookSourceType {
  static const int text = 0;
  static const int audio = 1;
  static const int image = 2;
  static const int file = 3;
  static const int video = 4;

  static String label(int type) {
    return switch (type) {
      audio => '听',
      image => '漫',
      file => '文件',
      video => '视频',
      _ => '文',
    };
  }
}

/// Bit flags mirroring `io.legado.app.constant.BookType`.
abstract final class BookType {
  static const int video = 0x04;
  static const int text = 0x08;
  static const int updateError = 0x10;
  static const int audio = 0x20;
  static const int image = 0x40;
  static const int webFile = 0x80;
  static const int local = 0x100;
  static const int archive = 0x200;
  static const int notShelf = 0x400;

  static const int allBookType = video | text | image | audio | webFile;
  static const String localTag = 'loc_book';
  static const String webDavTag = 'webDav::';

  static bool has(int type, int flag) => (type & flag) == flag;

  static int fromSourceType(int sourceType) {
    return switch (sourceType) {
      BookSourceType.audio => audio,
      BookSourceType.image => image,
      BookSourceType.file => webFile,
      BookSourceType.video => video,
      _ => text,
    };
  }
}

/// Mirrors `io.legado.app.constant.PageAnim`.
abstract final class PageAnim {
  static const int cover = 0;
  static const int slide = 1;

  /// Legacy value retained so settings imported from Legado remain readable.
  static const int simulation = 2;
  static const int scroll = 3;
  static const int noAnim = 4;

  static const List<int> all = [cover, slide, scroll, noAnim];
  static const List<int> choices = [cover, slide, scroll, noAnim];

  static int normalize(int anim) => all.contains(anim) ? anim : slide;

  static String label(int anim) {
    return switch (anim) {
      cover => '覆盖',
      slide => '滑动',
      scroll => '滚动',
      _ => '无动画',
    };
  }
}

abstract final class AppPattern {
  static final RegExp js = RegExp(
    r'<js>([\w\W]*?)</js>|@js:([\w\W]*)',
    caseSensitive: false,
  );
  static final RegExp webJs = RegExp(
    r'@webjs:([\w\W]{5,})',
    caseSensitive: false,
  );
  static final RegExp exp = RegExp(r'\{\{([\w\W]*?)\}\}');

  /// Matches an `<img>` tag across newlines / wrapped attributes.
  static final RegExp img = RegExp(r'<img\b[\s\S]*?>', caseSensitive: false);
  static final RegExp splitGroup = RegExp(r'[,;，；]');

  /// TextFile joins toc regex and optional JS replacement with these chars.
  static const String txtTocJoiner = '🫅🈳🏻';
}

/// Appearance is an app concern, but page-anim locking lives with engine constants.
enum AppearanceMode { minimal, animated, zhouli }

enum AppColorSchemeMode { light, dark, system }
