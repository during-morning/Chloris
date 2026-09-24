import 'dart:convert';

import '../constants/constants.dart';
import '../json/json_kit.dart';
import '../net/network_utils.dart';

class ReadConfig {
  ReadConfig({
    this.reverseToc = false,
    this.pageAnim,
    this.reSegment = false,
    this.imageStyle,
    this.useReplaceRule,
    this.delTag = 0,
    this.ttsEngine,
    this.splitLongChapter = true,
    this.readSimulating = false,
    this.startDate,
    this.startChapter,
    this.dailyChapters = 3,
    this.openCredits = 0,
    this.closeCredits = 0,
    this.playMode = 0,
    this.playSpeed = 1.0,
  });

  bool reverseToc;
  int? pageAnim;
  bool reSegment;
  String? imageStyle;
  bool? useReplaceRule;
  int delTag;
  String? ttsEngine;
  bool splitLongChapter;
  bool readSimulating;
  String? startDate;
  int? startChapter;
  int dailyChapters;
  int openCredits;
  int closeCredits;
  int playMode;
  double playSpeed;

  factory ReadConfig.fromJson(Map<String, dynamic> json) {
    return ReadConfig(
      reverseToc: JsonKit.boolOf(json['reverseToc']),
      pageAnim: JsonKit.intOrNull(json['pageAnim']),
      reSegment: JsonKit.boolOf(json['reSegment']),
      imageStyle: JsonKit.string(json['imageStyle']),
      useReplaceRule: json.containsKey('useReplaceRule')
          ? JsonKit.boolOf(json['useReplaceRule'])
          : null,
      delTag: JsonKit.intOf(json['delTag']),
      ttsEngine: JsonKit.string(json['ttsEngine']),
      splitLongChapter: JsonKit.boolOf(json['splitLongChapter'], true),
      readSimulating: JsonKit.boolOf(json['readSimulating']),
      startDate: JsonKit.string(json['startDate']),
      startChapter: JsonKit.intOrNull(json['startChapter']),
      dailyChapters: JsonKit.intOf(json['dailyChapters'], 3),
      openCredits: JsonKit.intOf(json['openCredits']),
      closeCredits: JsonKit.intOf(json['closeCredits']),
      playMode: JsonKit.intOf(json['playMode']),
      playSpeed: JsonKit.doubleOf(json['playSpeed'], 1),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'reverseToc': reverseToc,
    'pageAnim': pageAnim,
    'reSegment': reSegment,
    'imageStyle': imageStyle,
    'useReplaceRule': useReplaceRule,
    'delTag': delTag,
    'ttsEngine': ttsEngine,
    'splitLongChapter': splitLongChapter,
    'readSimulating': readSimulating,
    'startDate': startDate,
    'startChapter': startChapter,
    'dailyChapters': dailyChapters,
    'openCredits': openCredits,
    'closeCredits': closeCredits,
    'playMode': playMode,
    'playSpeed': playSpeed,
  });
}

/// Mirrors `io.legado.app.data.entities.Book`.
class Book {
  Book({
    required this.bookUrl,
    this.tocUrl = '',
    this.origin = BookType.localTag,
    this.originName = '',
    this.name = '',
    this.author = '',
    this.kind,
    this.customTag,
    this.coverUrl,
    this.customCoverUrl,
    this.intro,
    this.customIntro,
    this.charset,
    this.type = BookType.text,
    this.group = 0,
    this.latestChapterTitle,
    this.latestChapterTime,
    this.lastCheckTime,
    this.lastCheckCount = 0,
    this.totalChapterNum = 0,
    this.durChapterTitle,
    this.durChapterIndex = 0,
    this.durVolumeIndex = 0,
    this.chapterInVolumeIndex = 0,
    this.durChapterPos = 0,
    this.durChapterTime,
    this.wordCount,
    this.canUpdate = true,
    this.order = 0,
    this.originOrder = 0,
    this.variable,
    this.readConfig,
    this.syncTime = 0,
    this.infoHtml,
    this.tocHtml,
    this.downloadUrls,
  });

