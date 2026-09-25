import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';

/// Platform-neutral WebSocket request/response transport. Implementations live
/// outside the engine so the rule layer remains usable on IO and Web targets.
abstract interface class WsPort {
  Future<WsConnection> connect(WsRequestSpec spec);
}

class WsRequestSpec {
  const WsRequestSpec({
    required this.uri,
    this.headers = const {},
    this.timeout,
    this.session,
  });

  final Uri uri;
  final Map<String, String> headers;
  final Duration? timeout;
  final String? session;
}

abstract interface class WsConnection {
  Stream<Object?> get messages;
  void send(String message);
  Future<void> close([int? code, String? reason]);
}

/// Minimal fake used by protocol and application tests.
class ScriptedWsPort implements WsPort {
  ScriptedWsPort({this.onConnect});

  final FutureOr<List<Object?>> Function(WsRequestSpec spec, String message)?
  onConnect;
  final connected = <WsRequestSpec>[];
  final sent = <String>[];

  @override
  Future<WsConnection> connect(WsRequestSpec spec) async {
    connected.add(spec);
    final controller = StreamController<Object?>();
    late final _ScriptedConnection connection;
    connection = _ScriptedConnection(controller, sent, (message) async {
      final replies = await onConnect?.call(spec, message) ?? const [];
      for (final reply in replies) {
        if (!controller.isClosed) controller.add(reply);
      }
    });
    return connection;
  }
}

final class _ScriptedConnection implements WsConnection {
  _ScriptedConnection(this._controller, this._sent, this._reply);
  final StreamController<Object?> _controller;
  final List<String> _sent;
  final Future<void> Function(String) _reply;

  @override
  Stream<Object?> get messages => _controller.stream;

  @override
  void send(String message) {
    _sent.add(message);
    unawaited(_reply(message));
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    await _controller.close();
  }
}
