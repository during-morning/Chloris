import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../features/media/music_export.dart';
import 'export_filename.dart';

bool get bookExportUsesOtherApps =>
    !kIsWeb &&
    const [
      TargetPlatform.android,
      TargetPlatform.iOS,
    ].contains(defaultTargetPlatform);
String get bookExportLabel => bookExportUsesOtherApps ? '其他应用打开' : '保存到本地';
Uint8List buildDownloadedBook(Map<String, Object> input) {
  final text = StringBuffer()
    ..writeln(input['name'])
    ..writeln(input['author'])
    ..writeln();
  final titles = (input['titles'] as List).cast<String>(),
      contents = (input['contents'] as List).cast<String>();
  for (var i = 0; i < contents.length; i++) {
    text
      ..writeln(titles[i])
      ..writeln()
      ..writeln(contents[i])
      ..writeln();
  }
  return Uint8List.fromList(utf8.encode(text.toString()));
}

Future<void> exportDownloadedBook(
  Uint8List bytes,
  String name,
  String author, {
  Rect? sharePositionOrigin,
}) async {
  final fileName =
      '${applyExportTemplate(kDefaultExportFileNameTemplate, name, author)}.txt';
  if (bookExportUsesOtherApps) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/plain', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } else {
    await saveMusicBytes(bytes, fileName);
  }
}
