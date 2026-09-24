import '../core/persist/kv_settings.dart';

import 'export_filename.dart';

/// 导出文件名模板的持久化键。
const String _exportFileNameTemplateKey = 'exportFileNameTemplate';

/// 读取导出文件名模板，缺省回退 [kDefaultExportFileNameTemplate]。
Future<String> loadExportFileNameTemplate() async {
  final p = await KvSettings.ready();
  return p.getString(_exportFileNameTemplateKey) ?? kDefaultExportFileNameTemplate;
}

/// 保存导出文件名模板。
Future<void> saveExportFileNameTemplate(String template) async {
  final p = await KvSettings.ready();
  await p.setString(_exportFileNameTemplateKey, template);
}
