import 'dart:typed_data';
import 'package:flutter/material.dart';

class PdfViewer extends StatelessWidget {
  const PdfViewer({super.key, required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
  @override
  Widget build(BuildContext context) => Center(child: Text('当前平台不支持内嵌 PDF: $name'));
}
