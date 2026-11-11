/// Safe JSON converters.
///
/// Every getter in this file is total — it never throws, no matter
/// what the input looks like (null, wrong type, half-deserialised
/// nested map, etc.). Use these instead of `as Map?`, `as List?`,
/// `as num?` etc. when reading server payloads, because the latter
/// throw a TypeError when the value is present but the wrong type
/// (a common cause of "app suddenly crashes after a backend deploy").
///
/// Usage:
///   final m = SafeJson.asMap(res.data['shift']);
///   final list = SafeJson.asList(m['elastics']);
///   final qty  = SafeJson.asInt(item['quantity']);
///   final when = SafeJson.asDateTime(item['createdAt']);
class SafeJson {
  SafeJson._();

  /// Returns the value as `Map<String, dynamic>`, or an empty map
  /// if the input is null / not a map.
  static Map<String, dynamic> asMap(dynamic v) {
    if (v is Map) {
      try {
        return v.cast<String, dynamic>();
      } catch (_) {
        return {for (final e in v.entries) e.key.toString(): e.value};
      }
    }
    return const {};
  }

  /// Nullable map. Returns null if the input isn't a map.
  static Map<String, dynamic>? asMapOrNull(dynamic v) {
    if (v is Map) {
      try {
        return v.cast<String, dynamic>();
      } catch (_) {
        return {for (final e in v.entries) e.key.toString(): e.value};
      }
    }
    return null;
  }

  /// Returns the value as `List<dynamic>`, or an empty list if the
  /// input is null / not a list.
  static List<dynamic> asList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  /// Returns a list of typed maps, dropping any non-map elements.
  static List<Map<String, dynamic>> asMapList(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in v) {
      if (e is Map) {
        try {
          out.add(e.cast<String, dynamic>());
        } catch (_) {
          out.add({for (final entry in e.entries)
            entry.key.toString(): entry.value});
        }
      }
    }
    return out;
  }

  /// Returns the value as a non-null trimmed String. Empty string
  /// for null / unsupported types.
  static String asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  /// Nullable string. Returns null for null input AND for empty
  /// strings (so callers can use `?? '—'` for display).
  static String? asStringOrNull(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Numeric conversion that tolerates `int`, `double`, `num`,
  /// numeric strings, and bools (true→1, false→0).
  static num? asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static double asDouble(dynamic v, [double fallback = 0]) =>
      asNum(v)?.toDouble() ?? fallback;

  static int asInt(dynamic v, [int fallback = 0]) =>
      asNum(v)?.toInt() ?? fallback;

  static bool asBool(dynamic v, [bool fallback = false]) {
    if (v is bool) return v;
    if (v is num)  return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  /// Parses ISO-8601 / RFC-3339 dates. Returns null on anything it
  /// can't parse — never throws.
  static DateTime? asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Convenience: parses + converts to local time, returning null on
  /// failure. Most callers want this.
  static DateTime? asLocalDateTime(dynamic v) =>
      asDateTime(v)?.toLocal();

  /// Extracts a server-supplied error message from a Dio response
  /// body without crashing when the body is an HTML page, plain
  /// string, or otherwise non-JSON.
  ///
  /// Pass `responseData` (i.e. `dioException.response?.data`).
  static String? apiErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      final m = asMap(responseData);
      return asStringOrNull(m['message']) ?? asStringOrNull(m['error']);
    }
    return asStringOrNull(responseData);
  }
}
