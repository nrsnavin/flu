// ══════════════════════════════════════════════════════════════
//  App configuration — single source of truth for the backend URL.
//
//  Before this existed the base URL was hardcoded in ~60 files as a
//  cleartext `http://…` string, so moving to HTTPS meant a 90-place
//  find-and-replace. Now the whole app reads ApiConfig.baseUrl, and
//  the cutover to TLS is a single build-time flag — no code change:
//
//    flutter build apk \
//      --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v2
//
//  The default is kept at the current host so existing/dev builds keep
//  working until TLS is provisioned. See MOBILE_TLS.md for the full
//  go-live cutover (HTTPS URL + Android cleartext block).
// ══════════════════════════════════════════════════════════════
class ApiConfig {
  ApiConfig._();

  /// Backend API base, including the `/api/v2` prefix. Override at build
  /// time with `--dart-define=API_BASE_URL=...`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://13.233.117.153:2701/api/v2',
  );

  /// True once the app is pointed at an HTTPS endpoint — useful for a
  /// runtime guard / banner in debug builds.
  static bool get isSecure => baseUrl.startsWith('https://');

  /// Join a path suffix onto the base, e.g. path('/order').
  static String path(String suffix) {
    if (suffix.isEmpty) return baseUrl;
    return suffix.startsWith('/') ? '$baseUrl$suffix' : '$baseUrl/$suffix';
  }
}
