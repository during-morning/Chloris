import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chloris/app/router.dart';

void main() {
  test('在线详情、阅读器和目录使用明确的 GoRouter 顶层路径', () {
    expect(bookDetailRoute, '/book/detail');
    expect(readerRoute, '/reader');
    expect(readerTocRoute, '/reader/toc');
    expect(
      appRouter.configuration.routes.whereType<GoRoute>().map((r) => r.path),
      containsAll([bookDetailRoute, readerRoute, readerTocRoute]),
    );
  });
}