  String bookUrl;
  String tocUrl;
  String origin;
  String originName;
  String name;
  String author;
  String? kind;
  String? customTag;
  String? coverUrl;
  String? customCoverUrl;
  String? intro;
  String? customIntro;
  String? charset;
  int type;
  int group;
  String? latestChapterTitle;
  int? latestChapterTime;
  int? lastCheckTime;
  int lastCheckCount;
  int totalChapterNum;
  String? durChapterTitle;
  int durChapterIndex;
  int durVolumeIndex;
  int chapterInVolumeIndex;
  int durChapterPos;
  int? durChapterTime;
  String? wordCount;
  bool canUpdate;
  int order;
  int originOrder;
  String? variable;
  ReadConfig? readConfig;
  int syncTime;
  String? infoHtml;
  String? tocHtml;
  List<String>? downloadUrls;

  bool get isAudio => BookType.has(type, BookType.audio);
  bool get isImage => BookType.has(type, BookType.image);
  bool get isVideo => BookType.has(type, BookType.video);
  bool get isLocal =>
      BookType.has(type, BookType.local) ||
      origin == BookType.localTag ||
      origin.startsWith(BookType.webDavTag);
  bool get isLocalTxt => isLocal && originName.toLowerCase().endsWith('.txt');
  bool get isEpub => isLocal && originName.toLowerCase().endsWith('.epub');

  void putVariable(String key, String value) {
    final map = _decodeVariable(variable);
    map[key] = value;
    variable = jsonEncode(map);
  }

  String getVariable(String key) => _decodeVariable(variable)[key] ?? '';

  String? get displayCover =>
      (customCoverUrl == null || customCoverUrl!.isEmpty)
      ? coverUrl
      : customCoverUrl;
  String? get displayIntro {
    final raw = (customIntro == null || customIntro!.isEmpty)
        ? intro
        : customIntro;
    if (raw == null || raw.isEmpty) return raw;
    return sanitizeBookIntro(raw, name: name, author: author);
  }

  ReadConfig get config => readConfig ??= ReadConfig();

  int effectivePageAnim({required int fallback, required bool lockNoAnim}) {
    if (lockNoAnim) return PageAnim.noAnim;
    return config.pageAnim ?? (isImage ? PageAnim.scroll : fallback);
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      bookUrl: JsonKit.stringOr(json['bookUrl']),
      tocUrl: JsonKit.stringOr(json['tocUrl']),
      origin: JsonKit.stringOr(json['origin'], BookType.localTag),
      originName: JsonKit.stringOr(json['originName']),
      name: JsonKit.stringOr(json['name']),
      author: JsonKit.stringOr(json['author']),
      kind: JsonKit.string(json['kind']),
      customTag: JsonKit.string(json['customTag']),
      coverUrl: JsonKit.string(json['coverUrl']),
      customCoverUrl: JsonKit.string(json['customCoverUrl']),
      intro: JsonKit.string(json['intro']),
      customIntro: JsonKit.string(json['customIntro']),
      charset: JsonKit.string(json['charset']),
      type: JsonKit.intOf(json['type'], BookType.text),
      group: JsonKit.intOf(json['group']),
      latestChapterTitle: JsonKit.string(json['latestChapterTitle']),
      latestChapterTime: JsonKit.intOrNull(json['latestChapterTime']),
      lastCheckTime: JsonKit.intOrNull(json['lastCheckTime']),
      lastCheckCount: JsonKit.intOf(json['lastCheckCount']),
      totalChapterNum: JsonKit.intOf(json['totalChapterNum']),
      durChapterTitle: JsonKit.string(json['durChapterTitle']),
      durChapterIndex: JsonKit.intOf(json['durChapterIndex']),
      durVolumeIndex: JsonKit.intOf(json['durVolumeIndex']),
      chapterInVolumeIndex: JsonKit.intOf(json['chapterInVolumeIndex']),
      durChapterPos: JsonKit.intOf(json['durChapterPos']),
      durChapterTime: JsonKit.intOrNull(json['durChapterTime']),
      wordCount: JsonKit.string(json['wordCount']),
      canUpdate: JsonKit.boolOf(json['canUpdate'], true),
      order: JsonKit.intOf(json['order']),
      originOrder: JsonKit.intOf(json['originOrder']),
      variable: JsonKit.string(json['variable']),
      readConfig: JsonKit.object(json['readConfig'], ReadConfig.fromJson),
      syncTime: JsonKit.intOf(json['syncTime']),
      infoHtml: JsonKit.string(json['infoHtml']),
      tocHtml: JsonKit.string(json['tocHtml']),
      downloadUrls: (JsonKit.list(json['downloadUrls']) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'bookUrl': bookUrl,
    'tocUrl': tocUrl,
    'origin': origin,
    'originName': originName,
    'name': name,
    'author': author,
    'kind': kind,
    'customTag': customTag,
    'coverUrl': coverUrl,
    'customCoverUrl': customCoverUrl,
    'intro': intro,
    'customIntro': customIntro,
    'charset': charset,
    'type': type,
    'group': group,
    'latestChapterTitle': latestChapterTitle,
    'latestChapterTime': latestChapterTime,
    'lastCheckTime': lastCheckTime,
    'lastCheckCount': lastCheckCount,
    'totalChapterNum': totalChapterNum,
    'durChapterTitle': durChapterTitle,
    'durChapterIndex': durChapterIndex,
    'durVolumeIndex': durVolumeIndex,
    'chapterInVolumeIndex': chapterInVolumeIndex,
    'durChapterPos': durChapterPos,
    'durChapterTime': durChapterTime,
    'wordCount': wordCount,
    'canUpdate': canUpdate,
    'order': order,
    'originOrder': originOrder,
    'variable': variable,
    'readConfig': readConfig?.toJson(),
    'syncTime': syncTime,
    'downloadUrls': downloadUrls,
  });
}

