import 'package:dio/dio.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

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
    await _dio.post("/order/approve", data: {
      "orderId": orderId,
      "actor":   buildActorPayload(),
    });
  }

  static Future<void> cancelOrder(String orderId) async {
    await _dio.post("/order/cancel", data: {
      "orderId": orderId,
      "actor":   buildActorPayload(),
    });
  }

  /// Edit an Open order's header fields and/or items.
  /// `patch` may include any of: po, supplyDate, description, customer,
  /// elasticOrdered (full replacement; backend recomputes BOM).
  static Future<Map<String, dynamic>> updateOrder(
    String orderId,
    Map<String, dynamic> patch,
  ) async {
    final res = await _dio.post('/order/update-order', data: {
      'orderId': orderId,
      ...patch,
      'actor': buildActorPayload(),
    });
    return res.data as Map<String, dynamic>;
  }

  /// Soft-delete an Open order (must have no jobs). Sets status = "Deleted".
  static Future<void> deleteOrder(String orderId, {String? reason}) async {
    await _dio.post('/order/delete-order', data: {
      'orderId': orderId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      'actor': buildActorPayload(),
    });
  }
}
