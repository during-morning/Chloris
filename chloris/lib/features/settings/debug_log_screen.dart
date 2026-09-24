import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = DebugLog.buffer;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('日志（' + logs.length.toString() + '）'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              DebugLog.clear();
              setState(() {});
            },
          ),
          IconButton(
            tooltip: '复制',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final text = logs
                  .map((e) => e.stamp + ' ' + e.tag + ' ' + e.message)
                  .join('\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制日志')));
              }
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('暂无日志'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final e = logs[logs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    e.stamp + ' [' + e.tag + '] ' + e.message,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}
