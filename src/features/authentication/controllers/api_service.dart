import 'package:dio/dio.dart';
import '../../../core/app_config.dart';
import '../../../core/api_client.dart';

class ApiService {
  // Route through ApiClient.buildClient so the JWT cookie is attached —
  // a bare Dio(BaseOptions(...)) skips the interceptor and 401s against
  // the gated backend (/customer and /elastic are auth-gated).
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
    timeout: const Duration(seconds: 10),
  );

  static Future<List<dynamic>> fetchCustomers() async {
    final res = await _dio.get("/customer/all-customers");
    return res.data["customers"];
  }

  static Future<List<dynamic>> fetchElastics() async {
    final res = await _dio.get("/elastic/get-elastics");
    return res.data["elastics"];
  }

  static Future<void> createOrder(Map<String, dynamic> payload) async {
    await _dio.post("/order/create-order", data: payload);
  }
}
