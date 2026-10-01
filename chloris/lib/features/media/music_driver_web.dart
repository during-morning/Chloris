import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'music_controller.dart';

@JS('chlorisMusicAudio')
external JSObject get _audio;

class WebMusicDriver implements MusicPlayerDriver {
  WebMusicDriver() {
    _audio.callMethod(
      'attach'.toJS,
      ((JSString type, JSString json) {
        final data = jsonDecode(json.toDart);
        switch (type.toDart) {
          case 'position':
            _positions.add(Duration(milliseconds: (data as num).toInt()));
          case 'duration':
            _durations.add(
              data == null
                  ? null
                  : Duration(milliseconds: (data as num).toInt()),
            );
          case 'error':
            _errors.add(StateError('$data'));
          case 'state':
            _states.add(
              MusicDriverState(
                MusicPhase.values.firstWhere((e) => e.name == data['phase']),
                data['playing'] == true,
              ),
            );
        }
      }).toJS,
    );
  }
  final _states = StreamController<MusicDriverState>.broadcast(),
      _positions = StreamController<Duration>.broadcast(),
      _durations = StreamController<Duration?>.broadcast(),
      _errors = StreamController<Object>.broadcast();
  @override
  Stream<MusicDriverState> get states => _states.stream;
  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<Duration?> get durations => _durations.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  Future<void> _async(String method, JSAny? arg) async {
    await (_audio.callMethod(method.toJS, arg) as JSPromise<JSAny?>).toDart;
  }

  @override
  Future<void> load(MusicTrack t) => _async(
    'load',
    jsonEncode({
      'urls': t.segments.isEmpty
          ? [t.url]
          : t.segments.map((s) => s.request.url).toList(),
      'durations': t.segments.isEmpty
          ? [null]
          : t.segments
                .map(
                  (s) => s.duration == null
                      ? null
                      : s.duration!.inMilliseconds / 1000,
                )
                .toList(),
      'hls': t.mimeType.contains('mpegurl') || t.url.contains('.m3u8'),
    }).toJS,
  );
  @override
  Future<void> play() => _async('play', null);
  @override
  Future<void> pause() async {
    _audio.callMethod('pause'.toJS);
  }

  @override
  Future<void> stop() async {
    _audio.callMethod('stop'.toJS);
  }

  @override
  Future<void> seek(Duration p) => _async('seek', p.inMilliseconds.toJS);
  @override
  Future<void> setSpeed(double s) async {
    _audio.callMethod('speed'.toJS, s.toJS);
  }

  @override
  Future<void> setVolume(double s) async {
    _audio.callMethod('volume'.toJS, s.toJS);
  }

  @override
  Future<void> dispose() async {
    _audio.callMethod('dispose'.toJS);
    await Future.wait([
      _states.close(),
      _positions.close(),
      _durations.close(),
      _errors.close(),
    ]);
  }
}

MusicPlayerDriver createMusicDriver() => WebMusicDriver();
