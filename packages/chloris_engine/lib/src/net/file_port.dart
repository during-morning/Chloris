import 'dart:typed_data';

import '../models/domain_protocol.dart';

/// Host file-system access for rule scripts.
///
/// Book sources use `java.readFile` / `java.downloadFile` / `java.unzipFile` to
/// fetch and unpack auxiliary assets such as dictionary packs or font files.
/// Only some platforms can do that, so the engine depends on this port instead
/// of `dart:io`, and an absent capability is reported rather than papered over
/// with an empty string — a silent `''` from `readFile` is indistinguishable
/// from an empty file and corrupts whatever consumes it.
abstract interface class FilePort {
  /// Whether the host can touch the file system at all.
  bool get isSupported;

  /// Root that all rule-visible paths are confined to. Implementations must
  /// reject paths that escape it.
  Future<String> downloadDirectory();

  Future<Uint8List?> readBytes(String path);

  Future<bool> writeBytes(String path, Uint8List bytes);

  Future<bool> delete(String path);

  /// Regular files directly inside [directory].
  Future<List<String>> list(String directory);

  /// Resolves [name] inside [downloadDirectory] without touching the disk.
  Future<String> resolve(String name);
}

/// The port used when the host has no file access (Web, unit tests).
///
/// Every operation throws a [DomainError] rather than returning a benign
/// default, so a rule that needs files fails visibly.
class UnsupportedFilePort implements FilePort {
  const UnsupportedFilePort();

  @override
  bool get isSupported => false;

  static DomainError _error(String what) => DomainError(
    code: 'file_port_unsupported',
    stage: DomainErrorStage.request,
    message: '$what 在当前平台不可用',
    recoverable: false,
    retryable: false,
    suggestedAction: '该规则需要文件系统访问；桌面与移动端可用，Web 端不支持',
  );

  @override
  Future<String> downloadDirectory() async => throw _error('文件目录');

  @override
  Future<Uint8List?> readBytes(String path) async => throw _error('读取文件');

  @override
  Future<bool> writeBytes(String path, Uint8List bytes) async =>
      throw _error('写入文件');

  @override
  Future<bool> delete(String path) async => throw _error('删除文件');

  @override
  Future<List<String>> list(String directory) async => throw _error('列出目录');

  @override
  Future<String> resolve(String name) async => throw _error('解析文件路径');
}
