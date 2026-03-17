import 'dart:ui';

import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../screens/addElastic.dart';

// ── Order summary model ────────────────────────────────────────
class ElasticOrderSummary {
  final String orderId;
  final int orderNo;
  final String po;
  final String customer;
  final DateTime date;
  final DateTime supplyDate;
  final String status;
  final double orderedQty;
  final double producedQty;
  final double packedQty;
  final double pendingQty;
  final int jobCount;

  ElasticOrderSummary({
    required this.orderId,
    required this.orderNo,
    required this.po,
    required this.customer,
    required this.date,
    required this.supplyDate,
    required this.status,
    required this.orderedQty,
    required this.producedQty,
    required this.packedQty,
    required this.pendingQty,
    required this.jobCount,
  });

  double get fulfillmentPct =>
      orderedQty > 0 ? (producedQty / orderedQty * 100).clamp(0, 100) : 0;

  bool get isOverdue =>
      status != 'Completed' && status != 'Cancelled' &&
          supplyDate.isBefore(DateTime.now());

  factory ElasticOrderSummary.fromJson(Map<String, dynamic> j) =>
      ElasticOrderSummary(
        orderId:     j['orderId']?.toString()   ?? '',
        orderNo:     (j['orderNo']  as num?)?.toInt()    ?? 0,
        po:          j['po']?.toString()         ?? '—',
        customer:    j['customer']?.toString()   ?? '—',
        date:        j['date'] != null
            ? DateTime.parse(j['date'] as String).toLocal()
            : DateTime.now(),
        supplyDate:  j['supplyDate'] != null
            ? DateTime.parse(j['supplyDate'] as String).toLocal()
            : DateTime.now(),
        status:      j['status']?.toString()     ?? 'Open',
        orderedQty:  (j['orderedQty']  as num?)?.toDouble() ?? 0,
        producedQty: (j['producedQty'] as num?)?.toDouble() ?? 0,
        packedQty:   (j['packedQty']   as num?)?.toDouble() ?? 0,
        pendingQty:  (j['pendingQty']  as num?)?.toDouble() ?? 0,
        jobCount:    (j['jobCount']    as num?)?.toInt()    ?? 0,
      );
}

class ElasticDetailController extends GetxController {
  final Dio dio = Dio(BaseOptions(
    baseUrl:        "http://13.233.117.153:2701/api/v2/elastic",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final String elasticId;
  ElasticDetailController(this.elasticId);

  final loading      = true.obs;
  final savingPlan   = false.obs;
  final loadingOrders = false.obs;
  final RxMap<String, dynamic> elastic = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> costing = <String, dynamic>{}.obs;
  final orders = <ElasticOrderSummary>[].obs;

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
    // Fetch orders in parallel — non-blocking
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      loadingOrders.value = true;
      final res = await dio.get(
        "/orders-by-elastic",
        queryParameters: {"id": elasticId},
      );
      orders.value = (res.data["orders"] as List? ?? [])
          .map((o) => ElasticOrderSummary.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // non-critical — orders section shows empty state
    } finally {
      loadingOrders.value = false;
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
}