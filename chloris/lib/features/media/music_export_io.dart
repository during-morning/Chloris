import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'audio_file_store.dart';
import '../../services/export_filename.dart';

Future<void> saveMusicBytes(Uint8List bytes, String name) async {
  final path = await FilePicker.saveFile(
    fileName: name,
    bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
  );
  if (path != null && !Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}

Future<void> exportStoredMusic(
  AudioFileStore store,
  String key,
  String name, {
  Rect? origin,
}) async {
  final stored = await store.open(key);
  final file = File.fromUri(Uri.parse(stored.url));
  if (Platform.isAndroid || Platform.isIOS) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        fileNameOverrides: [sanitizeForFileName(name)],
        sharePositionOrigin: origin,
      ),
    );
  } else {
    final destination = await FilePicker.saveFile(
      fileName: sanitizeForFileName(name),
    );
    if (destination != null) await store.exportFile(key, destination);
  }
}

Future<void> exportMusicBundle(
  AudioFileStore store,
  List<String> keys,
  Map<String, dynamic> metadata,
  String name, {
  Rect? origin,
}) async {
  final filename = '${sanitizeForFileName(name)}.zip';
  if (Platform.isAndroid || Platform.isIOS) {
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/music-share',
    ).create(recursive: true);
    // Retain the shared file while the receiving application reads it. The OS
    // manages the temporary directory; persistent downloads remain separate.
    final destination =
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-$filename';
    await store.exportBundle(keys, metadata, destination);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(destination)],
        fileNameOverrides: [filename],
        sharePositionOrigin: origin,
      ),
    );
  } else {
    final destination = await FilePicker.saveFile(fileName: filename);
    if (destination != null)
      await store.exportBundle(keys, metadata, destination);
  }
}
