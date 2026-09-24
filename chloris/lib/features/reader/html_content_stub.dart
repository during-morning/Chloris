import 'package:flutter/widgets.dart';

/// Cross-platform fallback. Web uses the DOM renderer implementation.
class HtmlContentView extends StatelessWidget {
  const HtmlContentView({super.key, required this.htmlContent, required this.css});

  final String htmlContent;
  final String css;

  @override
  Widget build(BuildContext context) => Text(
        _plain(htmlContent),
      );

  static String _plain(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>|</div>|</h[1-6]>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
