import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _nextPdfView = 0;

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key, required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late final String _viewType;
  var _openedExternally = false;
  double _zoom = 1;
  late final String _url;
  @override
  void initState() {
    super.initState();
    _viewType = 'chloris-pdf-view-${_nextPdfView++}';
    final blob = html.Blob([widget.bytes], 'application/pdf');
    _url = html.Url.createObjectUrlFromBlob(blob);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) =>
      html.IFrameElement()..src = _url..style.border = '0'..style.width = '100%'..style.height = '100%');
  }
  @override
  void dispose() {
    html.Url.revokeObjectUrl(_url);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.picture_as_pdf_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.name} · ${(widget.bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB', overflow: TextOverflow.ellipsis)),
                IconButton(tooltip: '缩小', icon: const Icon(Icons.zoom_out), onPressed: _zoom > .5 ? () => setState(() => _zoom -= .1) : null),
                Text('${(_zoom * 100).round()}%', style: const TextStyle(fontSize: 12)),
                IconButton(tooltip: '放大', icon: const Icon(Icons.zoom_in), onPressed: _zoom < 2 ? () => setState(() => _zoom += .1) : null),
                IconButton(
                  tooltip: '新窗口打开',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    html.window.open(_url, '_blank');
                    if (mounted) setState(() => _openedExternally = true);
                  },
                ),
                if (_openedExternally)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle_outline, size: 18),
                  ),
                IconButton(
                  tooltip: '下载 PDF',
                  icon: const Icon(Icons.download),
                  onPressed: () => (html.AnchorElement(href: _url)
                    ..download = '${widget.name}.pdf')
                    .click(),
                ),
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 2,
              child: Transform.scale(
                scale: _zoom,
                alignment: Alignment.topCenter,
                child: HtmlElementView(viewType: _viewType),
              ),
            ),
          ),
        ],
      );
}
