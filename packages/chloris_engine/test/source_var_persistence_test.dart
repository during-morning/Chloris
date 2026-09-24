// 源级变量持久化（差异文档 §12 的 P2-12）。
//
// Legado-E 的 `java.put` / `java.get` 落在 CacheManager 上，键形如
// `v_<bookSourceUrl>_<key>`，没有 TTL，**重启后仍在**
// （`data/entities/BaseSource.kt:275-286`）。Chloris 原先只有一个进程内 map，
// 于是「书源在搜索时缓存一个 token、正文时再读」这类写法在重启后必然落空。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(DebugLog.clear);
  tearDown(DebugLog.clear);

  group('键格式（对齐 BaseSource.kt:281）', () {
    test('v_<bookSourceUrl>_<key>', () {
      expect(
        BookSource.varKeyFor('https://a.test', 'token'),
        'v_https://a.test_token',
      );
    });
  });

  group('未挂载持久层', () {
    test('仍在进程内可用，但会留下一次可见告警', () {
      final source = BookSource(bookSourceUrl: 'https://nv.test');
      expect(source.put('k', 'v'), 'v');
      expect(source.get('k'), 'v');
      expect(
        DebugLog.buffer.any(
          (e) => e.tag == 'BookSource' && e.message.contains('变量持久层'),
        ),
        isTrue,
        reason: '「写成功但重启就没了」必须是可见的，不能静默降级',
      );
    });

    test('告警只打一次，不刷屏', () {
      final source = BookSource(bookSourceUrl: 'https://nv2.test');
      for (var i = 0; i < 10; i++) {
        source.put('k$i', 'v$i');
      }
      expect(
        DebugLog.buffer
            .where((e) => e.message.contains('变量持久层'))
            .length,
        1,
      );
    });
  });

  group('挂载持久层（模拟重启后仍在）', () {
    test('put 写进 store，新建同 url 的 BookSource 能读回', () {
      final store = MemoryKvPort();
      final first = BookSource(bookSourceUrl: 'https://p.test')
        ..varStore = store;
      first.put('token', 'abc123');

      // 模拟重启：runtimeVars 全新，但 store 还在。
      final second = BookSource(bookSourceUrl: 'https://p.test')
        ..varStore = store;
      expect(second.runtimeVars, isEmpty);
      expect(second.get('token'), 'abc123');
      // 命中后回填内存层（对齐 CacheManager.get 的磁盘→内存提升）。
      expect(second.runtimeVars['token'], 'abc123');
    });

    test('不同书源的键互不串味', () {
      final store = MemoryKvPort();
      (BookSource(bookSourceUrl: 'https://s1.test')..varStore = store)
          .put('k', 'one');
      (BookSource(bookSourceUrl: 'https://s2.test')..varStore = store)
          .put('k', 'two');
      final s1 = BookSource(bookSourceUrl: 'https://s1.test')..varStore = store;
      final s2 = BookSource(bookSourceUrl: 'https://s2.test')..varStore = store;
      expect(s1.get('k'), 'one');
      expect(s2.get('k'), 'two');
      expect(store.length, 2);
    });

    test('内存层优先于 store（同一次运行内刚写的值不会被旧值盖掉）', () {
      final store = MemoryKvPort();
      store.write(BookSource.varKeyFor('https://w.test', 'k'), 'stale');
      final source = BookSource(bookSourceUrl: 'https://w.test')
        ..varStore = store;
      expect(source.get('k'), 'stale');
      source.put('k', 'fresh');
      expect(source.get('k'), 'fresh');
      expect(
        store.read(BookSource.varKeyFor('https://w.test', 'k')),
        'fresh',
        reason: 'put 必须同时更新持久层',
      );
    });

    test('未写过的键返回空串（对齐 CacheManager.get(...) ?: ""）', () {
      final store = MemoryKvPort();
      final source = BookSource(bookSourceUrl: 'https://x.test')
        ..varStore = store;
      expect(source.get('nope'), '');
    });
  });

  group('经 AnalyzeRule 的完整链路', () {
    test('java.put 写的变量在「重启后」被 java.get 读到', () async {
      final store = MemoryKvPort();
      final source = BookSource(bookSourceUrl: 'https://rule.test')
        ..varStore = store;

      final rule1 = AnalyzeRule(
        jsRuntime: const NoJsRuntime(),
        source: source,
      )..setContent('<p>x</p>');
      rule1.put('loginToken', 'T-1');

      // 新一次运行：新的 RuleData / 新的 AnalyzeRule，只有 store 复用。
      final rule2 = AnalyzeRule(
        jsRuntime: const NoJsRuntime(),
        source: BookSource(bookSourceUrl: 'https://rule.test')
          ..varStore = store,
      )..setContent('<p>x</p>');
      expect(rule2.get('loginToken'), 'T-1');
    });
  });

  group('UnsupportedKvPort：不可用就是不可用', () {
    test('每个操作都抛 DomainError，不回空值', () {
      const port = UnsupportedKvPort();
      expect(port.isPersistent, isFalse);
      expect(() => port.read('k'), throwsA(isA<DomainError>()));
      expect(() => port.write('k', 'v'), throwsA(isA<DomainError>()));
      expect(() => port.delete('k'), throwsA(isA<DomainError>()));
    });

    test('MemoryKvPort 明确声明自己不跨重启', () {
      expect(MemoryKvPort().isPersistent, isFalse);
    });
  });
}
