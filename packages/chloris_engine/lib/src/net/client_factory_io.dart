import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createHttpClient() {
  final io = HttpClient()
    ..maxConnectionsPerHost = 32
    ..idleTimeout = const Duration(seconds: 45)
    ..connectionTimeout = const Duration(seconds: 8);
  return IOClient(io);
}
