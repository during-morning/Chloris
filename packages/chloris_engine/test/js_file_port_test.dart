import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// In-memory file system so the engine tests do not touch the disk.
class _MemoryFilePort implements FilePort {
  _MemoryFilePort({this.root = '/root'});

  final String root;
  final Map<String, Uint8List> files = {};

  @override
  bool get isSupported => true;

  @override
  Future<String> downloadDirectory() async => root;

  @override
  Future<String> resolve(String name) async => '$root/$name';

  @override
  Future<Uint8List?> readBytes(String path) async => files[path];

  @override
  Future<bool> writeBytes(String path, Uint8List bytes) async {
    files[path] = bytes;
    return true;
  }

  @override
  Future<bool> delete(String path) async => files.remove(path) != null;

  @override
  Future<List<String>> list(String directory) async =>
      files.keys.where((k) => k.startsWith(directory)).toList();
}

class _NoHttp implements HttpPort {
  _NoHttp({this.bytes = const []});

  final List<int> bytes;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List.fromList(bytes);

  @override
  void cancelInFlight() {}
}

JavaHost _host(FilePort port, {HttpPort? http}) => JavaHost(
  http: http ?? _NoHttp(),
  cookieStore: CookieStore(),
  filePort: port,
);

Uint8List _zipBytes(Map<String, String> entries) {
  final archive = Archive();
  for (final e in entries.entries) {
    final data = utf8.encode(e.value);
    archive.addFile(ArchiveFile(e.key, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  group('UnsupportedFilePort', () {
    const port = UnsupportedFilePort();

    test('reports the capability as absent', () {
      expect(port.isSupported, isFalse);
    });

    test('every operation raises a DomainError, never a benign default', () async {
      // A silent '' from readFile is indistinguishable from an empty file and
      // corrupts whatever consumes it.
      await expectLater(port.readBytes('a'), throwsA(isA<DomainError>()));
      await expectLater(
        port.writeBytes('a', Uint8List(0)),
        throwsA(isA<DomainError>()),
      );
      await expectLater(port.delete('a'), throwsA(isA<DomainError>()));
      await expectLater(port.list('a'), throwsA(isA<DomainError>()));
      await expectLater(port.downloadDirectory(), throwsA(isA<DomainError>()));
      await expectLater(port.resolve('a'), throwsA(isA<DomainError>()));
    });

    test('the error names the missing capability', () async {
      try {
        await port.readBytes('a');
        fail('should have thrown');
      } on DomainError catch (e) {
        expect(e.code, 'file_port_unsupported');
        expect(e.retryable, isFalse);
        expect(e.suggestedAction, isNotNull);
      }
    });
  });

  group('JavaHost file operations', () {
    test('readTxtFile decodes UTF-8 content', () async {
      final port = _MemoryFilePort();
      port.files['/root/a.txt'] = Uint8List.fromList(utf8.encode('第一章'));
      expect(await _host(port).readTxtFile('/root/a.txt'), '第一章');
    });

    test('readTxtFile honours an explicit charset', () async {
      final port = _MemoryFilePort();
      // GBK for 中 is D6 D0.
      port.files['/root/g.txt'] = Uint8List.fromList([0xd6, 0xd0]);
      expect(await _host(port).readTxtFile('/root/g.txt', 'GBK'), '中');
    });

    test('readFile returns empty for a missing file, the path otherwise', () async {
      final port = _MemoryFilePort();
      final host = _host(port);
      expect(await host.readFile('/root/none'), '');
      port.files['/root/x'] = Uint8List.fromList([1]);
      expect(await host.readFile('/root/x'), '/root/x');
    });

    test('downloadFile writes the response and returns the local path', () async {
      final port = _MemoryFilePort();
      final host = _host(port, http: _NoHttp(bytes: [104, 105]));
      final path = await host.downloadFile('https://cdn.test/dict.txt');
      expect(path, '/root/dict.txt');
      expect(port.files[path], isNotNull);
      expect(utf8.decode(port.files[path]!), 'hi');
    });

    test('downloadFile with explicit content skips the network', () async {
      final port = _MemoryFilePort();
      final host = _host(port);
      final path = await host.downloadFile('https://cdn.test/a.txt', 'body');
      expect(utf8.decode(port.files[path]!), 'body');
    });

    test('downloadFile sanitises path separators out of the name', () async {
      final port = _MemoryFilePort();
      final host = _host(port);
      final path = await host.downloadFile('https://cdn.test/a/b/c.txt');
      expect(path, '/root/c.txt');
    });

    test('deleteFile reports whether anything was removed', () async {
      final port = _MemoryFilePort();
      port.files['/root/x'] = Uint8List(0);
      final host = _host(port);
      expect(await host.deleteFile('/root/x'), 'true');
      expect(await host.deleteFile('/root/x'), 'false');
    });

    test('getTxtInFolder keeps only .txt entries', () async {
      final port = _MemoryFilePort();
      port.files['/root/a.txt'] = Uint8List(0);
      port.files['/root/b.TXT'] = Uint8List(0);
      port.files['/root/c.json'] = Uint8List(0);
      final out = await _host(port).getTxtInFolder('/root');
      expect(out, hasLength(2));
      expect(out.every((p) => p.toLowerCase().endsWith('.txt')), isTrue);
    });

    test('unzipFile extracts entries and returns the target directory', () async {
      final port = _MemoryFilePort();
      port.files['/root/pack.zip'] = _zipBytes({
        'inner/one.txt': 'one',
        'two.txt': 'two',
      });
      final host = _host(port);
      final dir = await host.unzipFile('/root/pack.zip');
      expect(dir, '/root/pack.zip_unzip');
      expect(utf8.decode(port.files['$dir/inner/one.txt']!), 'one');
      expect(utf8.decode(port.files['$dir/two.txt']!), 'two');
    });

    test('unzipFile on a missing archive fails loudly', () async {
      final port = _MemoryFilePort();
      await expectLater(
        _host(port).unzipFile('/root/none.zip'),
        throwsA(isA<DomainError>()),
      );
    });

    test('unzipFile content is readable through getZipStringContent', () async {
      final port = _MemoryFilePort();
      port.files['/root/pack.zip'] = _zipBytes({'a.txt': 'hello'});
      final host = _host(port);
      await host.unzipFile('/root/pack.zip');
      expect(
        utf8.decode(port.files['/root/pack.zip_unzip/a.txt']!),
        'hello',
      );
    });
  });

  group('archives the backend cannot read', () {
    test('unArchiveFile dispatches zip and refuses the rest', () async {
      final port = _MemoryFilePort();
      port.files['/root/p.zip'] = _zipBytes({'a': 'b'});
      final host = _host(port);
      expect(await host.unArchiveFile('/root/p.zip'), endsWith('_unzip'));

      await expectLater(
        host.unArchiveFile('/root/p.7z'),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        host.unArchiveFile('/root/p.rar'),
        throwsA(isA<DomainError>()),
      );
    });

    test('rar and 7z report the backend limitation instead of returning empty',
        () async {
      final port = _MemoryFilePort();
      final host = _host(port);
      for (final call in <Future<Object?> Function()>[
        () => host.un7zFile('/root/a.7z'),
        () => host.unrarFile('/root/a.rar'),
        () => host.getRarStringContent('u', 'p'),
        () => host.get7zStringContent('u', 'p'),
        () => host.getRarByteArrayContent('u', 'p'),
        () => host.get7zByteArrayContent('u', 'p'),
      ]) {
        await expectLater(call(), throwsA(isA<DomainError>()));
      }
    });
  });

  group('bridge wiring', () {
    test('file operations ride the async two-pass cycle', () {
      for (final name in const [
        'readTxtFile',
        'readFile',
        'getFile',
        'downloadFile',
        'deleteFile',
        'getTxtInFolder',
        'unzipFile',
        'unArchiveFile',
        'importScript',
      ]) {
        expect(JsHostSession.isNetwork(name), isTrue, reason: name);
      }
    });

    test('the prelude exposes every file entry point', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final name in const [
        'readTxtFile',
        'readFile',
        'getFile',
        'downloadFile',
        'deleteFile',
        'getTxtInFolder',
        'unzipFile',
        'unArchiveFile',
        'un7zFile',
        'unrarFile',
        'getRarStringContent',
        'get7zStringContent',
        'getRarByteArrayContent',
        'get7zByteArrayContent',
        'importScript',
      ]) {
        expect(prelude, contains('$name:'), reason: name);
      }
    });
  });
}
