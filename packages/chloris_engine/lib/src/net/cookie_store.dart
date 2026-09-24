class CookieStore {
  final Map<String, String> _map = {};

  /// Fired after [set] / [mergeSetCookie] / [remove] with the domain key.
  void Function(String domain, String cookie)? onChange;

  void _emit(String domain) {
    onChange?.call(domain, _map[domain] ?? '');
  }

  String get(String url) => _map[domainOf(url)] ?? '';

  String getKey(String url, String key) {
    final cookie = get(url);
    for (final part in cookie.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length >= 2 && kv.first.trim() == key) {
        return kv.sublist(1).join('=');
      }
    }
    return '';
  }

  void set(String url, String? cookie) {
    final domain = domainOf(url);
    if (cookie == null || cookie.isEmpty) {
      _map.remove(domain);
    } else {
      _map[domain] = cookie;
    }
    _emit(domain);
  }

  void mergeSetCookie(String url, String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return;
    final domain = domainOf(url);
    final incoming = <String, String>{};
    // A Set-Cookie header may contain an Expires date with a comma. Split only
    // when the following token is another cookie name, or at header newlines.
    final records = setCookie.split(
      RegExp(r",(?=\s*[A-Za-z0-9!#$%&'*+.^_~-]+=)|\r?\n"),
    );
    final removals = <String>{};
    for (final part in records) {
      final fields = part.split(';');
      final first = fields.first;
      final eq = first.indexOf('=');
      if (eq > 0) {
        final key = first.substring(0, eq).trim();
        final value = first.substring(eq + 1).trim();
        final expired = fields.skip(1).any((field) {
          final lower = field.trim().toLowerCase();
          if (lower == 'max-age=0' || lower.startsWith('max-age=-')) {
            return true;
          }
          if (!lower.startsWith('expires=')) return false;
          final date = DateTime.tryParse(
            field.substring(field.indexOf('=') + 1).trim(),
          );
          return date != null && date.isBefore(DateTime.now().toUtc());
        });
        if (expired) {
          removals.add(key);
        } else {
          incoming[key] = value;
        }
      }
    }
    final current = <String, String>{};
    for (final part in (_map[domain] ?? '').split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        current[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
      }
    }
    current.addAll(incoming);
    for (final key in removals) {
      current.remove(key);
    }
    _map[domain] = current.entries
        .where((e) => e.key.isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    _emit(domain);
  }

  void remove(String url) {
    final domain = domainOf(url);
    _map.remove(domain);
    _emit(domain);
  }

  Map<String, String> snapshot() => Map.unmodifiable(_map);

  void load(Map<String, String> data) {
    _map
      ..clear()
      ..addAll(data);
  }

  static String domainOf(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }
}
