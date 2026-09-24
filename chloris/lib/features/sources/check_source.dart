import 'package:chloris_engine/chloris_engine.dart';

/// legado CheckSource 搜索式批量校验的对齐实现。
///
/// legado 的 [CheckSourceService.doCheckSource] 不只是探活，而是用
/// `source.getCheckKeyword(默认词)` 真实搜索一次，按「是否返回结果」判定源是否可用：
///   - 搜索返回非空 → 源健康（legado 移除「搜索失效」分组）；
///   - 搜索返回空   → 「搜索失效」（规则失效，但域名可达）；
///   - 域名不可达   → 「网站失效」/「域名失效」。
///
/// 本文件只放与 legado 一一对应的纯逻辑与常量，供 [BulkSourceValidator] 复用。

/// 对齐 legado `CheckSource.keyword = "我的"`，作为 [BookSource.getCheckKeyword] 的兜底词。
const String kDefaultCheckKeyword = '我的';

/// 搜索式校验探针：对单个源用关键词真实搜索一次并返回结果列表。
///
/// 引擎侧由 `searchOnlineBooksUseCaseProvider` 的 [SearchOnlineBooksUseCase] 提供实现；
/// 测试时注入假实现即可纯 Dart 实跑。
typedef SearchProbe = Future<List<SearchBook>> Function(
  BookSource source,
  String keyword,
);

/// 搜索式校验的分级结果（与 [SourceValidationStatus] 解耦，避免循环依赖）。
enum SearchCheckLevel {
  healthy,
  degraded,
  failed,
}

/// 两级校验的分级判定，对齐 legado `CheckSourceService.doCheckSource`：
///
/// - [reachable] 为探活是否通过（HEAD / 域名可达）；不通则整源 [failed]。
/// - [searched] 为源是否配置了可搜索的 `searchUrl`；缺失则对齐 legado
///   「搜索链接规则为空」分组，记为 [degraded]。
/// - [resultCount] 为搜索返回的有效结果数；非空计 [healthy]，空计 [degraded]。
SearchCheckLevel classifySearchResult({
  required bool reachable,
  required bool searched,
  required int resultCount,
}) {
  if (!reachable) return SearchCheckLevel.failed;
  if (!searched) return SearchCheckLevel.degraded;
  return resultCount > 0 ? SearchCheckLevel.healthy : SearchCheckLevel.degraded;
}
