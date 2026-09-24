import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/application/download/download_use_cases.dart';
import 'package:chloris/application/rss/rss_use_cases.dart';
import 'package:chloris/application/settings/settings_use_cases.dart';
import 'package:chloris/application/rss/rss_models.dart';
import 'package:chloris/services/backup_service.dart';

class _FakeRssPort implements RssFeedPort {
  _FakeRssPort(this.body);

  final String body;
  final urls = <String>[];

  @override
  Future<StrResponse> fetch(String url, {required String session}) async {
    urls.add('$session:$url');
    return StrResponse(url: url, body: body);
  }

  @override
  void cancel(String session) {}
}

class _FakeBackupPort implements BackupPort {
  BackupSnapshot? created;

  @override
  Uint8List create(BackupSnapshot snapshot, {String? password}) {
    created = snapshot;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  BackupData restore(Uint8List bytes, {String? password}) =>
      BackupData(sources: const [], replaces: const [], tocs: const []);
}

class _FakeWebDavPort implements WebDavPort {
  final files = <String, Uint8List>{};

  @override
  Future<Uint8List?> getFile(String path) async => files[path];

  @override
  Future<List<String>> list(String path) async => files.keys.toList();

  @override
  Future<bool> delete(String path) async => files.remove(path) != null;

  @override
  Future<bool> putFile(String path, Uint8List bytes) async {
    files[path] = bytes;
    return true;
  }
}

class _FakeBatchPort implements BatchDownloadPort {
  String? bookName;
  int? fromIndex;
  int? total;

  @override
  Future<void> enqueueOrResume({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
  }) async {
    this.bookName = bookName;
    this.fromIndex = fromIndex;
    this.total = total;
  }
}

void main() {
  test(
    'RSS use case parses feed through the port and deduplicates pages',
    () async {
      final port = _FakeRssPort('''<?xml version="1.0"?>
<rss><channel><item><title>第一条</title><link>https://a/1</link></item>
<item><title>第二条</title><link>https://a/2</link></item></channel></rss>''');
      final source = RssSource(sourceUrl: 'https://feed.example/rss');
      final result = await LoadRssArticlesUseCase(port)(source);
      expect(result.map((e) => e.title), ['第一条', '第二条']);
      expect(port.urls.single, 'rss:https://feed.example/rss');
    },
  );

  test('backup use case hands a complete snapshot to the port', () {
    final port = _FakeBackupPort();
    final snapshot = BackupSnapshot(
      sources: const [],
      replaces: const [],
      tocs: const [],
      rssSources: [RssSource(sourceUrl: 'https://feed.example/rss')],
      dictRules: const [
        {'name': 'demo'},
      ],
    );
    final bytes = CreateBackupUseCase(port)(snapshot);
    expect(bytes, [1, 2, 3]);
    expect(
      port.created?.rssSources.single.sourceUrl,
      snapshot.rssSources.single.sourceUrl,
    );
    expect(port.created?.dictRules.single['name'], 'demo');
  });

  test('WebDAV use cases isolate client operations behind a port', () async {
    final fake = _FakeWebDavPort();
    final useCases = WebDavUseCases(factory: (_) => fake);
    const config = WebDavConfig(baseUrl: 'https://dav.example');
    expect(
      await useCases.upload(config, '/backup.zip', Uint8List.fromList([9])),
      isTrue,
    );
    expect(await useCases.download(config, '/backup.zip'), [9]);
    expect(await useCases.list(config, '/'), ['/backup.zip']);
    expect(await useCases.remove(config, '/backup.zip'), isTrue);
  });

  test('batch download use case delegates intent to the queue port', () async {
    final port = _FakeBatchPort();
    await BatchDownloadUseCase(port)(
      bookName: 'demo',
      fromIndex: 2,
      total: 8,
      fetchChapter: (_) async {},
    );
    expect(port.bookName, 'demo');
    expect(port.fromIndex, 2);
    expect(port.total, 8);
  });
}
