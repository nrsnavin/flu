import 'package:dio/dio.dart';

class OrderApi {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://13.233.117.153:2701/api/v2", // 🔁 CHANGE
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<List<dynamic>> fetchOrders(String status) async {
    final res = await _dio.get(
      "/order/list",
      queryParameters: {"status": status},
    );
    return res.data["orders"];
  }

  static Future<void> approveOrder(String orderId) async {
    await _dio.post("/order/approve", data: {"orderId": orderId});
  }

  static Future<void> cancelOrder(String orderId) async {
    await _dio.post("/order/cancel", data: {"orderId": orderId});
  }
}
