import '../constants/constants.dart';
import '../json/json_kit.dart';

class FlexChildStyle {
  const FlexChildStyle({
    this.layoutFlexGrow = 0,
    this.layoutFlexShrink = 1,
    this.layoutAlignSelf = 'auto',
    this.layoutFlexBasisPercent = -1,
    this.layoutWrapBefore = false,
    this.layoutJustifySelf = 'auto',
  });

  final double layoutFlexGrow;
  final double layoutFlexShrink;
  final String layoutAlignSelf;
  final double layoutFlexBasisPercent;
  final bool layoutWrapBefore;
  final String layoutJustifySelf;

  static const FlexChildStyle defaultStyle = FlexChildStyle();

  factory FlexChildStyle.fromJson(Map<String, dynamic> json) {
    return FlexChildStyle(
      layoutFlexGrow: JsonKit.doubleOf(json['layout_flexGrow']),
      layoutFlexShrink: JsonKit.doubleOf(json['layout_flexShrink'], 1),
      layoutAlignSelf: JsonKit.stringOr(json['layout_alignSelf'], 'auto'),
      layoutFlexBasisPercent: JsonKit.doubleOf(
        json['layout_flexBasisPercent'],
        -1,
      ),
      layoutWrapBefore: JsonKit.boolOf(json['layout_wrapBefore']),
      layoutJustifySelf: JsonKit.stringOr(json['layout_justifySelf'], 'auto'),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'layout_flexGrow': layoutFlexGrow,
    'layout_flexShrink': layoutFlexShrink,
    'layout_alignSelf': layoutAlignSelf,
    'layout_flexBasisPercent': layoutFlexBasisPercent,
    'layout_wrapBefore': layoutWrapBefore,
    'layout_justifySelf': layoutJustifySelf,
  });
}

class RowUi {
  const RowUi({
    this.name = '',
    this.type = 'text',
    this.action,
    this.chars,
    this.defaultValue,
    this.viewName,
    this.style,
  });

  final String name;
  final String type;
  final String? action;
  final List<String?>? chars;
  final String? defaultValue;
  final String? viewName;
  final FlexChildStyle? style;

  factory RowUi.fromJson(Map<String, dynamic> json) {
    final charsRaw = json['chars'];
    return RowUi(
      name: JsonKit.stringOr(json['name']),
      type: JsonKit.stringOr(json['type'], 'text'),
      action: JsonKit.string(json['action']),
      chars: charsRaw is List
          ? charsRaw.map((e) => e?.toString()).toList()
          : null,
      defaultValue: JsonKit.string(json['default']),
      viewName: JsonKit.string(json['viewName']),
      style: JsonKit.object(json['style'], FlexChildStyle.fromJson),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'name': name,
    'type': type,
    'action': action,
    'chars': chars,
    'default': defaultValue,
    'viewName': viewName,
    'style': style?.toJson(),
  });
}

class ExploreKind {
  const ExploreKind({
    this.title = '',
    this.url,
    this.type = 'url',
    this.action,
    this.chars,
    this.defaultValue,
    this.viewName,
    this.style,
  });

  final String title;
  final String? url;
  final String type;
  final String? action;
  final List<String?>? chars;
  final String? defaultValue;
  final String? viewName;
  final FlexChildStyle? style;

  factory ExploreKind.fromJson(Map<String, dynamic> json) {
    final charsRaw = json['chars'];
    return ExploreKind(
      title: JsonKit.stringOr(json['title'] ?? json['name']),
      url: JsonKit.string(json['url'] ?? json['href']),
      type: JsonKit.stringOr(json['type'], 'url'),
      action: JsonKit.string(json['action']),
      chars: charsRaw is List
          ? charsRaw.map((e) => e?.toString()).toList()
          : null,
      defaultValue: JsonKit.string(json['default']),
      viewName: JsonKit.string(json['viewName']),
      style: JsonKit.object(json['style'], FlexChildStyle.fromJson),
    );
  }

