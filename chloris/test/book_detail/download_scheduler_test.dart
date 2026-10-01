import 'dart:async';
import 'dart:convert';
import 'package:chloris/core/download/chapter_download_scheduler.dart';
import 'package:chloris/core/read/book_validation.dart';
import 'package:chloris/services/book_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('并行任务共用全局上限和主机上限，完成顺序不影响导出顺序', () async {
    final scheduler = ChapterDownloadScheduler(
      concurrency: () => 4,
      hostConcurrency: () => 2,
    );
    var active = 0, peak = 0;
    final hosts = <String, int>{}, peakHosts = <String, int>{};
    final values = await Future.wait(
      List.generate(
        20,
        (i) => scheduler.run(
          host: 'host-${i % 3}',
          action: () async {
            final host = 'host-${i % 3}';
            active++;
            peak = peak < active ? active : peak;
            hosts[host] = (hosts[host] ?? 0) + 1;
            peakHosts[host] = (peakHosts[host] ?? 0) < hosts[host]!
                ? hosts[host]!
                : peakHosts[host]!;
            await Future<void>.delayed(Duration(milliseconds: 5 + i % 4));
            active--;
            hosts[host] = hosts[host]! - 1;
            return '$i';
          },
        ),
      ),
    );
    expect(peak, 4);
    expect(peakHosts.values.every((v) => v <= 2), true);
    expect(values, List.generate(20, (i) => '$i'));
    final txt = utf8.decode(
      buildDownloadedBook({
        'name': '测试',
        'author': '作者',
        'titles': ['第一章', '第二章'],
        'contents': ['一', '二'],
      }),
    );
    expect(txt.indexOf('第一章'), lessThan(txt.indexOf('第二章')));
  });
  test('取消只移除待执行任务，不阻断其他书籍', () async {
    final scheduler = ChapterDownloadScheduler(
          concurrency: () => 1,
          hostConcurrency: () => 1,
        ),
        gate = Completer<void>();
    var cancel = false, ran = false;
    final active = scheduler.run(host: 'a', action: () => gate.future);
    final queued = scheduler.run(
      host: 'a',
      cancelled: () => cancel,
      action: () async {
        ran = true;
      },
    );
    final expectation = expectLater(
      queued,
      throwsA(isA<ChapterDownloadCancelled>()),
    );
    cancel = true;
    scheduler.cancelPending();
    await expectation;
    gate.complete();
    await active;
    expect(ran, false);
    expect(await scheduler.run(host: 'a', action: () async => 42), 42);
  });
  test('有效单字书籍保留，空标题、空地址和脚本地址被过滤', () {
    expect(
      bookIdentityError(name: '道', url: 'https://example.com/book'),
      isNull,
    );
    expect(bookIdentityError(name: '道', url: 'local:fixture'), isNull);
    expect(
      bookIdentityError(name: '', url: 'https://example.com/book'),
      isNotNull,
    );
    expect(bookIdentityError(name: '书', url: 'javascript:alert(1)'), isNotNull);
    expect(
      bookIdentityError(name: '登录万界', url: 'https://example.com/book'),
      isNull,
    );
  });
}
