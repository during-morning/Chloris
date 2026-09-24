import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<void> openPdfBytes(BuildContext context, Uint8List bytes, String name) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
