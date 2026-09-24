import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/services/webdav_service.dart';

void main() {
  test('WebDAV PROPFIND 响应解析为列表', () async {
    final client = WebDavClient(baseUrl: 'https://dav.example.com/');
    // 用私有 list 的解析逻辑通过一个轻量调用不可行，这里直接校验响应 XML 结构可被解析。
    const xml = '''
<?xml version="1.0"?>
<D:multistatus xmlns:D="DAV:">
  <D:response><D:href>/remote.php/dav/files/u/a.txt</D:href><D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat></D:response>
  <D:response><D:href>/remote.php/dav/files/u/folder/</D:href><D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response>
</D:multistatus>''';
    // 直接调用一个公开解析方法（如有）或至少断言客户端存在基本方法。
    expect(client.baseUrl, 'https://dav.example.com/');
    expect(client.username, '');
    final parsed = parseWebDavList(xml);
    expect(parsed.length, 2);
    expect(parsed.any((e) => e.endsWith('/')), isTrue);
  });
}
