// 纯 Dart 实跑：验证导出文件名模板（{书名}/{作者} 占位符，默认 {书名}{-作者}）。
// 运行：dart run test/rss_export/export_filename_test.dart
import '../../lib/services/export_filename.dart';

int _failures = 0;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    print('  ✓ $name');
  } else {
    _failures++;
    print('  ✗ $name ${detail.isNotEmpty ? '-> $detail' : ''}');
  }
}

void main() {
  print('导出文件名模板测试');

  // 1. 默认模板 {书名}{-作者}：作者非空
  check(
    '默认模板 含作者',
    applyExportTemplate(kDefaultExportFileNameTemplate, '三体', '刘慈欣') == '三体-刘慈欣',
    applyExportTemplate(kDefaultExportFileNameTemplate, '三体', '刘慈欣'),
  );

  // 2. 默认模板：作者为空 -> 不留分隔符
  check(
    '默认模板 作者为空 -> 仅书名',
    applyExportTemplate(kDefaultExportFileNameTemplate, '三体', '') == '三体',
    applyExportTemplate(kDefaultExportFileNameTemplate, '三体', ''),
  );

  // 3. 仅书名占位符
  check(
    '{书名} 仅书名',
    applyExportTemplate('{书名}', '红楼梦', '曹雪芹') == '红楼梦',
    applyExportTemplate('{书名}', '红楼梦', '曹雪芹'),
  );

  // 4. {书名}{作者} 直接拼接
  check(
    '{书名}{作者} 拼接',
    applyExportTemplate('{书名}{作者}', '三体', '刘慈欣') == '三体刘慈欣',
    applyExportTemplate('{书名}{作者}', '三体', '刘慈欣'),
  );

  // 5. {书名} 作者：{作者} 类 legado 默认形态
  check(
    '{书名} 作者：{作者}',
    applyExportTemplate('{书名} 作者：{作者}', '三体', '刘慈欣') == '三体 作者：刘慈欣',
    applyExportTemplate('{书名} 作者：{作者}', '三体', '刘慈欣'),
  );

  // 6. 文件系统安全清洗：非法字符 -> _
  check(
    '非法字符清洗',
    applyExportTemplate('{书名}', '书:名/1', '') == '书_名_1',
    applyExportTemplate('{书名}', '书:名/1', ''),
  );

  // 7. 作者含非法字符同样清洗
  check(
    '作者非法字符清洗',
    applyExportTemplate('{书名}{-作者}', '三体', '刘/慈欣') == '三体-刘_慈欣',
    applyExportTemplate('{书名}{-作者}', '三体', '刘/慈欣'),
  );

  // 8. 空书名回退 'book'
  check(
    '空书名回退 book',
    applyExportTemplate('{书名}', '', '') == 'book',
    applyExportTemplate('{书名}', '', ''),
  );

  // 9. 连续分隔符折叠
  check(
    '缺作者时多余分隔被清',
    applyExportTemplate('{书名}-{作者}', '三体', '') == '三体',
    applyExportTemplate('{书名}-{作者}', '三体', ''),
  );

  print(_failures == 0 ? '\n全部通过 ✅' : '\n失败 $_failures 项 ❌');
  if (_failures > 0) throw StateError('导出文件名模板测试未通过');
}
