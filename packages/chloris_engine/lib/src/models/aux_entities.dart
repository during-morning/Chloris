import '../json/json_kit.dart';

class ReplaceRule {
  ReplaceRule({
    this.id,
    this.name = '',
    this.group,
    this.pattern = '',
    this.replacement = '',
    this.scope,
    this.scopeTitle = false,
    this.scopeContent = true,
    this.excludeScope,
    this.isEnabled = true,
    this.isRegex = true,
    this.timeoutMillisecond = 3000,
    this.order,
  });

  int? id;
  String name;
  String? group;
  String pattern;
  String replacement;
  String? scope;
  bool scopeTitle;
  bool scopeContent;
  String? excludeScope;
  bool isEnabled;
  bool isRegex;
  int timeoutMillisecond;
  int? order;

  bool get isValid {
    if (pattern.isEmpty) return false;
    if (isRegex) {
      try {
        RegExp(pattern);
      } catch (_) {
        return false;
      }
      if (pattern.endsWith('|') && !pattern.endsWith(r'\|')) return false;
    }
    return true;
  }

  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    return ReplaceRule(
      id: JsonKit.intOrNull(json['id']),
      name: JsonKit.stringOr(json['name']),
      group: JsonKit.string(json['group']),
      pattern: JsonKit.stringOr(json['pattern']),
      replacement: JsonKit.stringOr(json['replacement']),
      scope: JsonKit.string(json['scope']),
      scopeTitle: JsonKit.boolOf(json['scopeTitle']),
      scopeContent: JsonKit.boolOf(json['scopeContent'], true),
      excludeScope: JsonKit.string(json['excludeScope']),
      isEnabled: JsonKit.boolOf(json['isEnabled'], true),
      isRegex: JsonKit.boolOf(json['isRegex'], true),
      timeoutMillisecond: JsonKit.intOf(json['timeoutMillisecond'], 3000),
      order: JsonKit.intOrNull(json['order']) ?? JsonKit.intOrNull(json['sortOrder']),
    );
  }

  static List<ReplaceRule> listFromJson(dynamic raw) {
    final items = JsonKit.list(raw) ?? const [];
    return items
        .map((e) => JsonKit.map(e))
        .whereType<Map<String, dynamic>>()
        .map(ReplaceRule.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'id': id,
    'name': name,
    'group': group,
    'pattern': pattern,
    'replacement': replacement,
    'scope': scope,
    'scopeTitle': scopeTitle,
    'scopeContent': scopeContent,
    'excludeScope': excludeScope,
    'isEnabled': isEnabled,
    'isRegex': isRegex,
    'timeoutMillisecond': timeoutMillisecond,
    'order': order,
  });
}

class TxtTocRule {
  TxtTocRule({
    this.id,
    this.name = '',
    this.rule = '',
    this.replacement = '',
    this.example,
    this.serialNumber = -1,
    this.enable = true,
  });

  int? id;
  String name;
  String rule;
  String replacement;
  String? example;
  int serialNumber;
  bool enable;

  factory TxtTocRule.fromJson(Map<String, dynamic> json) {
    return TxtTocRule(
      id: JsonKit.intOrNull(json['id']),
      name: JsonKit.stringOr(json['name']),
      rule: JsonKit.stringOr(json['rule']),
      replacement: JsonKit.stringOr(json['replacement']),
      example: JsonKit.string(json['example']),
      serialNumber: JsonKit.intOf(json['serialNumber'], -1),
      enable: JsonKit.boolOf(json['enable'], true),
    );
  }

  static List<TxtTocRule> listFromJson(dynamic raw) {
    final items = JsonKit.list(raw) ?? const [];
    return items
        .map((e) => JsonKit.map(e))
        .whereType<Map<String, dynamic>>()
        .map(TxtTocRule.fromJson)
        .toList();
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'id': id,
    'name': name,
    'rule': rule,
    'replacement': replacement,
    'example': example,
    'serialNumber': serialNumber,
    'enable': enable,
  });
}

class Bookmark {
  Bookmark({
    required this.time,
    required this.bookName,
    required this.bookAuthor,
    this.chapterIndex = 0,
    this.chapterPos = 0,
    this.chapterName = '',
    this.bookText = '',
    this.content = '',
  });

