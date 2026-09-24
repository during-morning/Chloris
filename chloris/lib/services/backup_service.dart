import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../application/rss/rss_models.dart';

class BackupData {
  BackupData({
    required this.sources,
    required this.replaces,
    required this.tocs,
    this.rssSources = const [],
    this.dictRules = const [],
    this.version = 1,
  });

  final List<BookSource> sources;
  final List<ReplaceRule> replaces;
  final List<TxtTocRule> tocs;
  final List<RssSource> rssSources;
  final List<Map<String, dynamic>> dictRules;
  final int version;
}

class BackupService {
  const BackupService();

  /// 生成备份 zip（可选 AES-256-CBC 加密）；返回字节。
  Uint8List createBackup({
    required List<BookSource> sources,
    required List<ReplaceRule> replaces,
    required List<TxtTocRule> tocs,
    List<RssSource> rssSources = const [],
    List<Map<String, dynamic>> dictRules = const [],
    String? password,
  }) {
    final json = jsonEncode({
      'version': 2,
      'book_sources': sources.map((e) => e.toJson()).toList(),
      'replace_rules': replaces.map((e) => e.toJson()).toList(),
      'txt_toc_rules': tocs.map((e) => e.toJson()).toList(),
      'rss_sources': rssSources.map((e) => e.toJson()).toList(),
      'dict_rules': dictRules,
    });
    var bytes = utf8.encode(json);
    if (password != null && password.isNotEmpty) {
      bytes = AesCbc.encrypt(bytes, password);
    }
    final archive = Archive();
    archive.addFile(ArchiveFile('backup.json', bytes.length, bytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// 解析备份 zip（自动检测 AES 加密）。
  BackupData restoreBackup(Uint8List bytes, {String? password}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('backup.json');
    if (file == null) {
      throw StateError('备份文件缺少 backup.json');
    }
    var data = file.content as List<int>;
    if (password != null && password.isNotEmpty) {
      data = AesCbc.decrypt(Uint8List.fromList(data), password);
    }
    final decoded = jsonDecode(utf8.decode(data));
    if (decoded is! Map) throw StateError('备份数据格式无效');
    final map = Map<String, dynamic>.from(decoded);
    final version = (map['version'] as num?)?.toInt() ?? 1;
    if (version < 1 || version > 2) {
      throw StateError('不支持的备份版本 $version');
    }
    final dictRaw = map['dict_rules'];
    return BackupData(
      sources: BookSource.listFromJson(map['book_sources']),
      replaces: ReplaceRule.listFromJson(map['replace_rules']),
      tocs: TxtTocRule.listFromJson(map['txt_toc_rules']),
      rssSources: RssSource.listFromJson(map['rss_sources']),
      dictRules: dictRaw is List
          ? [
              for (final item in dictRaw)
                if (item is Map) Map<String, dynamic>.from(item),
            ]
          : const [],
      version: version,
    );
  }
}

/// AES-256-CBC（PKCS7）示例实现。
abstract final class AesCbc {
  static Uint8List encrypt(Uint8List input, String password) {
    final key = _key(password);
    final iv = _iv(password);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));
    final padded = _pad(input, 16);
    final out = Uint8List(padded.length);
    for (var i = 0; i < padded.length; i += 16) {
      cipher.processBlock(padded, i, out, i);
    }
    return out;
  }

  static Uint8List decrypt(Uint8List input, String password) {
    final key = _key(password);
    final iv = _iv(password);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(input.length);
    for (var i = 0; i < input.length; i += 16) {
      cipher.processBlock(input, i, out, i);
    }
    // 去掉 PKCS7 填充
    var pad = out[out.length - 1];
    if (pad < 1 || pad > 16) pad = 0;
    if (pad > 0 && pad <= out.length) {
      return Uint8List.fromList(out.sublist(0, out.length - pad));
    }
    return out;
  }

  static Uint8List _key(String password) =>
      Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes);

  static Uint8List _iv(String password) => Uint8List.fromList(
    sha256.convert(utf8.encode('iv:$password')).bytes.sublist(0, 16),
  );

  static Uint8List _pad(Uint8List input, int block) {
    final pad = block - (input.length % block);
    final out = Uint8List(input.length + pad);
    out.setRange(0, input.length, input);
    for (var i = 0; i < pad; i++) {
      out[input.length + i] = pad;
    }
    return out;
  }
}
