import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/core/api_client.dart';

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
    id:           j['_id'],
    manufacturer: j['manufacturer'] ?? j['ID'] ?? 'Machine',
    noOfHeads:    j['NoOfHead']?.toString() ?? '1',
  );

  int get headCount => int.tryParse(noOfHeads) ?? 1;
}

class JobElasticEntry {
  final String id;
  final String name;
  final int quantity;
  JobElasticEntry({required this.id, required this.name, required this.quantity});
}

class WeavingPlanController extends GetxController {
  final String jobId;
  WeavingPlanController(this.jobId);

  Dio get _dio => ApiClient.instance.dio;

  final isLoading      = true.obs;
  final isSubmitting   = false.obs;
  final machines       = <MachineSelectModel>[].obs;
  final selectedMachine = Rxn<MachineSelectModel>();
  final jobElastics    = <JobElasticEntry>[].obs;
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
      final res = await _dio.get('/machine/free');
      machines.assignAll(
        (res.data['machines'] as List)
            .map((e) => MachineSelectModel.fromJson(e))
            .toList(),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to load machines';
      Get.snackbar('Error', msg,
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

  Future<void> submitWeavingPlan({bool confirmHooks = false}) async {
    final machine = selectedMachine.value;
    if (machine == null) {
      Get.snackbar('Validation', 'Please select a machine',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final unassigned = headElasticMap.values.where((v) => v == null).length;
    if (unassigned > 0) {
      Get.snackbar('Validation', 'Assign an elastic to all $unassigned remaining heads',
          backgroundColor: const Color(0xFFD97706),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isSubmitting.value = true;
      await _dio.post('/job/plan-weaving', data: {
        'jobId':         jobId,
        'machineId':     machine.id,
        'headElasticMap': headElasticMap
            .map((k, v) => MapEntry(k.toString(), v)),
        if (confirmHooks) 'confirmHooks': true,
      });
      Get.snackbar('Weaving Planned', 'Machine assigned successfully',
          backgroundColor: const Color(0xFF16A34A),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      Get.back(result: true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final String msg =
          ((data is Map ? data['message'] : null) ?? 'Failed to plan weaving')
              .toString();

      // A weaving head has a fixed number of hooks and an elastic's recipe
      // says how many it needs. When the product needs more than the machine
      // has, the server refuses with HOOKS_EXCEED_MACHINE — but that is a
      // QUESTION, not a failure: the floor does sometimes run a product on a
      // smaller machine deliberately, and the message even says "Confirm to
      // assign it anyway". Showing it as a red error snackbar left the
      // operator holding an instruction they had no way to follow.
      if (data is Map && data['code'] == 'HOOKS_EXCEED_MACHINE' && !confirmHooks) {
        isSubmitting.value = false;
        final ok = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Machine has fewer hooks than the elastic needs'),
            content: Text('$msg\n\nAssign it anyway?'),
            actions: [
              TextButton(
                onPressed: () => Get.back<bool>(result: false),
                child: const Text('Go back'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Get.back<bool>(result: true),
                child: const Text('Assign anyway'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
        // The confirmation is a second, deliberate request — never
        // retried automatically, and never more than once.
        if (ok == true) await submitWeavingPlan(confirmHooks: true);
        return;
      }

      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }
}
