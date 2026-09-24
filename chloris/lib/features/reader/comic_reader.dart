import 'package:flutter/material.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../app/widgets/decoded_network_image.dart';
import '../../app/widgets/sharp_network_image.dart';

/// 漫画/图文混排阅读：正文按图片/文本块切分后纵向滚动；底栏上下章。
class ComicReader extends StatelessWidget {
  const ComicReader({
    super.key,
    required this.content,
    required this.chapterTitle,
    this.baseUrl,
    this.source,
    this.book,
    this.hasPrev = false,
    this.hasNext = false,
    this.onPrev,
    this.onNext,
  });

  final String content;
  final String chapterTitle;
  final String? baseUrl;
  final BookSource? source;
  final Book? book;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final blocks = splitContentBlocks(content, baseUrl: baseUrl);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(chapterTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 72),
        itemCount: blocks.length,
        itemBuilder: (context, i) {
          final block = blocks[i];
          if (block.isImage) {
            return InteractiveViewer(
              child: ImageDecoder.decodeJs(source, isCover: false) != null
                  ? DecodedNetworkImage(
                      url: block.value,
                      source: source,
                      book: book,
                      isCover: false,
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                      cacheScale: 2,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    )
                  : SharpNetworkImage(
                      url: block.value,
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                      cacheScale: 2,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              block.value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    height: 1.6,
                  ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: hasPrev ? onPrev : null,
              child: const Text('上一章'),
            ),
            TextButton(
              onPressed: hasNext ? onNext : null,
              child: const Text('下一章'),
            ),
          ],
        ),
      ),
    );
  }
}

bool isMangaContent(String content, {String? baseUrl}) {
  return splitContentBlocks(content, baseUrl: baseUrl).any((b) => b.isImage);
}
