enum ImportType {
  bookSource,
  rssSource,
  replaceRule,
  textTocRule,
  theme,
  readConfig,
  addToBookshelf,
  unknown,
}

class ImportRequest {
  const ImportRequest({required this.type, this.src = '', this.path});

  final ImportType type;
  final String src;
  final String? path;
}

ImportRequest? parseLegadoImport(String uri) {
  final u = Uri.tryParse(uri);
  if (u == null || u.scheme != 'legado') return null;
  if (u.host != 'import' && u.host != '') return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  final type = _typeOf(segs.isEmpty ? '' : segs.first);
  final src = u.queryParameters['src']?.trim() ?? '';
  return ImportRequest(type: type, src: src, path: segs.isEmpty ? null : segs.first);
}

ImportType _typeOf(String path) {
  switch (path) {
    case 'bookSource': return ImportType.bookSource;
    case 'rssSource': return ImportType.rssSource;
    case 'replaceRule': return ImportType.replaceRule;
    case 'textTocRule':
    case 'txtTocRule': return ImportType.textTocRule;
    case 'theme': return ImportType.theme;
    case 'readConfig': return ImportType.readConfig;
    case 'addToBookshelf': return ImportType.addToBookshelf;
    default: return ImportType.unknown;
  }
}
