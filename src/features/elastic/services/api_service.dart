import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

class ApiService {
  // Cookie-attaching factory so this client carries the JWT and clears
  // the auth gate. baseUrl matches the rest of the admin app (
  // ApiClient.instance points at the same host).
  static final Dio dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/elastic',
  );
}
