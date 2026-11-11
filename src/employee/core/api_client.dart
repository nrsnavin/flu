import 'package:dio/dio.dart';

import '../../core/api_client.dart' as admin;
import '../../core/app_config.dart';

// The employee screens' Dio. Built by the admin app's own factory, so
// it carries the same session cookie and the same "X-Client: mobile"
// header as every office screen: one sign-in, one token, whichever side
// of the app is showing.
//
// What it adds is the employee side's one extra rule: a 401 on a
// request that carried the token means the server has ended the session
// (signed out elsewhere, PIN reset, the employee has left), so the app
// goes back to the sign-in screen instead of showing pages whose every
// request fails.
class ApiClient {
  /// Set by EmpSession. Called when the server refuses the session.
  static void Function()? onSessionEnded;

  ApiClient._internal() {
    dio = admin.ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) {
          // Only a request that sent a token: a wrong PIN on the sign-in
          // screen is a 401 too, and ends nothing.
          final refused = e.response?.statusCode == 401 &&
              e.requestOptions.headers.containsKey('Cookie');
          if (refused) onSessionEnded?.call();
          handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;
}
