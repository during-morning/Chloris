import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';

import '../../core/persist/kv_settings.dart';
import '../../core/persist/settings_migrations.dart';
import '../rss/rss_models.dart';
import '../../services/backup_service.dart';
import '../../services/webdav_service.dart';

/// Application boundary for settings writes.  Feature pages update Riverpod
/// state immediately and send persistence through this port, so storage and
/// schema migration stay out of widget code.
abstract interface class SettingsWritePort {
  Future<void> setBool(String key, bool value);

  Future<void> setInt(String key, int value);

  Future<void> setDouble(String key, double value);

  Future<void> setString(String key, String value);
}

class KvSettingsWriteAdapter implements SettingsWritePort {
  const KvSettingsWriteAdapter();

  Future<KvSettings> _ready() => KvSettings.ready();

  @override
  Future<void> setBool(String key, bool value) async =>
      (await _ready()).setBool(key, value);

  @override
  Future<void> setDouble(String key, double value) async =>
      (await _ready()).setDouble(key, value);

  @override
  Future<void> setInt(String key, int value) async =>
      (await _ready()).setInt(key, value);

  @override
  Future<void> setString(String key, String value) async =>
      (await _ready()).setString(key, value);
}

class SettingsWriteUseCase {
  const SettingsWriteUseCase(this._port);

  final SettingsWritePort _port;

  Future<void> setBool(String key, bool value) =>
      _run(() => _port.setBool(key, value));

  Future<void> setDouble(String key, double value) =>
      _run(() => _port.setDouble(key, value));

  Future<void> setInt(String key, int value) =>
      _run(() => _port.setInt(key, value));

  Future<void> setString(String key, String value) =>
      _run(() => _port.setString(key, value));

  Future<void> resetNetworkDefaults() async {
    await setInt('httpTimeoutSec', 30);
    await setInt('searchTimeoutSec', 30);
    await setInt('tocTimeoutSec', 30);
    await setInt('contentTimeoutSec', 30);
    await setInt('searchPool', 32);
    await setInt('searchHostCap', 2);
    await setInt('downloadPool', 8);
    await setInt('downloadHostCap', 3);
    await setBool('debugVerbose', true);
    await setString('userAgent', '');
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.persist);
    }
  }
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.sources,
    required this.replaces,
    required this.tocs,
    this.rssSources = const [],
    this.dictRules = const [],
  });

  final List<BookSource> sources;
  final List<ReplaceRule> replaces;
  final List<TxtTocRule> tocs;
  final List<RssSource> rssSources;
  final List<Map<String, dynamic>> dictRules;
}

abstract interface class BackupPort {
  Uint8List create(BackupSnapshot snapshot, {String? password});

  BackupData restore(Uint8List bytes, {String? password});
}

class BackupServiceAdapter implements BackupPort {
  const BackupServiceAdapter();

  @override
  Uint8List create(BackupSnapshot snapshot, {String? password}) =>
      const BackupService().createBackup(
        sources: snapshot.sources,
        replaces: snapshot.replaces,
        tocs: snapshot.tocs,
        rssSources: snapshot.rssSources,
        dictRules: snapshot.dictRules,
        password: password,
      );

  @override
  BackupData restore(Uint8List bytes, {String? password}) =>
      const BackupService().restoreBackup(bytes, password: password);
}

class CreateBackupUseCase {
  const CreateBackupUseCase(this._port);

  final BackupPort _port;

  Uint8List call(BackupSnapshot snapshot, {String? password}) {
    try {
      return _port.create(snapshot, password: password);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.persist);
    }
  }
}

class RestoreBackupUseCase {
  const RestoreBackupUseCase(this._port);

  final BackupPort _port;

  BackupData call(Uint8List bytes, {String? password}) {
    try {
      return _port.restore(bytes, password: password);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.persist);
    }
  }
}

class WebDavConfig {
  const WebDavConfig({
    required this.baseUrl,
    this.username = '',
    this.password = '',
  });

  final String baseUrl;
  final String username;
  final String password;
}

abstract interface class WebDavPort {
  Future<List<String>> list(String path);

  Future<bool> putFile(String path, Uint8List bytes);

  Future<Uint8List?> getFile(String path);

  Future<bool> delete(String path);
}

class WebDavClientAdapter implements WebDavPort {
  WebDavClientAdapter(WebDavConfig config)
    : _client = WebDavClient(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
      );

  final WebDavClient _client;

  @override
  Future<Uint8List?> getFile(String path) => _client.getFile(path);

  @override
  Future<List<String>> list(String path) => _client.list(path);

  @override
  Future<bool> delete(String path) => _client.delete(path);

  @override
  Future<bool> putFile(String path, Uint8List bytes) =>
      _client.putFile(path, bytes);
}

class WebDavUseCases {
  const WebDavUseCases({this.factory = WebDavClientAdapter.new});

  final WebDavPort Function(WebDavConfig config) factory;

  Future<List<String>> list(WebDavConfig config, String path) async {
    try {
      return await factory(config).list(path);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.request);
    }
  }

  Future<bool> upload(WebDavConfig config, String path, Uint8List bytes) async {
    try {
      return await factory(config).putFile(path, bytes);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.request);
    }
  }

  Future<Uint8List?> download(WebDavConfig config, String path) async {
    try {
      return await factory(config).getFile(path);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.request);
    }
  }

  Future<bool> remove(WebDavConfig config, String path) async {
    try {
      return await factory(config).delete(path);
    } catch (error) {
      throw DomainError.from(error, stage: DomainErrorStage.request);
    }
  }
}
