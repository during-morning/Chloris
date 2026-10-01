import '../media/audio_focus.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TTS 朗读状态。
enum TtsStatus {
  /// 未开始 / 已停止。
  stopped,

  /// 正在朗读。
  playing,

  /// 已暂停（停留在当前句）。
  paused,
}

/// TTS 控制器对外暴露的状态快照。
class TtsState {
  const TtsState({
    this.status = TtsStatus.stopped,
    this.index = 0,
    this.total = 0,
    this.currentSentence = '',
  });

  /// 当前正在朗读（或暂停时停留）的句子下标。
  final TtsStatus status;
  final int index;

  /// 本章句子总数。
  final int total;
  final String currentSentence;

  TtsState copyWith({
    TtsStatus? status,
    int? index,
    int? total,
    String? currentSentence,
  }) => TtsState(
    status: status ?? this.status,
    index: index ?? this.index,
    total: total ?? this.total,
    currentSentence: currentSentence ?? this.currentSentence,
  );

  /// 当前朗读进度（0~1）。
  double get progress => total <= 0 ? 0.0 : (index + 1) / total;
}

/// 运行期平台判断：flutter_tts 在 Web 上支持有限，基础版仅在非 Web 平台启用。
bool ttsPlatformSupported() => !kIsWeb;

/// 按句切分章节文本，保留句末标点，便于句间逐句推进。
List<String> _splitSentences(String text) {
  if (text.isEmpty) return const [];
  // 中英文句末标点 + 换行均作为切分点；连续标点合并到同一句尾。
  final delim = RegExp(r'[。！？!?；;…\n\r]+');
  final parts = <String>[];
  var start = 0;
  for (final m in delim.allMatches(text)) {
    final piece = text.substring(start, m.end).trim();
    if (piece.isNotEmpty) parts.add(piece);
    start = m.end;
  }
  final tail = text.substring(start).trim();
  if (tail.isNotEmpty) parts.add(tail);
  return parts;
}

final ttsControllerProvider = NotifierProvider<TtsController, TtsState>(
  TtsController.new,
);

/// 系统 TTS 朗读控制器（对齐 legado 系统朗读，不含后台服务）。
///
/// 输入全文文本，按句逐句 speak，句间无停顿；监听 completion 自动推进下一句，
/// 全部读完后调用调用方注册的 [onNextChapter] 实现「播完自动翻章」。
class TtsController extends Notifier<TtsState> {
  final FlutterTts _tts = FlutterTts();
  List<String> _sentences = const [];
  VoidCallback? _onNextChapter;
  bool _disposed = false;

  @override
  TtsState build() {
    AudioFocusCoordinator.instance.register('tts',() async { stop(); });
    _configure();
    ref.onDispose(() {
      AudioFocusCoordinator.instance.unregister('tts');
      _disposed = true;
      _safe(() => _tts.stop());
    });
    return const TtsState();
  }

  void _configure() {
    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(_onComplete);
    _tts.setErrorHandler((_) => stop());
    _tts.setCancelHandler(() {});
    // 中文朗读参数；部分平台可能无对应语音，失败也不影响主流程。
    _safe(() => _tts.setLanguage('zh-CN'));
    _safe(() => _tts.setSpeechRate(0.5));
    _safe(() => _tts.setPitch(1.0));
    _safe(() => _tts.setVolume(1.0));
  }

  /// 吞掉平台不支持的配置异常 / 异步错误，避免影响主流程。
  void _safe(Future<Object?> Function() fn) {
    try {
      fn().catchError((_) => null);
    } catch (_) {
      // 忽略同步异常。
    }
  }

  void _onComplete() {
    if (_disposed || state.status == TtsStatus.stopped || _sentences.isEmpty) {
      return;
    }
    final next = state.index + 1;
    if (next < _sentences.length) {
      state = state.copyWith(
        index: next,
        status: TtsStatus.playing,
        currentSentence: _sentences[next],
      );
      _speak(_sentences[next]);
    } else {
      // 本章读尽：复位并回调翻章。
      final cb = _onNextChapter;
      state = const TtsState();
      cb?.call();
    }
  }

  Future<void> _speak(String text) async {
    if (_disposed) return;
    try {
      if (!await AudioFocusCoordinator.instance.acquire('tts')) return;
      await _tts.speak(text);
    } catch (_) {
      // 朗读失败：复位，避免卡在 playing。
      state = const TtsState();
    }
  }

  /// 开始朗读【全文文本】；播完最后一句话会调用 [onNextChapter] 实现自动翻章。
  void start(String text, {VoidCallback? onNextChapter}) {
    if (_disposed) return;
    _safe(() => _tts.stop());
    _onNextChapter = onNextChapter;
    _sentences = _splitSentences(text);
    if (_sentences.isEmpty) {
      state = const TtsState();
      return;
    }
    state = TtsState(
      status: TtsStatus.playing,
      index: 0,
      total: _sentences.length,
      currentSentence: _sentences[0],
    );
    _speak(_sentences[0]);
  }

  /// 暂停（停留在当前句）。
  void pause() {
    if (state.status != TtsStatus.playing) return;
    _safe(() => _tts.pause());
    state = state.copyWith(status: TtsStatus.paused);
  }

  /// 从暂停处继续朗读当前句。
  void resume() {
    if (state.status != TtsStatus.paused) return;
    state = state.copyWith(status: TtsStatus.playing);
    if (_sentences.isNotEmpty) _speak(_sentences[state.index]);
  }

  /// 停止并复位（不触发翻章回调）。
  void stop() {
    _safe(() => _tts.stop());
    _sentences = const [];
    _onNextChapter = null;
    state = const TtsState();
  }
}
