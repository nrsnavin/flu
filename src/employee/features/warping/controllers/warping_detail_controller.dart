import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../models/warping.dart';

// ═════════════════════════════════════════════════════════════
//  WARPING DETAIL CONTROLLER (worker, read-only)
//
//  GET /warping/detail/:id
//  GET /warping/warpingPlan?id=<planId>   (only if hasPlan)
// ═════════════════════════════════════════════════════════════
class EmpWarpingDetailController extends GetxController {
  final String warpingId;
  EmpWarpingDetailController(this.warpingId);

  Dio get _dio => ApiClient.instance.dio;

  final warping   = Rxn<WarpingDetail>();
  final plan      = Rxn<WarpingPlanDetail>();
  final isLoading = true.obs;
  final isPlanLoading = false.obs;
  final errorMsg  = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res  = await _dio.get('/warping/detail/$warpingId');
      final body = SafeJson.asMap(res.data);
      final w    = SafeJson.asMap(body['warping']);
      if (w.isEmpty) {
        errorMsg.value = 'Warping not found';
        return;
      }
      final detail = WarpingDetail.fromJson(w);
      warping.value = detail;
      // If plan came inline, reuse it; otherwise lazy-fetch.
      plan.value = detail.plan;
      if (detail.hasPlan && detail.plan == null) {
        await fetchPlan(detail.planId);
      }
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load warping';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlan(String planId) async {
    if (planId.isEmpty) return;
    isPlanLoading.value = true;
    try {
      final res  = await _dio.get('/warping/warpingPlan',
          queryParameters: {'id': planId});
      final body = SafeJson.asMap(res.data);
      // Endpoint returns the plan either at root or under `warpingPlan`.
      final pMap = body['warpingPlan'] is Map
          ? SafeJson.asMap(body['warpingPlan'])
          : body;
      if (pMap.isNotEmpty && pMap['_id'] != null) {
        plan.value = WarpingPlanDetail.fromJson(pMap);
      }
    } on DioException catch (_) {
      // Non-fatal — keep warping shown without plan.
    } finally {
      isPlanLoading.value = false;
    }
  }
}
