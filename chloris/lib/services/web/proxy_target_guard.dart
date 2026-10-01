import 'dart:io';

/// Rejects local, private and non-routable proxy destinations by default.
bool isBlockedProxyHost(String host, {bool allowPrivate = false}) {
  if (allowPrivate) return false;
  final h = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  if (h.isEmpty ||
      h == 'localhost' ||
      h.endsWith('.localhost') ||
      h.endsWith('.local')) {
    return true;
  }
  final address = InternetAddress.tryParse(h);
  if (address == null) return false; // DNS results must also be checked.
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 0 ||
        bytes[0] == 10 ||
        bytes[0] == 127 ||
        (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 0) ||
        (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 2) ||
        (bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19)) ||
        (bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100) ||
        (bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113) ||
        bytes[0] >= 224;
  }
  // IPv4-mapped IPv6 must obey the same IPv4 policy.
  if (bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff) {
    return isBlockedProxyHost(bytes.skip(12).join('.'));
  }
  // Public IPv6 global unicast is 2000::/3. This excludes loopback,
  // unspecified, link-local, unique-local, multicast and translation ranges.
  if ((bytes[0] & 0xe0) != 0x20) return true;
  if (bytes[0] == 0x20 && bytes[1] == 0x01) {
    // Documentation and Teredo addresses are not direct public destinations.
    if ((bytes[2] == 0x0d && bytes[3] == 0xb8) ||
        (bytes[2] == 0 && bytes[3] == 0)) {
      return true;
    }
  }
  if (bytes[0] == 0x20 && bytes[1] == 0x02) {
    // A 6to4 address embeds its IPv4 gateway.
    return isBlockedProxyHost(bytes.sublist(2, 6).join('.'));
  }
  return false;
}

String? proxyTargetError(String url, {bool allowPrivate = false}) {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return 'invalid url';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'unsupported scheme: ${uri.scheme}';
    }
    if (uri.userInfo.isNotEmpty || uri.port <= 0 || uri.port > 65535) {
      return 'invalid url';
    }
    if (isBlockedProxyHost(uri.host, allowPrivate: allowPrivate)) {
      return 'target host is not routable: ${uri.host}';
    }
    return null;
  } on FormatException {
    return 'invalid url';
  }
}
