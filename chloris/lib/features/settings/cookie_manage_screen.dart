import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class CookieManageScreen extends ConsumerStatefulWidget {
  const CookieManageScreen({super.key});

  @override
  ConsumerState<CookieManageScreen> createState() => _CookieManageScreenState();
}

class _CookieManageScreenState extends ConsumerState<CookieManageScreen> {
  @override
  Widget build(BuildContext context) {
    final store = ref.read(cookieStoreProvider);
    final map = store.snapshot();
    final keys = map.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cookie 管理'),
        actions: [
          if (keys.isNotEmpty)
            TextButton(
              onPressed: () {
                for (final k in List<String>.from(keys)) {
                  store.remove(k);
                }
                setState(() {});
              },
              child: const Text('全部清除'),
            ),
        ],
      ),
      body: keys.isEmpty
          ? const Center(child: Text('还没有保存的 Cookie'))
          : ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, i) {
                final k = keys[i];
                final v = map[k] ?? '';
                return ListTile(
                  title: Text(k),
                  subtitle: Text(
                    v,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: v));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制 Cookie')),
                      );
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      store.remove(k);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
