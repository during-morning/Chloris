import '../constants/constants.dart';
import '../debug/debug_log.dart';
import '../json/json_kit.dart';
import '../net/kv_port.dart';
import 'rules.dart';

/// Mirrors `io.legado.app.data.entities.BookSource`.
class BookSource {
  BookSource({
    required this.bookSourceUrl,
    this.bookSourceName = '',
    this.bookSourceGroup,
    this.bookSourceType = BookSourceType.text,
    this.bookUrlPattern,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.exploreUrl,
    this.exploreScreen,
    this.ruleExplore,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleReview,
    this.eventListener = false,
    this.customButton = false,
  });

  /// App 级默认变量持久层：宿主启动时挂一次，此后**所有** BookSource 实例
  /// （`fromJson`、手动构造、copyWith 不走此路径）自动获得持久化的
  /// `java.put`/`java.get` 变量，重启后仍在 —— 对齐 Legado-E 的
  /// `CacheManager` Room 兜底。引擎/单测不挂即可保持纯内存行为。
  static KvPort? defaultVarStore;

  String bookSourceUrl;
  String bookSourceName;
  String? bookSourceGroup;
  int bookSourceType;
  String? bookUrlPattern;
  int customOrder;
  bool enabled;
  bool enabledExplore;
  String? jsLib;
  bool? enabledCookieJar;
  String? concurrentRate;
  String? header;
  String? loginUrl;
  String? loginUi;
  String? loginCheckJs;
  String? coverDecodeJs;
  String? bookSourceComment;
  String? variableComment;
  int lastUpdateTime;
  int respondTime;
  int weight;
  String? exploreUrl;
  String? exploreScreen;
  ExploreRule? ruleExplore;
  String? searchUrl;
  SearchRule? ruleSearch;
  BookInfoRule? ruleBookInfo;
  TocRule? ruleToc;
  ContentRule? ruleContent;
  ReviewRule? ruleReview;
  bool eventListener;
  bool customButton;

  /// In-memory `java.put` / `java.get` bag for this source (not serialized).
  ///
  /// 这是**内存层**。对齐 Legado-E：那边 `java.get` 是
  /// `CacheManager.get("v_${key}_${k}") ?: ""`（`BaseSource.kt:275-286`），
  /// 走的是带 Room 兜底的缓存，**重启后仍在**。要让 Chloris 具备同样行为，
  /// 给 [varStore] 挂一个持久实现即可；没挂时只有内存层。
  final Map<String, String> runtimeVars = {};

  /// 源级变量的持久层（可选）。为 null 时变量仅存活于本次运行。
  /// 默认取 [defaultVarStore]，调用方仍可逐实例覆盖。
  KvPort? varStore = BookSource.defaultVarStore;

  bool _warnedNoVarStore = false;

  /// Legado 的键格式：`v_<bookSourceUrl>_<key>`。
  static String varKeyFor(String sourceUrl, String key) =>
      'v_${sourceUrl}_$key';

  SearchRule getSearchRule() => ruleSearch ??= SearchRule();

  String put(String key, String value) {
    runtimeVars[key] = value;
    final store = varStore;
    if (store == null) {
      // 「写成功但重启就没了」必须留痕，否则书源作者的登录态缓存会以
      // 「偶尔要重新登录」这种最难查的形式暴露出来。
      if (!_warnedNoVarStore) {
        _warnedNoVarStore = true;
        DebugLog.log(
          'BookSource',
          '未挂载变量持久层（KvPort）：java.put 写入的变量重启后会丢失',
          state: -1,
        );
      }
    } else {
      store.write(varKeyFor(bookSourceUrl, key), value);
    }
    return value;
  }

  String get(String key) {
    final memory = runtimeVars[key];
    if (memory != null) return memory;
    final store = varStore;
    if (store == null) return '';
    final persisted = store.read(varKeyFor(bookSourceUrl, key)) ?? '';
    // 命中后回填内存层，对齐 CacheManager.get 的「从磁盘取到就提升到内存」。
    if (persisted.isNotEmpty) runtimeVars[key] = persisted;
    return persisted;
  }
  ExploreRule getExploreRule() => ruleExplore ??= ExploreRule();
  BookInfoRule getBookInfoRule() => ruleBookInfo ??= BookInfoRule();
  TocRule getTocRule() => ruleToc ??= TocRule();
  ContentRule getContentRule() => ruleContent ??= ContentRule();

  bool get hasExploreUrl => (exploreUrl ?? '').trim().isNotEmpty;

  List<ExploreKind> get exploreKinds => ExploreKind.parse(exploreUrl);
  bool get hasLoginUrl => (loginUrl ?? '').trim().isNotEmpty;
  bool get hasSearch => (searchUrl ?? '').trim().isNotEmpty;
  bool get hasCompleteRules {
    final search = ruleSearch;
    final toc = ruleToc;
    final content = ruleContent;
    return hasSearch &&
        (search?.bookList ?? '').trim().isNotEmpty &&
        (toc?.chapterList ?? '').trim().isNotEmpty &&
        (content?.content ?? '').trim().isNotEmpty;
  }

