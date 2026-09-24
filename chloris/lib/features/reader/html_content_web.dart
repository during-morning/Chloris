import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _nextHtmlView = 0;

/// Browser DOM renderer used for every readable HTML document on Web.
class HtmlContentView extends StatefulWidget {
  const HtmlContentView({
    super.key,
    required this.htmlContent,
    required this.css,
  });

  final String htmlContent;
  final String css;

  @override
  State<HtmlContentView> createState() => _HtmlContentViewState();
}

class _HtmlContentViewState extends State<HtmlContentView> {
  late final String _viewType;
  late html.DivElement _host;

  @override
  void initState() {
    super.initState();
    _viewType = 'chloris-html-view-${_nextHtmlView++}';
    _host = _buildHost();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _host);
  }

  @override
  void didUpdateWidget(covariant HtmlContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent || oldWidget.css != widget.css) {
      _updateHost();
    }
  }

  void _updateHost() {
    final safe = _sanitize(widget.htmlContent);
    final css = widget.css.replaceAll('</style', '<\\/style');
    _host.setInnerHtml(
      '<style>$css</style><div class="chloris-reader-article">$safe</div>',
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
  }

  String _sanitize(String source) {
    final doc = html.DocumentFragment.html(source);
    for (final node in doc.querySelectorAll('script, iframe, object, embed, form, link, style, base')) {
      node.remove();
    }
    for (final node in doc.querySelectorAll('*')) {
      for (final name in node.attributes.keys.toList()) {
        final lower = name.toLowerCase();
        final value = node.attributes[name]?.trim().toLowerCase() ?? '';
        if (lower.startsWith('on') ||
            lower == 'srcdoc' ||
            (lower == 'style' && value.contains('expression(')) ||
            ((lower == 'href' || lower == 'src' || lower == 'xlink:href') &&
                (value.startsWith('javascript:') || value.startsWith('vbscript:') || value.startsWith('data:text/html') || value.startsWith('data:image/svg+xml')))) {
          node.attributes.remove(name);
        }
      }
    }
    return doc.innerHtml ?? '';
  }

  html.DivElement _buildHost() {
    final host = html.DivElement();
    host.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('overflow', 'hidden')
      ..setProperty('user-select', 'none')
      ..setProperty('-webkit-user-select', 'none')
      ..setProperty('background-color', 'transparent')
      ..setProperty('font-smooth', 'always')
      ..setProperty('-webkit-font-smoothing', 'antialiased')
      ..setProperty('text-rendering', 'optimizeLegibility')
      ..setProperty('contain', 'layout paint style');
    final style = html.StyleElement()..text = widget.css;
    final article = html.DivElement()
      ..classes.add('chloris-reader-article')
      ..setInnerHtml(_sanitize(widget.htmlContent), treeSanitizer: html.NodeTreeSanitizer.trusted);
    host.children.add(style);
    host.children.add(article);
    return host;
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
