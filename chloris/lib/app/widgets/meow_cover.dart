import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'decoded_network_image.dart';
import 'sharp_network_image.dart';

class MeowCover extends StatelessWidget {
  const MeowCover({
    super.key,
    required this.title,
    this.imageUrl,
    this.height = 238,
    this.source,
    this.book,
  });

  final String title;
  final String? imageUrl;
  final double height;
  final BookSource? source;
  final Book? book;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = title.isEmpty ? '书' : String.fromCharCode(title.runes.first);
    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: cs.secondaryContainer,
              child: Center(
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                ),
              ),
            ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ImageDecoder.decodeJs(source, isCover: true) != null
                  ? DecodedNetworkImage(
                      url: imageUrl!,
                      source: source,
                      book: book,
                      isCover: true,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : SharpNetworkImage(
                      url: proxiedImageUrl(imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
          ],
        ),
      ),
    );
  }
}

String proxiedImageUrl(String url) {
  if (!kIsWeb) return url;
  final u = url.trim();
  if (u.isEmpty) return u;
  if (u.startsWith('data:') || u.startsWith('blob:') || u.startsWith('/')) {
    return u;
  }
  if (u.contains('/proxy/img')) return u;
  return Uri.parse(Uri.base.origin)
      .replace(path: '/proxy/img', queryParameters: {'u': u}).toString();
}
