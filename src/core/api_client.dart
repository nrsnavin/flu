import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/authentication/controllers/storage_keys.dart';

// Single Dio instance for the whole app. Every request goes through this
// so the JWT cookie is attached automatically — the backend reads it from
// req.cookies.token, sets req.user, and the audit plugin uses that to
// stamp createdBy / updatedBy on every write.
class ApiClient {
  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: 'http://13.233.117.153:2701/api/v2',
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
