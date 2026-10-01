import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'package:chloris/app/providers.dart';
import 'package:chloris/application/sources/source_unify.dart';
import 'package:chloris/features/sources/sources_screen.dart';

class _FakeAssetLoader implements AssetLoader {
  const _FakeAssetLoader();

  @override
  Future<String> load(String path) async {
    // 同步读文件后在 microtask 中返回，避免 widget 测试 fake-async 下真实 IO 不落地。
    return File('assets/sources/default_book_sources.json').readAsStringSync();
  }
}

void main() {
  test('默认源资产可解析且已去重选优', () async {
    final raw = await File(
      'assets/sources/default_book_sources.json',
    ).readAsString();
    final list = BookSource.listFromJson(jsonDecode(raw));
    expect(list.length, inInclusiveRange(1800, 2000));
    final enabled = list.where((s) => s.enabled).length;
    expect(enabled, greaterThan(1500));
    expect(enabled, lessThanOrEqualTo(list.length));
    // URL 去重：归一化后无重复
    final keys = list
        .map((s) => canonicalizeSourceUrl(s.bookSourceUrl))
        .toSet();
    expect(keys.length, list.length);
    expect(keys, isNot(contains('')));
    // 运行时会归到统一分区
    final unified = list.map(unifySourceGroup).toSet();
    expect(unified.every(unifiedSourceGroups.contains), isTrue);
  });

  testWidgets('SourcesScreen 展示默认源总数与启用数', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetLoaderProvider.overrideWithValue(const _FakeAssetLoader()),
        ],
        child: const MaterialApp(home: SourcesScreen()),
      ),
    );
    var found = false;
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      if (find.textContaining('共 ').evaluate().isNotEmpty &&
          find.textContaining('启用 ').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'SourcesScreen never showed 共/启用');
    expect(find.textContaining('共 '), findsOneWidget);
    expect(find.textContaining('启用 '), findsOneWidget);
  });
}
