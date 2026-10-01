import 'dart:typed_data';

final Map<String, Uint8List> _memory = {};

Future<bool> write(String key, Uint8List bytes) async {
  _memory[key] = bytes;
  return true;
}

Future<Uint8List?> read(String key) async => _memory[key];
Future<void> delete(String key) async => _memory.remove(key);
