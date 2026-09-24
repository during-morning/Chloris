import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  group('replaceWithWatchdog 小文本（≤32KB）同步路径', () {
    test('isRegex=false 字面替换正确', () async {
      final out = await replaceWithWatchdog(
        input: 'hello world',
        pattern: 'world',
        replacement: '地球',
        isRegex: false,
        timeout: const Duration(seconds: 1),
      );
      expect(out, 'hello 地球');
    });

    test('isRegex=true 正则替换正确', () async {
      final out = await replaceWithWatchdog(
        input: '第一章 广告 第二章 广告',
        pattern: r'广告',
        replacement: '',
        isRegex: true,
        timeout: const Duration(seconds: 1),
      );
      expect(out.contains('广告'), isFalse);
      expect(out, '第一章  第二章 ');
    });

    test('接近阈值的小文本也走同步、结果正确', () async {
      final big = 'x' * (32 * 1024); // 恰好 32KB，等于阈值 → 同步
      final out = await replaceWithWatchdog(
        input: big,
        pattern: 'y',
        replacement: 'z',
        isRegex: false,
        timeout: const Duration(seconds: 1),
      );
      expect(out, big); // 无匹配，原样返回
    });
  });

  group('replaceWithWatchdog 大文本（>32KB）看门狗', () {
    test('灾难性回溯在短 timeout 下被打断，抛 regex_timeout', () async {
      // 40KB 的 a + 一个 '!'，'(a+)+$' 对「不以 a 结尾」的长串做灾难性回溯。
      final input = '${'a' * 40000}!';
      expect(input.length, greaterThan(32 * 1024));

      expect(
        () => replaceWithWatchdog(
          input: input,
          pattern: r'(a+)+$',
          replacement: '',
          isRegex: true,
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'regex_timeout'),
        ),
      );
    });

    test('正常大文本在 timeout 内完成，不误杀', () async {
      final input = '${'a' * 40000} b ${'c' * 40000}';
      final stopwatch = Stopwatch()..start();
      final out = await replaceWithWatchdog(
        input: input,
        pattern: r'\s+',
        replacement: ' ',
        isRegex: true,
        timeout: const Duration(seconds: 2),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(out, '${'a' * 40000} b ${'c' * 40000}');
    });
  });

  group('replaceWithWatchdog 非法 pattern', () {
    test('非法正则抛 regex_invalid', () async {
      expect(
        () => replaceWithWatchdog(
          input: 'abc',
          pattern: r'(', // 未闭合分组
          replacement: '',
          isRegex: true,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'regex_invalid'),
        ),
      );
    });
  });

  group('ContentProcessor._apply 超时跳过语义', () {
    test('大文本规则超时被跳过且不污染后续规则', () async {
      final book = Book(bookUrl: 'u', name: '书', origin: 'o');
      final chapter = BookChapter(url: 'c', title: '章', bookUrl: 'u');
      final rules = [
        ReplaceRule(
          name: 'catastrophe',
          pattern: r'(a+)+$',
          replacement: '',
          isRegex: true,
          timeoutMillisecond: 100,
        ),
        ReplaceRule(
          name: 'normal',
          pattern: '广告',
          replacement: '',
          isRegex: false,
        ),
      ];
      final p = ContentProcessor.forBook(book, allRules: rules);
      final input = '${'a' * 40000}! 这里有广告';
      final out = await p.process(book: book, chapter: chapter, content: input);
      // 灾难规则超时跳过 → 保留原文；
      expect(out.text.contains('a'), isTrue);
      // 正常规则仍生效 → 广告被去掉。
      expect(out.text.contains('广告'), isFalse);
    });
  });
}