class BookChapter {
  BookChapter({
    required this.url,
    this.title = '',
    this.isVolume = false,
    this.baseUrl = '',
    this.bookUrl = '',
    this.index = 0,
    this.isVip = false,
    this.isPay = false,
    this.resourceUrl,
    this.tag,
    this.wordCount,
    this.start,
    this.end,
    this.startFragmentId,
    this.endFragmentId,
    this.variable,
    this.imgUrl,
  });

  String url;
  String title;
  bool isVolume;
  String baseUrl;
  String bookUrl;
  int index;
  bool isVip;
  bool isPay;
  String? resourceUrl;
  String? tag;
  String? wordCount;
  int? start;
  int? end;
  String? startFragmentId;
  String? endFragmentId;
  String? variable;
  String? imgUrl;

  void putVariable(String key, String value) {
    final map = _decodeVariable(variable);
    map[key] = value;
    variable = jsonEncode(map);
  }

  String getVariable(String key) => _decodeVariable(variable)[key] ?? '';

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      url: JsonKit.stringOr(json['url']),
      title: JsonKit.stringOr(json['title']),
      isVolume: JsonKit.boolOf(json['isVolume']),
      baseUrl: JsonKit.stringOr(json['baseUrl']),
      bookUrl: JsonKit.stringOr(json['bookUrl']),
      index: JsonKit.intOf(json['index']),
      isVip: JsonKit.boolOf(json['isVip']),
      isPay: JsonKit.boolOf(json['isPay']),
      resourceUrl: JsonKit.string(json['resourceUrl']),
      tag: JsonKit.string(json['tag']),
      wordCount: JsonKit.string(json['wordCount']),
      start: JsonKit.intOrNull(json['start']),
      end: JsonKit.intOrNull(json['end']),
      startFragmentId: JsonKit.string(json['startFragmentId']),
      endFragmentId: JsonKit.string(json['endFragmentId']),
      variable: JsonKit.string(json['variable']),
      imgUrl: JsonKit.string(json['imgUrl']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'url': url,
    'title': title,
    'isVolume': isVolume,
    'baseUrl': baseUrl,
    'bookUrl': bookUrl,
    'index': index,
    'isVip': isVip,
    'isPay': isPay,
    'resourceUrl': resourceUrl,
    'tag': tag,
    'wordCount': wordCount,
    'start': start,
    'end': end,
    'startFragmentId': startFragmentId,
    'endFragmentId': endFragmentId,
    'variable': variable,
    'imgUrl': imgUrl,
  });
}

Map<String, String> _decodeVariable(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final map = JsonKit.map(raw);
  if (map == null) return {};
  return map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
}

class SearchBook {
  SearchBook({
    required this.bookUrl,
    this.origin = '',
    this.originName = '',
    this.type = BookType.text,
    this.name = '',
    this.author = '',
    this.kind,
    this.coverUrl,
    this.intro,
    this.wordCount,
    this.latestChapterTitle,
    this.tocUrl = '',
    this.time,
    this.variable,
    this.originOrder = 0,
    this.chapterWordCountText,
    this.chapterWordCount = -1,
    this.respondTime = -1,
    Set<String>? origins,
    this.infoHtml,
    this.tocHtml,
  }) : origins = origins ?? {origin} {
    originUrls[origin] = bookUrl;
  }

