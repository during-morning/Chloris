import 'dart:async';

import 'package:chloris/features/media/lyrics_view.dart';
import 'package:chloris/features/media/media_player_screen.dart';
import 'package:chloris/features/media/music_controller.dart';
import 'package:chloris/features/media/music_screen.dart';
import 'package:chloris/services/media_session/audio_handler_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMusicDriver implements MusicPlayerDriver {
  final stateEvents = StreamController<MusicDriverState>.broadcast(sync: true);
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final durationEvents = StreamController<Duration?>.broadcast(sync: true);
  final errorEvents = StreamController<Object>.broadcast(sync: true);
  final playback = Completer<void>();
  final loaded = <MusicTrack>[];
  Duration lastSeek = Duration.zero;
  int plays = 0;
  int pauses = 0;
  bool failNextLoad = false;
  @override
  Stream<MusicDriverState> get states => stateEvents.stream;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<Duration?> get durations => durationEvents.stream;
  @override
  Stream<Object> get errors => errorEvents.stream;
  @override
  Future<void> load(MusicTrack track) async {
    loaded.add(track);
    stateEvents.add(const MusicDriverState(MusicPhase.loading, false));
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('断网');
    }
    durationEvents.add(const Duration(seconds: 90));
    stateEvents.add(const MusicDriverState(MusicPhase.ready, false));
  }

  @override
  Future<void> play() {
    plays++;
    stateEvents.add(const MusicDriverState(MusicPhase.ready, true));
    return playback.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    stateEvents.add(const MusicDriverState(MusicPhase.ready, false));
  }

  @override
  Future<void> stop() async =>
      stateEvents.add(const MusicDriverState(MusicPhase.idle, false));
  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    positionEvents.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    if (!playback.isCompleted) playback.complete();
    await stateEvents.close();
    await positionEvents.close();
    await durationEvents.close();
    await errorEvents.close();
  }
}

const first = MusicTrack(
  url: 'https://example.com/one.mp3',
  title: '第一首',
  lyric: '[00:00.00]第一句\n[00:10.00]第二句\n[00:20.00]第三句',
);
const second = MusicTrack(url: 'https://example.com/two.mp3', title: '第二首');

class DelayedMusicDriver extends FakeMusicDriver {
  final gates = <String, Completer<void>>{};
  int _request = 0;
  MusicTrack? active;
  @override
  Future<void> load(MusicTrack track) async {
    final request = ++_request;
    final gate = gates.putIfAbsent(track.url, () => Completer<void>());
    stateEvents.add(const MusicDriverState(MusicPhase.loading, false));
    await gate.future;
    if (request != _request) throw StateError('旧加载已取消');
    active = track;
    await super.load(track);
  }

  @override
  Future<void> stop() async {
    ++_request;
    await super.stop();
  }
}

