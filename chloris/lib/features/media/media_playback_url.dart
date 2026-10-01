import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Browser media elements cannot send a source's Referer or Cookie headers.
/// The same-origin streaming proxy supplies them and preserves byte ranges.
String mediaPlaybackUrl(String url, Map<String, String> headers) {
  final uri = Uri.tryParse(url);
  if (!kIsWeb ||
      headers.isEmpty ||
      uri == null ||
      !['http', 'https'].contains(uri.scheme)) {
    return url;
  }
  return Uri.base
      .resolve('/proxy/media')
      .replace(
        queryParameters: {
          'url': url,
          'headers': jsonEncode(headers),
          if (Uri.base.queryParameters['token'] != null)
            'token': Uri.base.queryParameters['token']!,
        },
      )
      .toString();
}