  int time;
  String bookName;
  String bookAuthor;
  int chapterIndex;
  int chapterPos;
  String chapterName;
  String bookText;
  String content;

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      time: JsonKit.intOf(json['time']),
      bookName: JsonKit.stringOr(json['bookName']),
      bookAuthor: JsonKit.stringOr(json['bookAuthor']),
      chapterIndex: JsonKit.intOf(json['chapterIndex']),
      chapterPos: JsonKit.intOf(json['chapterPos']),
      chapterName: JsonKit.stringOr(json['chapterName']),
      bookText: JsonKit.stringOr(json['bookText']),
      content: JsonKit.stringOr(json['content']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'time': time,
    'bookName': bookName,
    'bookAuthor': bookAuthor,
    'chapterIndex': chapterIndex,
    'chapterPos': chapterPos,
    'chapterName': chapterName,
    'bookText': bookText,
    'content': content,
  });
}

class BookGroup {
  BookGroup({
    required this.groupId,
    this.groupName = '',
    this.cover,
    this.order = 0,
    this.enableRefresh = true,
    this.show = true,
    this.bookSort = -1,
    this.onlyUpdateRead = false,
  });

  static const int idRoot = -100;
  static const int idAll = -1;
  static const int idLocal = -2;
  static const int idAudio = -3;
  static const int idNetNone = -4;
  static const int idLocalNone = -5;
  static const int idVideo = -6;
  static const int idError = -11;
  static const int idImage = -7;

  int groupId;
  String groupName;
  String? cover;
  int order;
  bool enableRefresh;
  bool show;
  int bookSort;
  bool onlyUpdateRead;

  factory BookGroup.fromJson(Map<String, dynamic> json) {
    return BookGroup(
      groupId: JsonKit.intOf(json['groupId']),
      groupName: JsonKit.stringOr(json['groupName']),
      cover: JsonKit.string(json['cover']),
      order: JsonKit.intOf(json['order']),
      enableRefresh: JsonKit.boolOf(json['enableRefresh'], true),
      show: JsonKit.boolOf(json['show'], true),
      bookSort: JsonKit.intOf(json['bookSort'], -1),
      onlyUpdateRead: JsonKit.boolOf(json['onlyUpdateRead']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'groupId': groupId,
    'groupName': groupName,
    'cover': cover,
    'order': order,
    'enableRefresh': enableRefresh,
    'show': show,
    'bookSort': bookSort,
    'onlyUpdateRead': onlyUpdateRead,
  });
}

class SearchKeyword {
  SearchKeyword({
    required this.word,
    this.usage = 1,
    this.lastUseTime,
  });

  String word;
  int usage;
  int? lastUseTime;

  factory SearchKeyword.fromJson(Map<String, dynamic> json) {
    return SearchKeyword(
      word: JsonKit.stringOr(json['word']),
      usage: JsonKit.intOf(json['usage'], 1),
      lastUseTime: JsonKit.intOrNull(json['lastUseTime']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'word': word,
    'usage': usage,
    'lastUseTime': lastUseTime,
  });
}

class CookieRecord {
  CookieRecord({required this.url, this.cookie = ''});

  String url;
  String cookie;

  factory CookieRecord.fromJson(Map<String, dynamic> json) {
    return CookieRecord(
      url: JsonKit.stringOr(json['url']),
      cookie: JsonKit.stringOr(json['cookie']),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'cookie': cookie};
}

class CacheRecord {
  CacheRecord({required this.key, this.value, this.deadline = 0});

  String key;
  String? value;
  int deadline;

  factory CacheRecord.fromJson(Map<String, dynamic> json) {
    return CacheRecord(
      key: JsonKit.stringOr(json['key']),
      value: JsonKit.string(json['value']),
      deadline: JsonKit.intOf(json['deadline']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'key': key,
    'value': value,
    'deadline': deadline,
  });
}

class ReadRecord {
  ReadRecord({
    required this.deviceId,
    required this.bookName,
    this.readTime = 0,
    this.lastRead,
  });

  String deviceId;
  String bookName;
  int readTime;
  int? lastRead;

  factory ReadRecord.fromJson(Map<String, dynamic> json) {
    return ReadRecord(
      deviceId: JsonKit.stringOr(json['deviceId']),
      bookName: JsonKit.stringOr(json['bookName']),
      readTime: JsonKit.intOf(json['readTime']),
      lastRead: JsonKit.intOrNull(json['lastRead']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'deviceId': deviceId,
    'bookName': bookName,
    'readTime': readTime,
    'lastRead': lastRead,
  });
}
