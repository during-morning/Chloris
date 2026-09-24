import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<void> openPdfBytes(BuildContext context, Uint8List bytes, String name) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('本平台暂不内嵌 PDF，请用系统阅读器打开 $name')),
  );
}
