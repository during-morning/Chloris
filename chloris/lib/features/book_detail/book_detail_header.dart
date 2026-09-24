import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/meow.dart';

class BookDetailTocSkeleton extends StatelessWidget {
  const BookDetailTocSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        0,
        AppTokens.space16,
        AppTokens.space16,
      ),
      child: Column(
        children: [
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
              child: Container(
                height: AppTokens.space12,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radius8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String plainBookIntro(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return raw;
  if (!(t.contains('<') && (t.contains('</') || t.contains('<br') || t.contains('<p')))) {
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  final doc = html_parser.parse(t);
  return (doc.body?.text ?? t).replaceAll(RegExp(r'\s+'), ' ').trim();
}

class BookDetailHeader extends StatefulWidget {
  const BookDetailHeader({
    required this.source,
    required this.book,
    this.onAuthorTap,
    this.progress,
  });
  final BookSource source;
  final Book book;
  final VoidCallback? onAuthorTap;
  final String? progress;

  @override
  State<BookDetailHeader> createState() => _BookDetailHeaderState();
}

class _BookDetailHeaderState extends State<BookDetailHeader> {
  bool _introOpen = false;
  String _introRaw = '';
  String _introPlain = '';

  String _introText(String raw) {
    if (raw == _introRaw) return _introPlain;
    _introRaw = raw;
    _introPlain = plainBookIntro(raw);
    return _introPlain;
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final onAuthorTap = widget.onAuthorTap;
    final progress = widget.progress;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 118,
                child: MeowCover(
                  title: book.name,
                  imageUrl: book.coverUrl,
                  height: 118,
                  source: widget.source,
                  book: book,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onAuthorTap,
                      child: Text(
                        book.author,
                        style: TextStyle(
                          color: cs.primary,
                          decoration: onAuthorTap == null
                              ? null
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                    if ((book.kind ?? '').isNotEmpty)
                      Text(book.kind!, style: TextStyle(color: cs.onSurfaceVariant)),
                    if (book.originName.isNotEmpty)
                      Text(
                        book.originName,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (progress != null && progress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          progress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.primary, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if ((book.intro ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _introOpen = !_introOpen),
              child: Text(
                _introText(book.intro!),
                maxLines: _introOpen ? 40 : 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _introOpen = !_introOpen),
              child: Text(_introOpen ? '收起简介' : '展开简介'),
            ),
          ],
        ],
      ),
    );
  }
}

