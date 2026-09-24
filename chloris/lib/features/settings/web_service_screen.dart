import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rules/replace_rules_controller.dart';
import '../../features/sources/source_library_provider.dart';
import '../../services/web/web_service_controller.dart';

class WebServiceScreen extends ConsumerWidget {
  const WebServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(webServiceControllerProvider);
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Web 服务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kIsWeb) ...[
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('当前为浏览器端'),
              subtitle: Text(
                '本页无法在浏览器里再开 1234 端口。同源代理已由 dart run tool/serve_web.dart 提供（默认 2328）。',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('代理 POST /proxy/http'),
              subtitle: const Text('书源请求走同源转发'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: '/proxy/http'),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制路径')));
                  }
                },
              ),
            ),
          ] else ...[
            SwitchListTile(
              title: const Text('启动 HTTP/WS 接口'),
              subtitle: Text(
                st.running
                    ? ('运行中 · ' + st.port.toString())
                    : (st.error ?? '未启动'),
              ),
              value: st.running,
              onChanged: (v) async {
                final c = ref.read(webServiceControllerProvider.notifier);
                v ? await c.start() : await c.stop();
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('复制全部书源 JSON'),
            onTap: () async {
              final list = await ref.read(allSourcesProvider.future);
              final json = const JsonEncoder.withIndent(
                '  ',
              ).convert(list.map((e) => e.toJson()).toList());
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制 ' + list.length.toString() + ' 条书源'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('复制净化规则 JSON'),
            onTap: () async {
              final list = ref.read(replaceRulesProvider);
              final json = const JsonEncoder.withIndent(
                '  ',
              ).convert(list.map((e) => e.toJson()).toList());
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制净化规则')));
              }
            },
          ),
        ],
      ),
    );
  }
}
