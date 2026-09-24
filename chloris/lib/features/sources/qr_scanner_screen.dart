import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'source_library_provider.dart';

/// 扫码导入书源（匹配书源 JSON 数组）。
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    final sources = _tryParseSources(raw);
    if (sources.isNotEmpty) {
      ref.read(importedSourcesProvider.notifier).addAll(sources);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${sources.length} 条书源')),
      );
      Navigator.of(context).pop();
    } else {
      final display = raw.length > 120 ? raw.substring(0, 120) : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别内容（非书源数组）：$display')),
      );
    }
  }

  List<BookSource> _tryParseSources(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return BookSource.listFromJson(decoded);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码导入书源'), actions: [
        IconButton(icon: const Icon(Icons.stop), onPressed: () => Navigator.pop(context)),
      ]),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
