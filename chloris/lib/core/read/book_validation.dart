/// Checks stable metadata only; network failures do not prove a book invalid.
String? bookIdentityError({required String name, required String url}) {
  if (name.trim().isEmpty) return '书名为空';
  if (const {
    'null',
    'undefined',
    '未知',
    '未知书籍',
    '无标题',
    '暂无数据',
    '暂无书籍',
    '搜索结果',
    '详情页',
    'book',
    'unknown',
    'untitled',
    'no data',
    'no title',
    'not found',
  }.contains(name.trim().toLowerCase()))
    return '书名是占位信息';
  final value = url.trim();
  if (value.isEmpty) return '书籍标识为空';
  final uri = Uri.tryParse(value);
  if (uri == null || value.contains(RegExp(r'[\r\n\x00]'))) return '书籍地址无效';
  if (const {
    'javascript',
    'data',
    'about',
    'mailto',
  }.contains(uri.scheme.toLowerCase()))
    return '不是书籍地址';
  if (const {'http', 'https'}.contains(uri.scheme) && uri.host.isEmpty)
    return '书籍地址缺少主机';
  return null;
}
