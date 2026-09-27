import 'package:web_socket_channel/web_socket_channel.dart';

/// Browser WebSocket cannot attach arbitrary HTTP headers during the
/// handshake. The server-side token is therefore handled by the HTTP/session
/// layer; keep the transport compatible with the browser API here.
WebSocketChannel connectChannel(Uri uri, Map<String, String> headers) =>
    WebSocketChannel.connect(uri);