  String bookUrl;
  String origin;
  String originName;
  int type;
  String name;
  String author;
  String? kind;
  String? coverUrl;
  String? intro;
  String? wordCount;
  String? latestChapterTitle;
  String tocUrl;
  int? time;
  String? variable;
  int originOrder;
  String? chapterWordCountText;
  int chapterWordCount;
  int respondTime;
  Set<String> origins;
  String? infoHtml;
  String? tocHtml;

  final originUrls = <String, String>{};

  void addOrigin(String value, [String? url]) {
    origins.add(value);
    originUrls[value] = url ?? bookUrl;
  }

  Book toBook() {
    final originsJson = origins.join(',');
    final urlsJson = originUrls.entries
        .map((e) => '${e.key}=>${e.value}')
        .join('\n');
    return Book(
      bookUrl: bookUrl,
      tocUrl: tocUrl,
      origin: origin,
      originName: originName,
      name: name,
      author: author,
      kind: kind,
      coverUrl: coverUrl,
      intro: intro,
      type: type,
      wordCount: wordCount,
      latestChapterTitle: latestChapterTitle,
      originOrder: originOrder,
      variable: 'origins=$originsJson\nurls=$urlsJson',
      infoHtml: infoHtml,
      tocHtml: tocHtml,
    );
  }

  factory SearchBook.fromJson(Map<String, dynamic> json) {
    return SearchBook(
      bookUrl: JsonKit.stringOr(json['bookUrl']),
      origin: JsonKit.stringOr(json['origin']),
      originName: JsonKit.stringOr(json['originName']),
      type: JsonKit.intOf(json['type'], BookType.text),
      name: JsonKit.stringOr(json['name']),
      author: JsonKit.stringOr(json['author']),
      kind: JsonKit.string(json['kind']),
      coverUrl: JsonKit.string(json['coverUrl']),
      intro: JsonKit.string(json['intro']),
      wordCount: JsonKit.string(json['wordCount']),
      latestChapterTitle: JsonKit.string(json['latestChapterTitle']),
      tocUrl: JsonKit.stringOr(json['tocUrl']),
      time: JsonKit.intOrNull(json['time']),
      variable: JsonKit.string(json['variable']),
      originOrder: JsonKit.intOf(json['originOrder']),
      chapterWordCountText: JsonKit.string(json['chapterWordCountText']),
      chapterWordCount: JsonKit.intOf(json['chapterWordCount'], -1),
      respondTime: JsonKit.intOf(json['respondTime'], -1),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'bookUrl': bookUrl,
    'origin': origin,
    'originName': originName,
    'type': type,
    'name': name,
    'author': author,
    'kind': kind,
    'coverUrl': coverUrl,
    'intro': intro,
    'wordCount': wordCount,
    'latestChapterTitle': latestChapterTitle,
    'tocUrl': tocUrl,
    'time': time,
    'variable': variable,
    'originOrder': originOrder,
    'chapterWordCountText': chapterWordCountText,
    'chapterWordCount': chapterWordCount,
    'respondTime': respondTime,
  });
}

class BookProgress {
  const BookProgress({
    required this.name,
    required this.author,
    required this.durChapterIndex,
    required this.durChapterPos,
    required this.durChapterTime,
    this.durChapterTitle,
  });

  final String name;
  final String author;
  final int durChapterIndex;
  final int durChapterPos;
  final int durChapterTime;
  final String? durChapterTitle;

  factory BookProgress.fromBook(Book book) {
    return BookProgress(
      name: book.name,
      author: book.author,
      durChapterIndex: book.durChapterIndex,
      durChapterPos: book.durChapterPos,
      durChapterTime: book.durChapterTime ?? 0,
      durChapterTitle: book.durChapterTitle,
    );
  }

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    return BookProgress(
      name: JsonKit.stringOr(json['name']),
      author: JsonKit.stringOr(json['author']),
      durChapterIndex: JsonKit.intOf(json['durChapterIndex']),
      durChapterPos: JsonKit.intOf(json['durChapterPos']),
      durChapterTime: JsonKit.intOf(json['durChapterTime']),
      durChapterTitle: JsonKit.string(json['durChapterTitle']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'name': name,
    'author': author,
    'durChapterIndex': durChapterIndex,
    'durChapterPos': durChapterPos,
    'durChapterTime': durChapterTime,
    'durChapterTitle': durChapterTitle,
  });
}
