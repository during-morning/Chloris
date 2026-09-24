/// 导出文件名模板（仿 legado `BookExtensions.getExportFileName` 的 {书名}/{作者} 绑定）。
///
/// legado 默认导出名为 `书名 作者：作者`（见 BookExtensions.kt:322），其完整版用 JS
/// 规则引擎绑定 `name` / `author` / `epubIndex`。这里只做文件名模板（小步实现，
/// 不引入规则引擎）：
///
/// 占位符：
/// - `{书名}`：书名
/// - `{作者}`：作者
/// - `{-作者}`：仅当作者非空时插入 `-作者`，避免作者缺省时留下多余分隔符
///
/// 默认模板 `{书名}{-作者}`。解析后的文件名会做文件系统安全清洗（与
/// `file_manage_screen.dart` 原有逻辑一致：保留字母、数字、中文、`. _ -`）。
const String kDefaultExportFileNameTemplate = '{书名}{-作者}';

/// 把任意字符串清洗为安全的文件名片段。
String sanitizeForFileName(String input) {
  final s = input
      .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .trim();
  return s.isEmpty ? 'book' : s;
}

/// 按模板生成导出文件名（不含扩展名）。
///
/// 清洗顺序：书名、作者各自清洗为安全片段，再代入模板；最后折叠多余的分隔符
/// （连续 `- _ 空格` 合并为一个 `-`，并去掉首尾分隔符），避免缺省作者时留下
/// 难看的文件名。
String applyExportTemplate(String template, String name, String author) {
  final n = sanitizeForFileName(name);
  // 先按原始作者是否为空决定占位符：空作者时 {作者}/{-作者} 直接为空，
  // 避免 sanitizeForFileName 的 'book' 回退值被误当成作者。
  final authorEmpty = author.trim().isEmpty;
  final a = authorEmpty ? '' : sanitizeForFileName(author);
  var s = template
      .replaceAll('{-作者}', a.isEmpty ? '' : '-$a')
      .replaceAll('{作者}', a)
      .replaceAll('{书名}', n);
  s = s
      .replaceAll(RegExp(r'[-_ ]{2,}'), '-')
      .replaceAll(RegExp(r'^[-_ ]+'), '')
      .replaceAll(RegExp(r'[-_ ]+$'), '')
      .trim();
  return s.isEmpty ? n : s;
}
