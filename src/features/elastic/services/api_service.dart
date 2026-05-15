import 'package:dio/dio.dart';

import '../../../core/api_client.dart';

class ApiService {
  // Cookie-attaching factory so this client carries the JWT and clears
  // the auth gate. baseUrl matches the rest of the admin app (
  // ApiClient.instance points at the same host).
  static final Dio dio = ApiClient.buildClient(
    baseUrl: "http://13.233.117.153:2701/api/v2/elastic",
  );
}
