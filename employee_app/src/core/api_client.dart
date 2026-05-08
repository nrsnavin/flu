import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/controllers/storage_keys.dart';

// Singleton Dio instance for the employee app. Mirrors the admin
// app's ApiClient so the JWT cookie set at login flows with every
// request — the backend reads `req.cookies.token`, populates
// `req.user`, and the audit-fields plugin records who did what.
class ApiClient {
  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl:        'http://13.233.117.153:2701/api/v2',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    dio.interceptors.add(
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
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;
}
