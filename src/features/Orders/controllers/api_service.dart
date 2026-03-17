import 'package:dio/dio.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2", // 🔁 CHANGE
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
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
