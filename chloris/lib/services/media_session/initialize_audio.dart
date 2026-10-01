import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';

bool _registered = false;
Future<void>? _configured;

/// 驱动自行确保桌面后端已注册，不依赖启动时的异步媒体会话初始化。
void ensureAudioBackendRegistered() {
  if (_registered) return;
  if (!kIsWeb) MediaKit.ensureInitialized();
  JustAudioMediaKit.title = 'Cholris';
  JustAudioMediaKit.ensureInitialized();
  _registered = true;
}

/// Windows/Linux 使用 media-kit，移动端和 macOS 保留原生 just_audio。
Future<void> initializeAudioBackend() {
  ensureAudioBackendRegistered();
  return _configured ??= _configureSession();
}

Future<void> _configureSession() async {
  if (!kIsWeb) {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      _configured = null;
      rethrow;
    }
  }
}
