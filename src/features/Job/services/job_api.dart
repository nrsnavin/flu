import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

class JobApi {
  // Route through ApiClient.buildClient so the JWT cookie attaches
  // (job routes are now all behind isAuthenticated).
  static final Dio _dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
  );

  static Future<void> createOrder(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post("/job/create", data: payload);
      if (res.statusCode == 201) {
        Get.snackbar("Success", "Job Created");
        // Only pop if there's a navigation context to pop. GetX
        // would silently no-op, but calling it explicitly inside
        // the success branch avoids future regressions.
        if (Get.key.currentState?.canPop() ?? false) {
          Get.back();
        }
      } else {
        Get.snackbar(
          "Could not create job",
          "Server returned ${res.statusCode}",
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data?['message']?.toString() ?? 'Failed to create job')
          : (e.message ?? 'Failed to create job');
      Get.snackbar("Error", msg);
    }
  }

  static Future<void> updateJobStatus(String id, String next) async {
    try {
      final res = await _dio.post(
        "/job/update-status",
        data: {'jobId': id, 'nextStatus': next},
      );
      if (res.statusCode == 201) {
        Get.snackbar("Success", "Job Status Updated");
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data?['message']?.toString() ?? 'Failed to update status')
          : (e.message ?? 'Failed to update status');
      Get.snackbar("Error", msg);
    }
  }

  static Future<Map<String, dynamic>> fetchDetail(String id) async {
    final res = await _dio.get("/job/detail", queryParameters: {"id": id});
    final body = res.data is Map ? res.data["job"] : null;
    return body is Map ? Map<String, dynamic>.from(body) : const {};
  }

  static Future<Response> getJobs({
    required int page,
    required String status,
    required String search,
  }) async {
    return _dio.get(
      "/job/jobs",
      queryParameters: {
        "page": page,
        "limit": 10,
        "status": status,
        "search": search,
      },
    );
  }
}
