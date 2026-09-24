/// 订阅源发现分类列表解析。
///
/// 对应 legado `RssSourceExtensions.sortUrls()`（help/source/RssSourceExtensions.kt）：
///
/// ```kotlin
/// str?.split("(&&|\n)+".toRegex())?.forEach { sort ->
///     val name = sort.substringBefore("::")
///     val url  = sort.substringAfter("::", "")
///     if (url.isNotEmpty()) add(Pair(name, url))
/// }
/// if (isEmpty()) add(Pair("", sourceUrl))
/// ```
///
/// 即：分类列表按 `&&` 或换行分条；每条 `名称::url` 拆出名称与 url，
/// 仅当 url 非空才保留；无分类时调用方回退到 sourceUrl。
///
/// 说明：legado 的 `sortUrl` 还支持 `<js>` / `@js:` 前缀的动态脚本求值，
/// 这里只做静态解析（小步实现，不引入规则引擎），脚本类源直接回退为空、
/// 由发现页按 sourceUrl 加载全部文章。
class RssSortUrl {
  const RssSortUrl(this.name, this.url);

  final String name;
  final String url;

  @override
  String toString() => '$name::$url';
}

/// 解析 `RssSource.sortUrl` 为发现分类列表。
///
/// - 空字符串 / `null`：返回空列表（调用方按 sourceUrl 加载全部）。
/// - `<js>` / `@js:` 前缀（动态脚本）：当前不支持，返回空列表。
/// - 其余：按 `(&&|\n)+` 切分后逐条取 `名称::url`。
List<RssSortUrl> parseSortUrls(String? sortUrl) {
  final str = sortUrl?.trim();
  if (str == null || str.isEmpty) return const [];
  if (str.startsWith('<js>') || str.startsWith('@js:')) return const [];

  final out = <RssSortUrl>[];
  for (final part in str.split(RegExp(r'(&&|\n)+'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final idx = p.indexOf('::');
    final name = idx < 0 ? p : p.substring(0, idx).trim();
    final url = idx < 0 ? '' : p.substring(idx + 2).trim();
    if (url.isNotEmpty) out.add(RssSortUrl(name, url));
  }
  return out;
}
