import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/absolutely_widgets.dart';
import '../../app/widgets/meow.dart';
import '../../core/persist/kv_settings.dart';
import 'legal_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onAccepted});

  final VoidCallback? onAccepted;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _legal = false;

  Future<void> _accept() async {
    final p = await KvSettings.ready();
    await p.setBool('welcomeAccepted', true);
    widget.onAccepted?.call();
    if (mounted && widget.onAccepted == null) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.colorScheme;
    final ext = theme.extension<AppStyleExtension>();
    final mono = ext?.mono ?? false;
    final absolutely = ext?.style == AppUiStyle.absolutely;
    final can = _legal;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('新手引导')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              if (mono)
                Text(
                  '>_',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: palette.onSurface,
                  ),
                )
              else
                Image.asset(
                  'assets/brand/icon.png',
                  width: absolutely ? 72 : 96,
                  height: absolutely ? 72 : 96,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.auto_stories,
                    size: 72,
                    color: palette.onSurfaceVariant,
                  ),
                ),
              SizedBox(height: absolutely ? AppTokens.space24 : 20),
              Text(
                mono ? '[ 欢迎使用 Cholris ]' : '欢迎使用 Cholris',
                textAlign: TextAlign.center,
                // Absolutely: the welcome hero uses the display serif.
                style: absolutely
                    ? theme.textTheme.displaySmall
                    : theme.textTheme.headlineMedium,
              ),
              SizedBox(height: absolutely ? AppTokens.space12 : 12),
              Text(
                '跨平台开源阅读器，不提供书籍内容。书源、规则与风险由你自行承担。使用前请读完免责声明。',
                textAlign: TextAlign.center,
                // Absolutely: serif editorial subtitle.
                style: absolutely
                    ? AppTheme.absolutelySubtitle(theme)
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: palette.onSurfaceVariant,
                      ),
              ),
              const SizedBox(height: AppTokens.space16),
              const MeowRule(),
              const SizedBox(height: AppTokens.space8),
              CheckboxListTile(
                value: _legal,
                onChanged: (v) => setState(() => _legal = v ?? false),
                title: const Text('已阅读免责声明：使用第三方书源的风险由用户自行承担。'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              if (absolutely) ...[
                // Clay poster moment — the trailer 字卡 grammar, one per flow.
                AbsolutelyBannerCard(
                  title: 'Cholris',
                  subtitle: '你的阅读空间，由你自己定义。',
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: can ? _accept : null,
                child: const Text('开始使用'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
