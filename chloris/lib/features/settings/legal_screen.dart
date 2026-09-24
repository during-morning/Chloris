import 'package:flutter/material.dart';

import 'legal_texts.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('免责声明与隐私')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('免责声明', style: theme.titleLarge),
          const SizedBox(height: 8),
          const Text(LegalTexts.legalDisclaimer, style: TextStyle(height: 1.7)),
          const SizedBox(height: 24),
          Text('隐私', style: theme.titleLarge),
          const SizedBox(height: 8),
          const Text(LegalTexts.privacy, style: TextStyle(height: 1.7)),
          const SizedBox(height: 24),
          Text('开源许可', style: theme.titleLarge),
          const SizedBox(height: 8),
          const Text(LegalTexts.license, style: TextStyle(height: 1.7)),
        ],
      ),
    );
  }
}
