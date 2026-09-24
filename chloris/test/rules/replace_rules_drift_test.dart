import 'dart:convert';
import 'dart:io';

import 'package:chloris/core/persist/app_db.dart';
import 'package:chloris/core/persist/persist_queue.dart';
import 'package:chloris/features/rules/replace_rules_controller.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Lets the fire-and-forget `_persist()` reach `PersistQueue.schedule` before
/// flushing. `_persist()` awaits the preferences handle first, so flushing
/// immediately finds no job and the mirror silently never runs.
Future<void> _settleStore() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await PersistQueue.instance.flush();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(
      Directory.systemTemp.createTempSync('chloris_rules_test').path,
    );
  });

  test('replace rules reach the drift table, which used to stay empty', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(replaceRulesProvider.notifier).addAll([
      ReplaceRule(
        name: '正文去广告',
        pattern: '广告.*',
        replacement: '',
        scope: '正文',
        excludeScope: '标题',
        isRegex: true,
        timeoutMillisecond: 1500,
        order: 3,
      ),
      ReplaceRule(
        name: '纯文本替换',
        pattern: 'foo',
        replacement: 'bar',
        isRegex: false,
        scopeTitle: true,
        scopeContent: false,
      ),
    ]);

    await _settleStore();

    final db = await AppDb.open();
    expect(db, isNotNull, reason: 'drift must open behind the fake provider');
    final rows = await db!.select(db.replaceRules).get();
    expect(rows, hasLength(2));

    final first = rows.firstWhere((r) => r.name == '正文去广告');
    // The four columns this table never had before.
    expect(first.scope, '正文');
    expect(first.excludeScope, '标题');
    expect(first.isRegex, isTrue);
    expect(first.timeoutMillisecond, 1500);
    expect(first.orderValue, 3);

    final second = rows.firstWhere((r) => r.name == '纯文本替换');
    expect(second.isRegex, isFalse);
    expect(second.scopeTitle, isTrue);
    expect(second.scopeContent, isFalse);
    // Column defaults match the engine model rather than being null.
    expect(second.timeoutMillisecond, 3000);
  });

  test('KV stays authoritative, so the mirror cannot lose the rules', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(replaceRulesProvider.notifier).addAll([
      ReplaceRule(name: 'r', pattern: 'a', replacement: 'b'),
    ]);
    await _settleStore();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('replaceRules');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect((decoded.single as Map)['name'], 'r');
  });

  test('a rewrite replaces rows instead of accumulating duplicates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(replaceRulesProvider.notifier);

    notifier.add(ReplaceRule(name: 'one', pattern: 'a', replacement: 'b'));
    await _settleStore();
    notifier.add(ReplaceRule(name: 'two', pattern: 'c', replacement: 'd'));
    await _settleStore();

    final db = await AppDb.open();
    final rows = await db!.select(db.replaceRules).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.name).toSet(), {'one', 'two'});
  });
}
