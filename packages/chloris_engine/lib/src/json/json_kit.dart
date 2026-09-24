import 'dart:convert';

/// Tolerant JSON helpers matching legado Gson habits:
/// nested rules may be objects or JSON strings; booleans may be 0/1.
class JsonKit {
  JsonKit._();

  static Map<String, dynamic>? map(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') return null;
      try {
        return map(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<dynamic>? list(dynamic value) {
    if (value == null) return null;
    if (value is List) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static String? string(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return jsonEncode(value);
  }

  static String stringOr(dynamic value, [String fallback = '']) {
    return string(value) ?? fallback;
  }

  static bool boolOf(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no' || v.isEmpty) return false;
    }
    return fallback;
  }

  static int intOf(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static int? intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double doubleOf(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static T? object<T>(
    dynamic value,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final m = map(value);
    if (m == null) return null;
    return fromJson(m);
  }

  /// Drop nulls so exported sources look like 开源阅读 JSON.
  static Map<String, dynamic> compact(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      final cleaned = _compactValue(value);
      if (cleaned != null) {
        out[key] = cleaned;
      }
    });
    return out;
  }

  static dynamic _compactValue(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final nested = compact(value);
      return nested.isEmpty ? null : nested;
    }
    if (value is Map) {
      return _compactValue(map(value));
    }
    if (value is List) {
      return value.map(_compactValue).where((e) => e != null).toList();
    }
    return value;
  }

  static String encodePretty(Object? value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}
