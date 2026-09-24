import 'package:flutter/material.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/absolutely_widgets.dart';
import 'legal_screen.dart';
import 'legal_texts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = DebugLog.buffer;
    final theme = Theme.of(context);
    final absolutely = theme.extension<AppStyleExtension>()?.style ==
        AppUiStyle.absolutely;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Image.asset(
            'assets/brand/icon.png',
            width: 88,
            height: 88,
            errorBuilder: (_, _, _) => const Icon(Icons.auto_stories, size: 64),
          ),
          const SizedBox(height: 12),
          Text(
            'Chloris',
            textAlign: TextAlign.center,
            style: absolutely
                ? theme.textTheme.headlineMedium
                : const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '版本 0.1.0+1',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // Absolutely: the divider grid carries the three metadata columns —
          // no boxes, hairline rules only (风格全集 §5.2).
          if (absolutely) ...[
            const SizedBox(height: 20),
            const AbsolutelyDividerGrid(
              columns: 3,
              children: [
                _AboutFact(title: '版本', value: '0.1.0+1'),
                _AboutFact(title: '许可', value: 'GPL-3.0'),
                _AboutFact(title: '血统', value: 'legado-E'),
              ],
            ),
            const SizedBox(height: 20),
          ],
          Text('介绍', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(LegalTexts.aboutIntro, style: TextStyle(height: 1.65)),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('检查更新'),
            subtitle: const Text('当前 0.1.0+1 · Web 端请拉取最新 build/web'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前已是本机构建版本 0.1.0+1，未配置远程更新通道')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('调试日志'),
            subtitle: Text('${logs.length} 条'),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('调试日志'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 320,
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) => Text(
                      '${logs[i].stamp} ${logs[i].tag} · ${logs[i].message}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('开源许可'),
            subtitle: Text('GPL-3.0（参考 legado-E）'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text('免责声明与隐私'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// One hairline-grid cell in the Absolutely about header.
class _AboutFact extends StatelessWidget {
  const _AboutFact({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
