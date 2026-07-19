import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/authentication/controllers/storage_keys.dart';
import 'app_config.dart';

// Single Dio instance for the whole app. Every request goes through this
// so the JWT cookie is attached automatically — the backend reads it from
// req.cookies.token, sets req.user, and the audit plugin uses that to
// stamp createdBy / updatedBy on every write.
class ApiClient {
  ApiClient._internal() {
    dio = buildClient(baseUrl: ApiConfig.baseUrl);
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;

  // Factory for per-feature Dio instances that point at a specific path
  // prefix (e.g. ".../api/v2/customer"). Many controllers were written
  // before the auth gate landed and constructed bare `Dio(BaseOptions(...))`
  // — those skipped the cookie interceptor and now 401 against the gated
  // backend. Routing them through this factory restores the JWT cookie
  // on every request without forcing each controller to depend on the
  // shared baseUrl.
  static Dio buildClient({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
  }) {
    final client = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
    ));

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(StorageKeys.token) ?? '';
          if (token.isNotEmpty) {
            options.headers['Cookie'] = 'token=$token';
          }
          handler.next(options);
        },
      ),
    );

    return client;
  }
}
