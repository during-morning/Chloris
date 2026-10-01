import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:file_picker/file_picker.dart';
import 'audio_file_store.dart';
import '../../services/export_filename.dart';

Future<void> saveMusicBytes(Uint8List bytes, String name) async {
  await FilePicker.saveFile(fileName: name, bytes: bytes);
}

Future<void> exportStoredMusic(
  AudioFileStore store,
  String key,
  String name, {
  Rect? origin,
}) => store.exportFile(key, sanitizeForFileName(name));
Future<void> exportMusicBundle(
  AudioFileStore store,
  List<String> keys,
  Map<String, dynamic> metadata,
  String name, {
  Rect? origin,
}) => store.exportBundle(keys, metadata, '${sanitizeForFileName(name)}.zip');
