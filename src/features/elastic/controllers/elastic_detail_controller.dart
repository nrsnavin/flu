import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../screens/addElastic.dart';

class ElasticDetailController extends GetxController {
  final Dio dio = Dio(BaseOptions(
    baseUrl:        "http://13.233.117.153:2701/api/v2/elastic",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final String elasticId;
  ElasticDetailController(this.elasticId);

  final loading       = true.obs;
  final savingPlan    = false.obs;   // spinner while saving template
  final recalculating   = false.obs;  // spinner while recalculating costing
  final RxMap<String, dynamic> elastic = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> costing = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      loading.value = true;
      final res = await dio.get(
        "/get-elastic-detail",
        queryParameters: {"id": elasticId},
      );
      elastic.value = res.data["elastic"];
      costing.value = res.data["elastic"]["costing"] ?? {};
    } catch (_) {
      Get.snackbar("Error", "Failed to load elastic details",
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  Future<void> editElastic() async {
    await Get.to(() => AddElasticPage(
      editData: Map<String, dynamic>.from(elastic),
    ));
    fetchDetail();
  }

  Future<void> cloneElastic() async {
    await Get.to(() => AddElasticPage(
      cloneData: Map<String, dynamic>.from(elastic),
    ));
  }

  Future<void> deleteElastic({required VoidCallback onDeleted}) async {
    try {
      loading.value = true;
      await dio.delete("/delete-elastic", queryParameters: {"id": elasticId});
      Get.snackbar("Deleted", "${elastic["name"]} has been deleted",
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      onDeleted();
    } on DioException catch (e) {
      final msg = e.response?.data?["message"] ?? "Failed to delete elastic";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  WARPING PLAN TEMPLATE
  // ═══════════════════════════════════════════════════════════

  /// Warp yarn options for plan dropdowns — extracted from elastic's
  /// warpYarn array after population (id is a Map with _id/name).
  List<Map<String, String>> get warpYarnOptions {
    final yarns = elastic["warpYarn"] as List? ?? [];
    return yarns
        .where((w) => w["id"] is Map && w["id"]["_id"] != null)
        .map<Map<String, String>>((w) => {
      "id":   w["id"]["_id"].toString(),
      "name": w["id"]["name"]?.toString() ?? "—",
    })
        .toList();
  }

  /// Returns current template as a prefill map for the bottom sheet,
  /// or null if no template exists yet.
  Map<String, dynamic>? get currentTemplate {
    final tpl = elastic["warpingPlanTemplate"];
    if (tpl == null) return null;
    final beams = tpl["beams"] as List?;
    if (beams == null || beams.isEmpty) return null;
    return tpl as Map<String, dynamic>;
  }

  /// Called by the bottom sheet's Save button.
  /// [template] = { noOfBeams, beams: [{beamNo, totalEnds, sections:[{warpYarn,ends}]}] }
  /// Pass null to clear the template.
  Future<bool> savePlanTemplate(Map<String, dynamic>? template) async {
    try {
      savingPlan.value = true;
      await dio.put("/warping-plan-template", data: {
        "elasticId": elasticId,
        "template":  template,
      });
      await fetchDetail();
      Get.snackbar(
        "Saved",
        template != null
            ? "Warping plan template saved successfully"
            : "Warping plan template cleared",
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?["message"] ?? "Failed to save plan template";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      savingPlan.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  COSTING RECALCULATION
  // ═══════════════════════════════════════════════════════════

  /// Calls POST /elastic/recalculate-elastic-cost.
  /// [conversionCost] — pass a new value to override what is stored,
  ///                    or null to keep the existing stored value.
  ///
  /// Returns true on success. On success the [costing] map is updated
  /// in-place so the UI reflects the new numbers immediately without
  /// a full page reload.
  Future<bool> recalculateCosting({double? conversionCost}) async {
    try {
      recalculating.value = true;

      final body = <String, dynamic>{"elasticId": elasticId};
      if (conversionCost != null) body["conversionCost"] = conversionCost;

      final res = await dio.post("/recalculate-elastic-cost", data: body);

      // Update the costing map directly — no need for a full page fetch
      final updated = res.data["costing"] as Map<String, dynamic>?;
      if (updated != null) {
        costing.value = updated;
        // Also patch the costing key inside the elastic map so any widget
        // reading elastic["costing"] also sees the fresh data
        elastic["costing"] = updated;
      }

      Get.snackbar(
        "Costing Updated",
        "Recalculated using latest raw material prices",
        backgroundColor: const Color(0xFF16A34A),
        colorText: const Color(0xFFFFFFFF),
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?["message"] ?? "Recalculation failed";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      recalculating.value = false;
    }
  }
}