  bool get isDecorative {
    final t = title.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^[\s\-_=.*~—─━•·\*]+$').hasMatch(t)) return true;
    final u = (url ?? '').trim();
    if (u.isEmpty) return true;
    return false;
  }

  bool get isHttp {
    final u = (url ?? '').trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  /// Parse legado `exploreUrl`: JSON array, `title::url` lines, or a single URL.
  static List<ExploreKind> parse(String? raw) {
    if (raw == null) return [];
    final s = raw.trim();
    if (s.isEmpty) return [];

    List<ExploreKind> fromList(List<dynamic> items) {
      final out = <ExploreKind>[];
      for (final e in items) {
        final map = JsonKit.map(e);
        if (map != null) {
          out.add(ExploreKind.fromJson(map));
          continue;
        }
        if (e is List && e.isNotEmpty) {
          out.add(
            ExploreKind(
              title: '${e.first ?? ''}'.trim(),
              url: e.length > 1 ? e[1]?.toString() : null,
            ),
          );
          continue;
        }
        if (e is String && e.contains('::')) {
          final i = e.indexOf('::');
          out.add(
            ExploreKind(
              title: e.substring(0, i).trim(),
              url: e.substring(i + 2).trim(),
            ),
          );
        }
      }
      return out.where((k) => !k.isDecorative).toList();
    }

    List<ExploreKind> tryJson(String text) {
      final asList = JsonKit.list(text);
      if (asList != null && asList.isNotEmpty) return fromList(asList);
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final nested = JsonKit.list(text.substring(start, end + 1));
        if (nested != null && nested.isNotEmpty) return fromList(nested);
      }
      return const [];
    }

    final direct = tryJson(s);
    if (direct.isNotEmpty) return direct;

    final js = AppPattern.js.firstMatch(s);
    if (js != null) {
      final inner = (js.group(1) ?? js.group(2) ?? '').trim();
      if (inner.isNotEmpty) {
        final fromJs = tryJson(inner);
        if (fromJs.isNotEmpty) return fromJs;
      }
    }

    if (s.contains('::')) {
      return [
        for (final line in s.split(RegExp(r'(?:&&|\r?\n)+')))
          if (line.contains('::'))
            ExploreKind(
              title: line.substring(0, line.indexOf('::')).trim(),
              url: line.substring(line.indexOf('::') + 2).trim(),
            ),
      ].where((k) => !k.isDecorative).toList();
    }
    if (s.toLowerCase().startsWith('http')) {
      return [ExploreKind(title: '发现', url: s)];
    }
    return [];
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'title': title,
    'url': url,
    'type': type,
    'action': action,
    'chars': chars,
    'default': defaultValue,
    'viewName': viewName,
    'style': style?.toJson(),
  });
}

