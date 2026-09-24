import 'package:chloris_engine/chloris_engine.dart';

import 'rss_sort_url.dart';
export 'rss_sort_url.dart';

/// 订阅源（对应 legado `RssSource`，44 列）。
///
/// 导入一条 Legado 订阅源时，未知字段不会丢：它们进入 [extra]，导出时原样写回。
/// 之前只序列化 22 个字段，`loginUi` / `header` / `jsLib` / 白黑名单等会在
/// “导入即静默消失”，用户看不出任何异常。
class RssSource {
  RssSource({
    required this.sourceUrl,
    this.sourceName = '',
    this.sourceGroup,
    this.sourceIcon,
    this.sourceComment,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledCookieJar = true,
    this.enableJs = false,
    this.singleUrl = true,
    this.loadWithBaseUrl = false,
    this.articleStyle = 0,
    this.lastUpdateTime = 0,
    this.ruleArticles,
    this.ruleTitle,
    this.rulePubDate,
    this.ruleDescription,
    this.ruleContent,
    this.ruleImage,
    this.ruleLink,
    this.ruleNextPage,
    this.variableComment,
    this.jsLib,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.sortUrl,
    this.contentWhitelist,
    this.contentBlacklist,
    this.style,
    this.injectJs,
    this.preloadJs,
    this.startHtml,
    this.startStyle,
    this.startJs,
    this.type = 0,
    this.showWebLog = 0,
    this.preload = 0,
    this.cacheFirst = 0,
    this.searchUrl,
    this.shouldOverrideUrlLoading,
    Map<String, dynamic> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  final String sourceUrl;
  final String sourceName;
  final String? sourceGroup;
  final String? sourceIcon;
  final String? sourceComment;
  final int customOrder;
  final bool enabled;
  final bool enabledCookieJar;
  final bool enableJs;
  final bool singleUrl;
  final bool loadWithBaseUrl;
  final int articleStyle;
  final int lastUpdateTime;

  /// Legado custom RSS rules. A leading '-' reverses article order.
  final String? ruleArticles;
  final String? ruleTitle;
  final String? rulePubDate;
  final String? ruleDescription;

  /// Optional article HTML/content rule used by custom Legado RSS sources.
  final String? ruleContent;
  final String? ruleImage;
  final String? ruleLink;
  final String? ruleNextPage;

  // ---- Fields Legado stores but an earlier revision dropped on import ----
  final String? variableComment;
  final String? jsLib;
  final String? concurrentRate;
  final String? header;
  final String? loginUrl;
  final String? loginUi;
  final String? loginCheckJs;
  final String? coverDecodeJs;
  final String? sortUrl;
  final String? contentWhitelist;
  final String? contentBlacklist;
  final String? style;
  final String? injectJs;
  final String? preloadJs;
  final String? startHtml;
  final String? startStyle;
  final String? startJs;
  final int type;
  final int showWebLog;
  final int preload;
  final int cacheFirst;
  final String? searchUrl;
  final bool? shouldOverrideUrlLoading;

  /// Keys this build does not model, preserved verbatim so that a round trip
  /// through Chloris never silently loses a newer Legado field.
  final Map<String, dynamic> extra;

  static const _known = {
    'sourceUrl',
    'sourceName',
    'sourceGroup',
    'sourceIcon',
    'sourceComment',
    'customOrder',
    'enabled',
    'enabledCookieJar',
    'enableJs',
    'singleUrl',
    'loadWithBaseUrl',
    'articleStyle',
    'lastUpdateTime',
    'ruleArticles',
    'ruleTitle',
    'rulePubDate',
    'ruleDescription',
    'ruleContent',
    'ruleImage',
    'ruleLink',
    'ruleNextPage',
    'variableComment',
    'jsLib',
    'concurrentRate',
    'header',
    'loginUrl',
    'loginUi',
    'loginCheckJs',
    'coverDecodeJs',
    'sortUrl',
    'contentWhitelist',
    'contentBlacklist',
    'style',
    'injectJs',
    'preloadJs',
    'startHtml',
    'startStyle',
    'startJs',
    'type',
    'showWebLog',
    'preload',
    'cacheFirst',
    'searchUrl',
    'shouldOverrideUrlLoading',
  };

  factory RssSource.fromJson(Map<String, dynamic> json) => RssSource(
    sourceUrl: JsonKit.stringOr(json['sourceUrl']),
    sourceName: JsonKit.stringOr(json['sourceName']),
    sourceGroup: json['sourceGroup']?.toString(),
    sourceIcon: json['sourceIcon']?.toString(),
    sourceComment: json['sourceComment']?.toString(),
    customOrder: JsonKit.intOf(json['customOrder']),
    enabled: JsonKit.boolOf(json['enabled'], true),
    enabledCookieJar: JsonKit.boolOf(json['enabledCookieJar'], true),
    enableJs: JsonKit.boolOf(json['enableJs']),
    singleUrl: JsonKit.boolOf(json['singleUrl'], true),
    loadWithBaseUrl: JsonKit.boolOf(json['loadWithBaseUrl']),
    articleStyle: JsonKit.intOf(json['articleStyle']),
    lastUpdateTime: JsonKit.intOf(json['lastUpdateTime']),
    ruleArticles: json['ruleArticles']?.toString(),
    ruleTitle: json['ruleTitle']?.toString(),
    rulePubDate: json['rulePubDate']?.toString(),
    ruleDescription: json['ruleDescription']?.toString(),
    ruleContent: json['ruleContent']?.toString(),
    ruleImage: json['ruleImage']?.toString(),
    ruleLink: json['ruleLink']?.toString(),
    ruleNextPage: json['ruleNextPage']?.toString(),
    variableComment: json['variableComment']?.toString(),
    jsLib: json['jsLib']?.toString(),
    concurrentRate: json['concurrentRate']?.toString(),
    header: json['header']?.toString(),
    loginUrl: json['loginUrl']?.toString(),
    loginUi: json['loginUi']?.toString(),
    loginCheckJs: json['loginCheckJs']?.toString(),
    coverDecodeJs: json['coverDecodeJs']?.toString(),
    sortUrl: json['sortUrl']?.toString(),
    contentWhitelist: json['contentWhitelist']?.toString(),
    contentBlacklist: json['contentBlacklist']?.toString(),
    style: json['style']?.toString(),
    injectJs: json['injectJs']?.toString(),
    preloadJs: json['preloadJs']?.toString(),
    startHtml: json['startHtml']?.toString(),
    startStyle: json['startStyle']?.toString(),
    startJs: json['startJs']?.toString(),
    type: JsonKit.intOf(json['type']),
    showWebLog: JsonKit.intOf(json['showWebLog']),
    preload: JsonKit.intOf(json['preload']),
    cacheFirst: JsonKit.intOf(json['cacheFirst']),
    searchUrl: json['searchUrl']?.toString(),
    shouldOverrideUrlLoading: json.containsKey('shouldOverrideUrlLoading')
        ? JsonKit.boolOf(json['shouldOverrideUrlLoading'])
        : null,
    extra: {
      for (final e in json.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    },
  );

  Map<String, dynamic> toJson() => {
    // Unknown-but-preserved keys go first so a modelled field always wins.
    ...extra,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'sourceGroup': sourceGroup,
    'sourceIcon': sourceIcon,
    'sourceComment': sourceComment,
    'customOrder': customOrder,
    'enabled': enabled,
    'enabledCookieJar': enabledCookieJar,
    'enableJs': enableJs,
    'singleUrl': singleUrl,
    'loadWithBaseUrl': loadWithBaseUrl,
    'articleStyle': articleStyle,
    'lastUpdateTime': lastUpdateTime,
    'ruleArticles': ruleArticles,
    'ruleTitle': ruleTitle,
    'rulePubDate': rulePubDate,
    'ruleDescription': ruleDescription,
    'ruleContent': ruleContent,
    'ruleImage': ruleImage,
    'ruleLink': ruleLink,
    'ruleNextPage': ruleNextPage,
    'variableComment': variableComment,
    'jsLib': jsLib,
    'concurrentRate': concurrentRate,
    'header': header,
    'loginUrl': loginUrl,
    'loginUi': loginUi,
    'loginCheckJs': loginCheckJs,
    'coverDecodeJs': coverDecodeJs,
    'sortUrl': sortUrl,
    'contentWhitelist': contentWhitelist,
    'contentBlacklist': contentBlacklist,
    'style': style,
    'injectJs': injectJs,
    'preloadJs': preloadJs,
    'startHtml': startHtml,
    'startStyle': startStyle,
    'startJs': startJs,
    'type': type,
    'showWebLog': showWebLog,
    'preload': preload,
    'cacheFirst': cacheFirst,
    'searchUrl': searchUrl,
    'shouldOverrideUrlLoading': shouldOverrideUrlLoading,
  };

  /// 解析发现分类列表（legado `sortUrl`）。
  ///
  /// 返回空时调用方应回退到 [sourceUrl] 加载全部文章。
  List<RssSortUrl> sortUrls() => parseSortUrls(sortUrl);

  static List<RssSource> listFromJson(dynamic raw) {
    final items = JsonKit.list(raw) ?? (raw is Map ? [raw] : const []);
    return items
        .map((e) => JsonKit.map(e))
        .whereType<Map<String, dynamic>>()
        .map(RssSource.fromJson)
        .where((s) => s.sourceUrl.isNotEmpty)
        .toList();
  }
}

/// 订阅文章（对应 legado `rssArticles`，14 列）。
///
/// 之前只保留 8 个字段，`read` / `durPos` / `sort` / `group` / `type` 全部丢失，
/// 于是“已读状态”和“阅读进度”在重启后必然回退。
class RssArticle {
  RssArticle({
    required this.title,
    this.link = '',
    this.author = '',
    this.pubDate = '',
    this.description = '',
    this.content = '',
    this.sourceName = '',
    this.image = '',
    this.sort = '',
    this.group = '默认分组',
    this.read = false,
    this.durPos = 0,
    this.type = 0,
    this.order = 0,
    this.variable,
    Map<String, dynamic> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  final String title;
  final String link;
  final String author;
  final String pubDate;
  final String description;
  final String content;
  final String sourceName;
  final String image;
  final String sort;
  final String group;
  final bool read;
  final int durPos;
  final int type;
  final int order;
  final String? variable;
  final Map<String, dynamic> extra;

  static const _known = {
    'title',
    'link',
    'author',
    'pubDate',
    'description',
    'content',
    'sourceName',
    'image',
    'sort',
    'group',
    'read',
    'durPos',
    'type',
    'order',
    'variable',
  };

  factory RssArticle.fromJson(Map<String, dynamic> json) => RssArticle(
    title: json['title']?.toString() ?? '',
    link: json['link']?.toString() ?? '',
    author: json['author']?.toString() ?? '',
    pubDate: json['pubDate']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    sourceName: json['sourceName']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    sort: json['sort']?.toString() ?? '',
    group: json['group']?.toString() ?? '默认分组',
    read: JsonKit.boolOf(json['read']),
    durPos: JsonKit.intOf(json['durPos']),
    type: JsonKit.intOf(json['type']),
    order: JsonKit.intOf(json['order']),
    variable: json['variable']?.toString(),
    extra: {
      for (final e in json.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    },
  );

  Map<String, dynamic> toJson() => {
    ...extra,
    'title': title,
    'link': link,
    'author': author,
    'pubDate': pubDate,
    'description': description,
    'content': content,
    'sourceName': sourceName,
    'image': image,
    'sort': sort,
    'group': group,
    'read': read,
    'durPos': durPos,
    'type': type,
    'order': order,
    'variable': variable,
  };

  RssArticle copyWith({bool? read, int? durPos}) => RssArticle(
    title: title,
    link: link,
    author: author,
    pubDate: pubDate,
    description: description,
    content: content,
    sourceName: sourceName,
    image: image,
    sort: sort,
    group: group,
    read: read ?? this.read,
    durPos: durPos ?? this.durPos,
    type: type,
    order: order,
    variable: variable,
    extra: extra,
  );
}
