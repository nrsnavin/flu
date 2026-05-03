import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

/// FIX: Rewritten to use raw Map<String,dynamic> to avoid dependency on
/// missing model files (JobDetailViewMapper, JobDetailView, PreparatoryView,
/// ShiftDetailModelView, etc.) that are not included in the upload set.
/// The API returns a flat job object — we work with it directly.
class JobDetailController extends GetxController {
  static final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final String jobId;
  JobDetailController(this.jobId);

  final job      = Rxn<Map<String, dynamic>>();
  final loading  = true.obs;
  final actioning = false.obs; // separate flag for status-update actions

  @override
  void onInit() {
    // FIX: super.onInit() first — was called after fetchJob()
    super.onInit();
    fetchJob();
  }

  Future<void> fetchJob() async {
    try {
      loading.value = true;
      final res = await _dio.get("/job/detail", queryParameters: {"id": jobId});
      job.value = res.data["job"] as Map<String, dynamic>?;
    } on DioException catch (e) {
      // FIX: was no catch at all — raw exception propagated to crash
      final msg = e.response?.data?['message'] ?? "Failed to load job";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  // ── Status update with confirmation ──────────────────────────
  Future<void> updateStatus(String nextStatus) async {
    final confirm = await Get.dialog<bool>(AlertDialog(
      title: const Text("Confirm"),
      content: Text("Move job to $nextStatus stage?"),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          child: const Text("Confirm"),
        ),
      ],
    ));
    if (confirm != true) return;

    try {
      actioning.value = true;
      await _dio.post("/job/update-status", data: {
        "jobId":      jobId,
        "nextStatus": nextStatus,
        "actor":      buildActorPayload(),
      });
      Get.snackbar(
        "Stage Updated",
        "Job moved to $nextStatus",
        backgroundColor: _stageColor(nextStatus),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      await fetchJob();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Status update failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      actioning.value = false;
    }
  }

  Color _stageColor(String status) {
    switch (status) {
      case "weaving":   return const Color(0xFF1D6FEB);
      case "finishing": return const Color(0xFFD97706);
      case "checking":  return const Color(0xFF7C3AED);
      case "packing":   return const Color(0xFF0891B2);
      case "completed": return const Color(0xFF16A34A);
      default:          return const Color(0xFF475569);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  String get status => job.value?["status"]?.toString() ?? "";

  bool get canPlanWeaving {
    final j = job.value;
    if (j == null) return false;
    final wStatus =
    j["warping"] is Map ? j["warping"]["status"]?.toString() : null;
    final cStatus =
    j["covering"] is Map ? j["covering"]["status"]?.toString() : null;
    return j["status"] == "preparatory" &&
        wStatus == "completed" &&
        cStatus == "completed";
  }

  bool get hasMachine => job.value?["machine"] != null;

  String? get nextStatus {
    const flow = {
      "weaving":   "finishing",
      "finishing": "checking",
      "checking":  "packing",
      "packing":   "completed",
    };
    return flow[status];
  }
}