class SearchRule {
  SearchRule({
    this.checkKeyWord,
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  String? checkKeyWord;
  String? bookList;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? bookUrl;
  String? coverUrl;
  String? wordCount;

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      checkKeyWord: JsonKit.string(json['checkKeyWord']),
      bookList: JsonKit.string(json['bookList']),
      name: JsonKit.string(json['name']),
      author: JsonKit.string(json['author']),
      intro: JsonKit.string(json['intro']),
      kind: JsonKit.string(json['kind']),
      lastChapter: JsonKit.string(json['lastChapter']),
      updateTime: JsonKit.string(json['updateTime']),
      bookUrl: JsonKit.string(json['bookUrl']),
      coverUrl: JsonKit.string(json['coverUrl']),
      wordCount: JsonKit.string(json['wordCount']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'checkKeyWord': checkKeyWord,
    'bookList': bookList,
    'name': name,
    'author': author,
    'intro': intro,
    'kind': kind,
    'lastChapter': lastChapter,
    'updateTime': updateTime,
    'bookUrl': bookUrl,
    'coverUrl': coverUrl,
    'wordCount': wordCount,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchRule &&
      other.checkKeyWord == checkKeyWord &&
      other.bookList == bookList &&
      other.name == name &&
      other.author == author &&
      other.intro == intro &&
      other.kind == kind &&
      other.lastChapter == lastChapter &&
      other.updateTime == updateTime &&
      other.bookUrl == bookUrl &&
      other.coverUrl == coverUrl &&
      other.wordCount == wordCount;

  @override
  int get hashCode => Object.hash(
    checkKeyWord,
    bookList,
    name,
    author,
    intro,
    kind,
    lastChapter,
    updateTime,
    bookUrl,
    coverUrl,
    wordCount,
  );
}

class ExploreRule {
  ExploreRule({
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  String? bookList;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? bookUrl;
  String? coverUrl;
  String? wordCount;

  factory ExploreRule.fromJson(Map<String, dynamic> json) {
    return ExploreRule(
      bookList: JsonKit.string(json['bookList']),
      name: JsonKit.string(json['name']),
      author: JsonKit.string(json['author']),
      intro: JsonKit.string(json['intro']),
      kind: JsonKit.string(json['kind']),
      lastChapter: JsonKit.string(json['lastChapter']),
      updateTime: JsonKit.string(json['updateTime']),
      bookUrl: JsonKit.string(json['bookUrl']),
      coverUrl: JsonKit.string(json['coverUrl']),
      wordCount: JsonKit.string(json['wordCount']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'bookList': bookList,
    'name': name,
    'author': author,
    'intro': intro,
    'kind': kind,
    'lastChapter': lastChapter,
    'updateTime': updateTime,
    'bookUrl': bookUrl,
    'coverUrl': coverUrl,
    'wordCount': wordCount,
  });
}

class BookInfoRule {
  BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
    this.canReName,
    this.downloadUrls,
  });

  String? init;
  String? name;
  String? author;
  String? intro;
  String? kind;
  String? lastChapter;
  String? updateTime;
  String? coverUrl;
  String? tocUrl;
  String? wordCount;
  String? canReName;
  String? downloadUrls;

  factory BookInfoRule.fromJson(Map<String, dynamic> json) {
    return BookInfoRule(
      init: JsonKit.string(json['init']),
      name: JsonKit.string(json['name']),
      author: JsonKit.string(json['author']),
      intro: JsonKit.string(json['intro']),
      kind: JsonKit.string(json['kind']),
      lastChapter: JsonKit.string(json['lastChapter']),
      updateTime: JsonKit.string(json['updateTime']),
      coverUrl: JsonKit.string(json['coverUrl']),
      tocUrl: JsonKit.string(json['tocUrl']),
      wordCount: JsonKit.string(json['wordCount']),
      canReName: JsonKit.string(json['canReName']),
      downloadUrls: JsonKit.string(json['downloadUrls']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'init': init,
    'name': name,
    'author': author,
    'intro': intro,
    'kind': kind,
    'lastChapter': lastChapter,
    'updateTime': updateTime,
    'coverUrl': coverUrl,
    'tocUrl': tocUrl,
    'wordCount': wordCount,
    'canReName': canReName,
    'downloadUrls': downloadUrls,
  });
}

class TocRule {
  TocRule({
    this.preUpdateJs,
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.formatJs,
    this.isVolume,
    this.isVip,
    this.isPay,
    this.updateTime,
    this.nextTocUrl,
  });

  String? preUpdateJs;
  String? chapterList;
  String? chapterName;
  String? chapterUrl;
  String? formatJs;
  String? isVolume;
  String? isVip;
  String? isPay;
  String? updateTime;
  String? nextTocUrl;

  factory TocRule.fromJson(Map<String, dynamic> json) {
    return TocRule(
      preUpdateJs: JsonKit.string(json['preUpdateJs']),
      chapterList: JsonKit.string(json['chapterList']),
      chapterName: JsonKit.string(json['chapterName']),
      chapterUrl: JsonKit.string(json['chapterUrl']),
      formatJs: JsonKit.string(json['formatJs']),
      isVolume: JsonKit.string(json['isVolume']),
      isVip: JsonKit.string(json['isVip']),
      isPay: JsonKit.string(json['isPay']),
      updateTime: JsonKit.string(json['updateTime']),
      nextTocUrl: JsonKit.string(json['nextTocUrl']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'preUpdateJs': preUpdateJs,
    'chapterList': chapterList,
    'chapterName': chapterName,
    'chapterUrl': chapterUrl,
    'formatJs': formatJs,
    'isVolume': isVolume,
    'isVip': isVip,
    'isPay': isPay,
    'updateTime': updateTime,
    'nextTocUrl': nextTocUrl,
  });
}

class ContentRule {
  ContentRule({
    this.content,
    this.subContent,
    this.title,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.imageDecode,
    this.payAction,
    this.callBackJs,
  });

  String? content;
  String? subContent;
  String? title;
  String? nextContentUrl;
  String? webJs;
  String? sourceRegex;
  String? replaceRegex;
  String? imageStyle;
  String? imageDecode;
  String? payAction;
  String? callBackJs;

  factory ContentRule.fromJson(Map<String, dynamic> json) {
    return ContentRule(
      content: JsonKit.string(json['content']),
      subContent: JsonKit.string(json['subContent']),
      title: JsonKit.string(json['title']),
      nextContentUrl: JsonKit.string(json['nextContentUrl']),
      webJs: JsonKit.string(json['webJs']),
      sourceRegex: JsonKit.string(json['sourceRegex']),
      replaceRegex: JsonKit.string(json['replaceRegex']),
      imageStyle: JsonKit.string(json['imageStyle']),
      imageDecode: JsonKit.string(json['imageDecode']),
      payAction: JsonKit.string(json['payAction']),
      callBackJs: JsonKit.string(json['callBackJs']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'content': content,
    'subContent': subContent,
    'title': title,
    'nextContentUrl': nextContentUrl,
    'webJs': webJs,
    'sourceRegex': sourceRegex,
    'replaceRegex': replaceRegex,
    'imageStyle': imageStyle,
    'imageDecode': imageDecode,
    'payAction': payAction,
    'callBackJs': callBackJs,
  });
}

class ReviewRule {
  ReviewRule({
    this.reviewUrl,
    this.avatarRule,
    this.contentRule,
    this.postTimeRule,
    this.reviewQuoteUrl,
    this.voteUpUrl,
    this.voteDownUrl,
    this.postReviewUrl,
    this.postQuoteUrl,
    this.deleteUrl,
  });

  String? reviewUrl;
  String? avatarRule;
  String? contentRule;
  String? postTimeRule;
  String? reviewQuoteUrl;
  String? voteUpUrl;
  String? voteDownUrl;
  String? postReviewUrl;
  String? postQuoteUrl;
  String? deleteUrl;

  factory ReviewRule.fromJson(Map<String, dynamic> json) {
    return ReviewRule(
      reviewUrl: JsonKit.string(json['reviewUrl']),
      avatarRule: JsonKit.string(json['avatarRule']),
      contentRule: JsonKit.string(json['contentRule']),
      postTimeRule: JsonKit.string(json['postTimeRule']),
      reviewQuoteUrl: JsonKit.string(json['reviewQuoteUrl']),
      voteUpUrl: JsonKit.string(json['voteUpUrl']),
      voteDownUrl: JsonKit.string(json['voteDownUrl']),
      postReviewUrl: JsonKit.string(json['postReviewUrl']),
      postQuoteUrl: JsonKit.string(json['postQuoteUrl']),
      deleteUrl: JsonKit.string(json['deleteUrl']),
    );
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'reviewUrl': reviewUrl,
    'avatarRule': avatarRule,
    'contentRule': contentRule,
    'postTimeRule': postTimeRule,
    'reviewQuoteUrl': reviewQuoteUrl,
    'voteUpUrl': voteUpUrl,
    'voteDownUrl': voteDownUrl,
    'postReviewUrl': postReviewUrl,
    'postQuoteUrl': postQuoteUrl,
    'deleteUrl': deleteUrl,
  });
}
