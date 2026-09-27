import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'channel_ws_connect_stub.dart'
    if (dart.library.io) 'channel_ws_connect_io.dart' as ws;

/// Flutter IO/Web adapter for the engine's platform-neutral socket port.
class ChannelWsPort implements WsPort {
  const ChannelWsPort();

  @override
  Future<WsConnection> connect(WsRequestSpec spec) async {
    final channel = ws.connectChannel(spec.uri, spec.headers);
    await channel.ready;
    return _ChannelWsConnection(channel);
  }
}

final class _ChannelWsConnection implements WsConnection {
  _ChannelWsConnection(this._channel);
  final WebSocketChannel _channel;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);
}
