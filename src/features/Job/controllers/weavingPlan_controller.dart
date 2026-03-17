import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

// Inline-safe model for machines on this page
class MachineSelectModel {
  final String id;
  final String manufacturer;
  final String noOfHeads;

  MachineSelectModel({
    required this.id,
    required this.manufacturer,
    required this.noOfHeads,
  });

  factory MachineSelectModel.fromJson(Map j) => MachineSelectModel(
    id:           j["_id"],
    manufacturer: j["manufacturer"] ?? j["ID"] ?? "Machine",
    noOfHeads:    j["NoOfHead"]?.toString() ?? "1",
  );

  int get headCount => int.tryParse(noOfHeads) ?? 1;
}

// Inline model for elastics in job
class JobElasticEntry {
  final String id;
  final String name;
  final int quantity;
  JobElasticEntry({required this.id, required this.name, required this.quantity});
}

class WeavingPlanController extends GetxController {
  final String jobId;
  WeavingPlanController(this.jobId);

  final _dio = Dio(BaseOptions(
    baseUrl: "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final isLoading      = true.obs;
  final isSubmitting   = false.obs;
  final machines       = <MachineSelectModel>[].obs;
  final selectedMachine = Rxn<MachineSelectModel>();
  final jobElastics    = <JobElasticEntry>[].obs;

  // headIndex → selected elasticId
  final headElasticMap = <int, String?>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFreeMachines();
  }

  void setJobElastics(List<JobElasticEntry> elastics) {
    jobElastics.assignAll(elastics);
  }

  Future<void> fetchFreeMachines() async {
    try {
      isLoading.value = true;
      final res = await _dio.get("/machine/free");
      machines.assignAll(
        (res.data["machines"] as List)
            .map((e) => MachineSelectModel.fromJson(e))
            .toList(),
      );
    } on DioException catch (e) {
      // FIX: was missing — crash silently before
      final msg = e.response?.data?['message'] ?? "Failed to load machines";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void selectMachine(MachineSelectModel machine) {
    selectedMachine.value = machine;
    headElasticMap.clear();
    for (int i = 0; i < machine.headCount; i++) {
      headElasticMap[i] = null;
    }
  }

  void selectElasticForHead(int headIndex, String elasticId) {
    headElasticMap[headIndex] = elasticId;
  }

  Future<void> submitWeavingPlan() async {
    // FIX: was force-unwrapping selectedMachine.value! — NPE possible
    final machine = selectedMachine.value;
    if (machine == null) {
      Get.snackbar("Validation", "Please select a machine",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final unassigned =
        headElasticMap.values.where((v) => v == null).length;
    if (unassigned > 0) {
      Get.snackbar("Validation", "Assign an elastic to all $unassigned remaining heads",
          backgroundColor: const Color(0xFFD97706),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isSubmitting.value = true;
      await _dio.post("/job/plan-weaving", data: {
        "jobId":         jobId,
        "machineId":     machine.id,
        "headElasticMap": headElasticMap
            .map((k, v) => MapEntry(k.toString(), v)),
      });
      Get.snackbar("Weaving Planned", "Machine assigned successfully",
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      // FIX: was Get.to(JobListPage()) — created stale instance.
      //      Go back to the Job Detail page which will refresh.
      Get.back(result: true);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to plan weaving";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }
}