void main() {
  test('快速切源取消旧请求，迟到的旧结果不覆盖新歌曲', () async {
    final driver = DelayedMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    final loadingFirst = controller.setQueue([first, second]);
    await Future<void>.delayed(Duration.zero);
    while (!driver.gates.containsKey(first.url)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final loadingSecond = controller.select(1);
    await Future<void>.delayed(Duration.zero);
    driver.gates[second.url]!.complete();
    await loadingSecond;
    driver.gates[first.url]!.complete();
    await loadingFirst;
    expect(driver.active, second);
    expect(controller.current, second);
    expect(controller.error, isNull);
    expect(driver.plays, 1);
  });

  test('加载中暂停或停止禁止自动开始，停止后播放重新加载', () async {
    final driver = DelayedMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    final loadingFirst = controller.setQueue([first]);
    await Future<void>.delayed(Duration.zero);
    await controller.pause();
    driver.gates[first.url]!.complete();
    await loadingFirst;
    expect(controller.playing, false);
    expect(driver.plays, 0);
    final loadingSecond = controller.setQueue([second]);
    await Future<void>.delayed(Duration.zero);
    await controller.stop();
    driver.gates[second.url]!.complete();
    await loadingSecond;
    expect(controller.playing, false);
    expect(driver.plays, 0);
    await controller.play();
    expect(driver.active, second);
    expect(controller.playing, true);
    expect(driver.plays, 1);
  });
  test('准备就绪不等待整首音频结束，播放完成自动下一首且停止在队列末尾', () async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    await controller.setQueue([first, second]);
    expect(driver.playback.isCompleted, false);
    expect(controller.phase, MusicPhase.ready);
    expect(controller.playing, true);
    driver.stateEvents.add(const MusicDriverState(MusicPhase.completed, true));
    await Future<void>.delayed(Duration.zero);
    expect(controller.current, second);
    expect(driver.loaded.length, 2);
    driver.stateEvents.add(const MusicDriverState(MusicPhase.completed, true));
    await Future<void>.delayed(Duration.zero);
    expect(controller.current, second);
    expect(controller.playing, false);
  });

  test('失败可重试，seek限制到合法范围，移除当前音频切换并释放本地资源', () async {
    final driver = FakeMusicDriver()..failNextLoad = true;
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    var released = 0;
    final local = MusicTrack(
      url: 'blob:local',
      title: '本地音频',
      release: () => released++,
    );
    await controller.setQueue([local, second]);
    expect(controller.error, contains('断网'));
    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.playing, true);
    await controller.seek(const Duration(seconds: 400));
    expect(driver.lastSeek, const Duration(seconds: 90));
    await controller.skip(-400);
    expect(driver.lastSeek, Duration.zero);
    await controller.removeAt(0);
    expect(controller.current, second);
    expect(released, 1);
  });

  test('系统媒体控制和界面共用队列与播放位置', () async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    final handler = CholrisAudioHandler(controller: controller);
    addTearDown(() {
      handler.detach();
      controller.dispose();
    });
    await controller.setQueue([first, second]);
    expect(handler.mediaItem.value?.title, '第一首');
    await handler.pause();
    expect(controller.playing, false);
    await handler.seek(const Duration(seconds: 12));
    expect(controller.position, const Duration(seconds: 12));
    await handler.skipToNext();
    expect(controller.current, second);
    expect(handler.mediaItem.value?.title, '第二首');
    await handler.skipToPrevious();
    expect(controller.current, first);
  });

  testWidgets('同一播放器切换章节更新资源；离开页面只清除导航回调并继续音频', (tester) async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaPlayerView(
            controller: controller,
            url: first.url,
            title: first.title,
            hasNext: true,
            onNext: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.current?.url, first.url);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaPlayerView(
            controller: controller,
            url: second.url,
            title: second.title,
            hasNext: true,
            onNext: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.current?.url, second.url);
    expect(find.text('第二首'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(controller.nextChapter, isNull);
    expect(controller.playing, true);
  });

  testWidgets('歌词点击定位并高亮当前播放区域', (tester) async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    await controller.setQueue([first]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MusicPlayerPanel(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('lyric-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二句'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(driver.lastSeek, const Duration(seconds: 10));
    final lyrics = tester.widget<LyricsView>(find.byType(LyricsView));
    expect(lyrics.document.indexAt(lyrics.position), 1);
    final selected = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('lyric-1')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(selected.properties.selected, true);
  });

  testWidgets('任意窄矮窗口播放器和音乐页面不溢出', (tester) async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    await controller.setQueue([first, second]);
    for (final size in const [
      Size(240, 280),
      Size(320, 180),
      Size(800, 300),
      Size(1300, 700),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: MusicScreen(controller: controller)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('单曲循环重新从头播放，定时停止可取消', (tester) async {
    final driver = FakeMusicDriver();
    final controller = MusicController(driver: driver);
    addTearDown(controller.dispose);
    await controller.setQueue([first]);
    controller.cycleRepeat();
    controller.cycleRepeat();
    driver.stateEvents.add(const MusicDriverState(MusicPhase.completed, true));
    await tester.pump();
    expect(driver.lastSeek, Duration.zero);
    expect(driver.plays, 2);
    controller.setSleepTimer(const Duration(seconds: 1));
    controller.setSleepTimer(null);
    await tester.pump(const Duration(seconds: 2));
    expect(driver.pauses, 0);
    controller.setSleepTimer(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.playing, false);
    expect(driver.pauses, 1);
  });
}
