import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chloris/engine/file_port/file_port_io.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;

  setUp(() {
    base = Directory.systemTemp.createTempSync('chloris_fileport');
    PathProviderPlatform.instance = _FakePathProvider(base.path);
  });

  tearDown(() {
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  test('the factory returns a usable port on IO', () {
    expect(createFilePort().isSupported, isTrue);
  });

  test('write/read/delete round-trip inside the root', () async {
    final port = AppFilePort();
    final dir = await port.downloadDirectory();
    final path = p.join(dir, 'a.txt');

    expect(await port.writeBytes(path, Uint8List.fromList([1, 2, 3])), isTrue);
    expect((await port.readBytes(path))!.toList(), [1, 2, 3]);
    expect(await port.delete(path), isTrue);
    expect(await port.readBytes(path), isNull);
  });

  test('relative paths resolve under the root', () async {
    final port = AppFilePort();
    final resolved = await port.resolve('nested/x.txt');
    final dir = await port.downloadDirectory();
    expect(resolved, p.join(dir, 'nested', 'x.txt'));
  });

  test('path traversal is rejected instead of escaped', () async {
    final port = AppFilePort();
    for (final bad in const [
      '../../etc/passwd',
      '/etc/passwd',
      'a/../../../../outside.txt',
    ]) {
      await expectLater(
        port.writeBytes(bad, Uint8List(0)),
        throwsA(isA<DomainError>()),
        reason: bad,
      );
    }
  });

  test('an absolute path outside the root is rejected, not rewritten', () async {
    final port = AppFilePort();
    final outside = File(p.join(base.path, 'outside.txt'));
    await expectLater(
      port.readBytes(outside.path),
      throwsA(isA<DomainError>()),
    );
    expect(outside.existsSync(), isFalse);
  });

  test('reads and writes binary content unchanged', () async {
    final port = AppFilePort();
    final dir = await port.downloadDirectory();
    final bytes = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
    final path = p.join(dir, 'blob.bin');
    await port.writeBytes(path, bytes);
    expect((await port.readBytes(path))!.toList(), bytes.toList());
  });

  test('a GBK file decodes through readTxtFile', () async {
    final port = AppFilePort();
    final dir = await port.downloadDirectory();
    final path = p.join(dir, 'gbk.txt');
    await port.writeBytes(path, Uint8List.fromList([0xd6, 0xd0]));

    final host = JavaHost(
      http: _NoHttp(),
      cookieStore: CookieStore(),
      filePort: port,
    );
    expect(await host.readTxtFile(path, 'GBK'), '中');
    // Without a charset the detector is used; the exact answer depends on the
    // heuristic, so only assert it does not throw and is not empty.
    expect(await host.readTxtFile(path), isNotEmpty);
  });

  test('list returns files and does not escape the root', () async {
    final port = AppFilePort();
    final dir = await port.downloadDirectory();
    await port.writeBytes(p.join(dir, 'one.txt'), Uint8List(0));
    await port.writeBytes(p.join(dir, 'two.txt'), Uint8List(0));

    final files = await port.list(dir);
    expect(files, hasLength(2));

    await expectLater(
      port.list(p.join(base.path, '..')),
      throwsA(isA<DomainError>()),
    );
  });

  test('utf8 text written then read back is identical', () async {
    final port = AppFilePort();
    final dir = await port.downloadDirectory();
    final path = p.join(dir, 'cn.txt');
    await port.writeBytes(path, Uint8List.fromList(utf8.encode('第一章 起')));
    final host = JavaHost(
      http: _NoHttp(),
      cookieStore: CookieStore(),
      filePort: port,
    );
    expect(await host.readTxtFile(path), '第一章 起');
  });
}

class _NoHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  void cancelInFlight() {}
}