  /// 校验/调试用的搜索关键词，对齐 legado BookSource.getCheckKeyword
  /// （BookSource.kt:212-220）：checkKeyWord 非空白且不含 http / :: / ++ / -- 时
  /// 优先于默认关键词——这类词通常是给校验器用的固定探针，不是给搜索的。
  String getCheckKeyword(String def) {
    final kw = ruleSearch?.checkKeyWord;
    if (kw != null &&
        kw.trim().isNotEmpty &&
        !kw.contains('http') &&
        !kw.contains('::') &&
        !kw.contains('++') &&
        !kw.contains('--')) {
      return kw;
    }
    return def;
  }

  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      bookSourceUrl: JsonKit.stringOr(json['bookSourceUrl']),
      bookSourceName: JsonKit.stringOr(json['bookSourceName']),
      bookSourceGroup: JsonKit.string(json['bookSourceGroup']),
      bookSourceType: JsonKit.intOf(json['bookSourceType']),
      bookUrlPattern: JsonKit.string(json['bookUrlPattern']),
      customOrder: JsonKit.intOf(json['customOrder']),
      enabled: JsonKit.boolOf(json['enabled'], true),
      enabledExplore: JsonKit.boolOf(json['enabledExplore'], true),
      jsLib: JsonKit.string(json['jsLib']),
      enabledCookieJar: json.containsKey('enabledCookieJar')
          ? JsonKit.boolOf(json['enabledCookieJar'], true)
          : true,
      concurrentRate: JsonKit.string(json['concurrentRate']),
      header: JsonKit.string(json['header']),
      loginUrl: JsonKit.string(json['loginUrl']),
      loginUi: JsonKit.string(json['loginUi']),
      loginCheckJs: JsonKit.string(json['loginCheckJs']),
      coverDecodeJs: JsonKit.string(json['coverDecodeJs']),
      bookSourceComment: JsonKit.string(json['bookSourceComment']),
      variableComment: JsonKit.string(json['variableComment']),
      lastUpdateTime: JsonKit.intOf(json['lastUpdateTime']),
      respondTime: JsonKit.intOf(json['respondTime'], 180000),
      weight: JsonKit.intOf(json['weight']),
      exploreUrl: JsonKit.string(json['exploreUrl']),
      exploreScreen: JsonKit.string(json['exploreScreen']),
      ruleExplore: JsonKit.object(json['ruleExplore'], ExploreRule.fromJson),
      searchUrl: JsonKit.string(json['searchUrl']),
      ruleSearch: JsonKit.object(json['ruleSearch'], SearchRule.fromJson),
      ruleBookInfo: JsonKit.object(json['ruleBookInfo'], BookInfoRule.fromJson),
      ruleToc: JsonKit.object(json['ruleToc'], TocRule.fromJson),
      ruleContent: JsonKit.object(json['ruleContent'], ContentRule.fromJson),
      ruleReview: JsonKit.object(json['ruleReview'], ReviewRule.fromJson),
      eventListener: JsonKit.boolOf(json['eventListener']),
      customButton: JsonKit.boolOf(json['customButton']),
    );
  }

  static List<BookSource> listFromJson(dynamic raw) {
    final items = JsonKit.list(raw) ?? (raw is Map ? [raw] : const []);
    return items
        .map((e) => JsonKit.map(e))
        .whereType<Map<String, dynamic>>()
        .map(BookSource.fromJson)
        .where((s) => s.bookSourceUrl.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() => JsonKit.compact({
    'bookSourceUrl': bookSourceUrl,
    'bookSourceName': bookSourceName,
    'bookSourceGroup': bookSourceGroup,
    'bookSourceType': bookSourceType,
    'bookUrlPattern': bookUrlPattern,
    'customOrder': customOrder,
    'enabled': enabled,
    'enabledExplore': enabledExplore,
    'jsLib': jsLib,
    'enabledCookieJar': enabledCookieJar,
    'concurrentRate': concurrentRate,
    'header': header,
    'loginUrl': loginUrl,
    'loginUi': loginUi,
    'loginCheckJs': loginCheckJs,
    'coverDecodeJs': coverDecodeJs,
    'bookSourceComment': bookSourceComment,
    'variableComment': variableComment,
    'lastUpdateTime': lastUpdateTime,
    'respondTime': respondTime,
    'weight': weight,
    'exploreUrl': exploreUrl,
    'exploreScreen': exploreScreen,
    'ruleExplore': ruleExplore?.toJson(),
    'searchUrl': searchUrl,
    'ruleSearch': ruleSearch?.toJson(),
    'ruleBookInfo': ruleBookInfo?.toJson(),
    'ruleToc': ruleToc?.toJson(),
    'ruleContent': ruleContent?.toJson(),
    'ruleReview': ruleReview?.toJson(),
    'eventListener': eventListener ? true : null,
    'customButton': customButton ? true : null,
  });

  BookSourcePart toPart() => BookSourcePart(
    bookSourceUrl: bookSourceUrl,
    bookSourceName: bookSourceName,
    bookSourceGroup: bookSourceGroup,
    customOrder: customOrder,
    enabled: enabled,
    enabledExplore: enabledExplore,
    hasLoginUrl: hasLoginUrl,
    lastUpdateTime: lastUpdateTime,
    respondTime: respondTime,
    weight: weight,
    hasExploreUrl: hasExploreUrl,
    eventListener: eventListener,
    bookSourceType: bookSourceType,
  );
}

class BookSourcePart {
  BookSourcePart({
    required this.bookSourceUrl,
    this.bookSourceName = '',
    this.bookSourceGroup,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.hasLoginUrl = false,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.hasExploreUrl = false,
    this.eventListener = false,
    this.bookSourceType = BookSourceType.text,
  });

  String bookSourceUrl;
  String bookSourceName;
  String? bookSourceGroup;
  int customOrder;
  bool enabled;
  bool enabledExplore;
  bool hasLoginUrl;
  int lastUpdateTime;
  int respondTime;
  int weight;
  bool hasExploreUrl;
  bool eventListener;
  int bookSourceType;
}
