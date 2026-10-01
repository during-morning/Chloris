import 'dart:typed_data';
import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/data/database/app_database.dart';
import 'package:chloris/engine/engine_facade.dart';
import 'package:chloris/engine/online_book_adapter.dart';
import 'package:chloris/features/media/audio_resolver.dart';
import 'package:chloris/features/media/music_controller.dart';
import 'package:chloris/features/media/music_repository.dart';
import 'package:chloris/features/media/music_services.dart';
import 'package:chloris/features/media/music_workspace.dart';
import 'package:chloris/features/sources/source_library_provider.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'music_player_test.dart' show FakeMusicDriver, first, second;

class NoHttp implements HttpPort {
  @override
  void cancelInFlight() {}
  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
  @override
  Future<StrResponse> send(HttpRequestSpec spec) => throw UnimplementedError();
}

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('新版播放器 ${style.name} 窄宽屏和文字放大无溢出', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final http = NoHttp(),
          controller = MusicController(driver: FakeMusicDriver());
      final engine = EngineFacade(http: http);
      final services = MusicServices(
        resolver: AudioResolver(
          http: http,
          engine: engine,
          port: EngineOnlineBookAdapter(engine),
          findSource: (_) async => null,
        ),
        repository: MusicRepository(database: db),
        controller: controller,
      );

      await tester.runAsync(() => services.startup);
      controller.restoreQueue([first, second]);
      addTearDown(tester.view.reset);
      for (final size in const [
        Size(240, 280),
        Size(320, 180),
        Size(390, 844),
        Size(1300, 700),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [musicServicesProvider.overrideWithValue(services)],
              child: MaterialApp(
                theme: AppTheme.light(AppThemeFamily.green, style: style),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const MusicFullPlayer(),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$size scale=$scale');
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text(first.displayTitle),
            ),
            findsOneWidget,
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await services.flush();
        services.dispose();
        controller.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await db.close();
      });
      await tester.pump();
    });
  }
  testWidgets('音乐导航与四个空状态正常切换', (tester) async {
    final db = AppDatabase(NativeDatabase.memory()), http = NoHttp();
    final controller = MusicController(driver: FakeMusicDriver()),
        engine = EngineFacade(http: http);
    final services = MusicServices(
      resolver: AudioResolver(
        http: http,
        engine: engine,
        port: EngineOnlineBookAdapter(engine),
        findSource: (_) async => null,
      ),
      repository: MusicRepository(database: db),
      controller: controller,
    );
    await tester.runAsync(() => services.startup);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicServicesProvider.overrideWithValue(services),
          enabledSourcesProvider.overrideWith((_) async => []),
        ],
        child: const MaterialApp(home: MusicWorkspace()),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(find.textContaining('暂无启用'), findsOneWidget);
    for (final tab in ['曲库', '歌单', '下载']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      services.dispose();
      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.close();
    });
  });
}
