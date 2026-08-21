import 'package:dio/dio.dart';
import '../../PurchaseOrder/services/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../screens/label.dart';
import '../screens/pdf.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;


import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
// ── API ───────────────────────────────────────────────────────
class WarpingApi {
  static final Dio _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/warping');

  static Future<Map<String, dynamic>> listWarpings({
    required String status, String search = '', int page = 1, int limit = 20,
  }) async {
    final res = await _dio.get('/list', queryParameters: {
      'status': status, 'search': search, 'page': page, 'limit': limit,
    });
    return res.data as Map<String, dynamic>;
  }

  static Future<WarpingDetail> fetchDetail(String id) async {
    final res = await _dio.get('/detail/$id');
    return WarpingDetail.fromJson(res.data['warping'] as Map<String, dynamic>);
  }

  // Backend switched these endpoints from PUT to POST so the JSON
  // body always survives reverse-proxy hops (some strip PUT bodies,
  // dropping the actor). `id` now rides in the body too.
  static Future<void> start(String id) async =>
      _dio.post('/start', data: {'id': id, 'actor': buildActorPayload()});

  /// Complete a warping.
  ///
  /// [forceReason] skips the "yarn still on the rack" gate. The route
  /// enforces a minimum of 5 characters and records the reason on the
  /// fingerprint, so a completion that skipped the check stays visible
  /// afterwards instead of looking like one that passed it.
  static Future<void> complete(String id, {String? forceReason}) async =>
      _dio.post('/complete', data: {
        'id': id,
        'actor': buildActorPayload(),
        if (forceReason != null) ...{
          'force': true,
          'forceReason': forceReason,
        },
      });

  // FIX: was { _id: id } on backend — now fixed to { warping: id }
  static Future<WarpingPlanDetail?> fetchPlan(String warpingId) async {
    final res = await _dio.get('/warpingPlan', queryParameters: {'id': warpingId});
    if (res.data['exists'] == true) {
      return WarpingPlanDetail.fromJson(res.data['plan'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Returns { warpYarns, prefillTemplate, lotStock }
  static Future<Map<String, dynamic>> fetchPlanContext(String jobId) async {
    final res = await _dio.get('/plan-context/$jobId');
    final yarns = (res.data['warpYarns'] as List? ?? [])
        .map((e) => WarpYarnOption.fromJson(e as Map<String, dynamic>))
        .toList();
    final template = res.data['prefillTemplate'] as Map<String, dynamic>?;
    final lotStock = (res.data['lotStock'] as List? ?? [])
        .whereType<Map>()
        .map((e) => YarnLotStock.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return {
      'warpYarns': yarns,
      'prefillTemplate': template,
      'lotStock': lotStock,
    };
  }

  // ── Warping batches ────────────────────────────────────────
  // A batch is the record of which lots were actually drawn to build
  // which beams. See models/WarpingBatch.js for why it is separate
  // from the plan.

  static Future<List<WarpingBatchModel>> listBatches({
    String? warpingId,
    String? jobId,
    String status = 'all',
  }) async {
    final res = await _dio.get('/batch/list', queryParameters: {
      if (warpingId != null) 'warpingId': warpingId,
      if (jobId != null) 'jobId': jobId,
      'status': status,
    });
    return (res.data['batches'] as List? ?? [])
        .whereType<Map>()
        .map((e) => WarpingBatchModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<WarpingBatchModel> createBatch({
    required String warpingId,
    required List<int> beamNos,
    required List<BatchAllocation> allocations,
    List<String> elastics = const [],
    String remarks = '',
  }) async {
    final res = await _dio.post('/batch/create', data: {
      'warpingId':   warpingId,
      'beamNos':     beamNos,
      'allocations': allocations.map((a) => a.toJson()).toList(),
      if (elastics.isNotEmpty) 'elastics': elastics,
      'remarks': remarks,
    });
    return WarpingBatchModel.fromJson(res.data['batch'] as Map<String, dynamic>);
  }

  static Future<WarpingBatchModel> issueBatch(String id) async {
    final res = await _dio.post('/batch/$id/issue');
    return WarpingBatchModel.fromJson(res.data['batch'] as Map<String, dynamic>);
  }

  static Future<WarpingBatchModel> completeBatch(String id) async {
    final res = await _dio.post('/batch/$id/complete');
    return WarpingBatchModel.fromJson(res.data['batch'] as Map<String, dynamic>);
  }

  static Future<WarpingBatchModel> cancelBatch(String id) async {
    final res = await _dio.patch('/batch/$id/cancel');
    return WarpingBatchModel.fromJson(res.data['batch'] as Map<String, dynamic>);
  }

  static Future<WarpingPlanDetail> createPlan({
    required String warpingId,
    required List<EditableBeam> beams,
    String? remarks,
  }) async {
    final res = await _dio.post('/warpingPlan/create', data: {
      'warpingId': warpingId,
      'beams':     beams.map((b) => b.toJson()).toList(),
      'remarks':   remarks ?? '',
    });
    return WarpingPlanDetail.fromJson(res.data['plan'] as Map<String, dynamic>);
  }

  // DELETE /warpingPlan/:id — removes the plan (only while warping is open)
  // so a corrected one can be created. Requires an audit reason; the server
  // stamps a WARPING_PLAN_DELETED fingerprint on the parent job.
  static Future<void> deletePlan(String planId, {required String auditReason}) async {
    await _dio.delete('/warpingPlan/$planId',
        queryParameters: {'auditReason': auditReason});
  }
}

// ══════════════════════════════════════════════════════════════
//  WARPING LIST CONTROLLER
//
//  BUGS FIXED:
//  1. WarpingController instantiated at StatelessWidget class field → stale.
//  2. No error state.
// ══════════════════════════════════════════════════════════════
class WarpingListController extends GetxController {
  final warpings      = <WarpingListItem>[].obs;
  final isLoading     = false.obs;
  final errorMsg      = Rxn<String>();
  final statusFilter  = 'open'.obs;
  final searchQuery   = ''.obs;
  final hasMore       = true.obs;

  // Stats per status
  final Map<String, int> statusCounts = {};

  int _page = 1;
  static const _limit = 20;

  @override
  void onInit() {
    super.onInit();
    fetch(reset: true);
    ever(statusFilter, (_) => fetch(reset: true));
  }

  Future<void> fetch({bool reset = false}) async {
    if (isLoading.value) return;
    if (reset) { _page = 1; hasMore.value = true; warpings.clear(); }
    if (!hasMore.value) return;

    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final data = await WarpingApi.listWarpings(
        status: statusFilter.value,
        search: searchQuery.value,
        page:   _page,
        limit:  _limit,
      );
      final items = (data['data'] as List? ?? [])
          .map((e) => WarpingListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      warpings.addAll(items);
      hasMore.value = data['pagination']?['hasMore'] == true;
      _page++;
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ?? 'Failed to load';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void changeStatus(String s) {
    statusFilter.value = s;
  }

  void onSearch(String v) {
    searchQuery.value = v;
    fetch(reset: true);
  }
}

// ══════════════════════════════════════════════════════════════
//  WARPING DETAIL CONTROLLER
//
//  BUGS FIXED:
//  1. `hasPlan` was never set to true — plan section always showed
//     empty. Now: if detail.hasPlan is true, fetches plan separately.
//  2. Base URL was 10.0.2.2 (Android emulator localhost) → fixed.
//  3. startWarping() and completeWarping() had no try/catch.
//  4. Controller instantiated in build() on StatelessWidget → stale.
// ══════════════════════════════════════════════════════════════
class WarpingDetailController extends GetxController {
  final String warpingId;
  WarpingDetailController(this.warpingId);

  final warping        = Rxn<WarpingDetail>();
  final plan           = Rxn<WarpingPlanDetail>();
  final isLoading      = true.obs;
  final isActing       = false.obs;
  final isExportingPdf = false.obs;
  final errorMsg       = Rxn<String>();

  final isExportingBeamLabels = false.obs;


  Future<void> exportBeamLabels() async {
    final p = plan.value;
    final w = warping.value;
    if (p == null || w == null || p.beams.isEmpty) {
      _snack('No beams to export', isError: true);
      return;
    }
    isExportingBeamLabels.value = true;
    try {
      final shade  = w.elastics.isNotEmpty ? w.elastics.first.elasticName : '—';
      final meters = w.elastics.isNotEmpty ? w.elastics.first.plannedQty  : 0;
      await BeamLabelPdf.generate(
        jobOrderNo: warping.value?.jobOrderNo??0,
        shade:      shade,
        meters:     meters,
        beams:      p.beams,
      );
    } catch (e) {
      _snack('Failed to export labels: $e', isError: true);
    } finally {
      isExportingBeamLabels.value = false;
    }
  }

  void _snack(String msg, {required bool isError}) => Get.snackbar(
    isError ? 'Error' : 'Success', msg,
    backgroundColor: isError ? ErpColors.errorRed : ErpColors.successGreen,
    colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );

  @override
  void onInit() { super.onInit(); fetchDetail(); }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final w = await WarpingApi.fetchDetail(warpingId);
      warping.value = w;
      // FIX: hasPlan was never set — always showed "no plan" UI.
      //      Now fetch plan if warpingPlan is linked.
      if (w.plan != null) {
        plan.value = w.plan;
      } else if (w.hasPlan) {
        await _fetchPlan();
      }
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ?? 'Failed to load warping';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchPlan() async {
    try {
      plan.value = await WarpingApi.fetchPlan(warpingId);
    } catch (_) {}
  }

  Future<bool> startWarping() async {
    isActing.value = true;
    try {
      // FIX: no try/catch in original
      await WarpingApi.start(warpingId);
      await fetchDetail();
      _snack('Warping started', isError: false);
      return true;
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] as String? ?? 'Failed to start', isError: true);
      return false;
    } catch (e) {
      _snack(e.toString(), isError: true);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  /// The one refusal that is not a mistake.
  ///
  /// The route rejects completion while the yarn is still on the rack
  /// (409 WARPING_YARN_NOT_ISSUED). That is a state the operator can
  /// FIX — issue the batch — so it is held on screen as something to
  /// act on rather than flashed past in a red snackbar, which is all
  /// the phone did with it before. The web has held it this way since
  /// the rule shipped; the phone silently could not get past it.
  final yarnBlocker = RxnString();

  void dismissYarnBlocker() => yarnBlocker.value = null;

  /// [forceReason] completes anyway, for beams already off the machine
  /// — warping that ran before the yarn was recorded against a batch.
  /// The route wants at least 5 characters and keeps it on the audit
  /// trail.
  Future<bool> completeWarping({String? forceReason}) async {
    isActing.value = true;
    try {
      await WarpingApi.complete(warpingId, forceReason: forceReason);
      yarnBlocker.value = null;
      await fetchDetail();
      _snack('Warping completed successfully', isError: false);
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      final message =
          (data is Map ? data['message'] as String? : null) ?? 'Failed to complete';
      if (code == 'WARPING_YARN_NOT_ISSUED') {
        // Not a snackbar. It stays until it is dealt with.
        yarnBlocker.value = message;
        return false;
      }
      _snack(message, isError: true);
      return false;
    } catch (e) {
      _snack(e.toString(), isError: true);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  /// Deletes the current warping plan (Open warping only) with an audit
  /// reason. Returns true so the caller can refresh into the no-plan view.
  Future<bool> deletePlan(String auditReason) async {
    final p = plan.value;
    if (p == null) return false;
    isActing.value = true;
    try {
      await WarpingApi.deletePlan(p.id, auditReason: auditReason);
      await fetchDetail();
      _snack('Warping plan deleted', isError: false);
      return true;
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] as String? ?? 'Failed to delete plan', isError: true);
      return false;
    } catch (e) {
      _snack(e.toString(), isError: true);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  Future<void> exportPdf() async {
    final w = warping.value;
    final p = plan.value;
    if (w == null) {
      _snack('Warping data not loaded', isError: true);
      return;
    }
    if (p == null) {
      _snack('No warping plan available to export', isError: true);
      return;
    }
    isExportingPdf.value = true;
    try {
      await WarpingPlanPdfService.generate(
        jobOrderNo: w.jobOrderNo.toString(),
        plan:       p,
        elastics:   w.elastics,
        date:       w.date,
        status:     w.status,
      );
      _snack('PDF exported successfully', isError: false);
    } catch (e) {
      _snack('PDF export failed: $e', isError: true);
    } finally {
      isExportingPdf.value = false;
    }
  }


}

// ══════════════════════════════════════════════════════════════
//  WARPING PLAN CONTROLLER
//
//  KEY DESIGN: All TextEditingControllers for "ends" fields are
//  owned here (not in StatefulWidget State). This eliminates the
//  StatefulWidget-reuse bug where initState never re-runs after
//  prefill replaces the beams list.
//
//  endsCtrl(bi, si) → returns the TextEditingController for
//  beam[bi] section[si]. Synced automatically on any beam change.
// ══════════════════════════════════════════════════════════════
class WarpingPlanController extends GetxController {
  final String jobId;
  final String warpingId;
  WarpingPlanController(this.jobId, this.warpingId);

  static final _aiDio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

  final warpYarns    = <WarpYarnOption>[].obs;
  final beams        = <EditableBeam>[].obs;
  final beamCount    = 1.obs;
  final isLoading    = true.obs;
  final isSaving     = false.obs;
  final isGenerating = false.obs;
  final aiRemarks    = Rxn<String>();
  final errorMsg     = Rxn<String>();

  // ── TextEditingControllers owned by this controller ──────
  // Key: 'bi_si'  e.g. '0_0', '0_1', '1_0'
  final Map<String, TextEditingController> _endsCtrlMap = {};

  TextEditingController endsCtrl(int bi, int si) {
    final key = '${bi}_$si';
    if (!_endsCtrlMap.containsKey(key)) {
      _endsCtrlMap[key] = TextEditingController();
    }
    return _endsCtrlMap[key]!;
  }

  /// Call after any change to beams list.
  /// Creates / updates text fields to match current beam/section data.
  void _syncEndsControllers() {
    for (int bi = 0; bi < beams.length; bi++) {
      for (int si = 0; si < beams[bi].sections.length; si++) {
        final ends = beams[bi].sections[si].ends;
        final text = ends > 0 ? '$ends' : '';
        final ctrl = endsCtrl(bi, si);
        if (ctrl.text != text) {
          ctrl.value = ctrl.value.copyWith(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }
    // Remove controllers for positions that no longer exist
    _endsCtrlMap.removeWhere((key, ctrl) {
      final parts = key.split('_');
      final bi = int.tryParse(parts[0]) ?? 999;
      final si = int.tryParse(parts[1]) ?? 999;
      if (bi >= beams.length) { ctrl.dispose(); return true; }
      if (si >= beams[bi].sections.length) { ctrl.dispose(); return true; }
      return false;
    });
  }

  int get totalEnds => beams.fold(0, (s, b) => s + b.totalEnds);

  @override
  void onInit() {
    super.onInit();
    _initBeams();
    _fetchContext();
  }

  @override
  void onClose() {
    for (final c in _endsCtrlMap.values) c.dispose();
    _endsCtrlMap.clear();
    super.onClose();
  }

  void _initBeams() {
    beams.assignAll([EditableBeam(beamNo: 1)]);
    _syncEndsControllers();
  }

  Future<void> _fetchContext() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final ctx = await WarpingApi.fetchPlanContext(jobId);
      warpYarns.value = ctx['warpYarns'] as List<WarpYarnOption>;
      final tpl = ctx['prefillTemplate'] as Map<String, dynamic>?;
      if (tpl != null) {
        _prefillFromTemplate(tpl);
      }
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ?? 'Failed to load warp yarns';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _prefillFromTemplate(Map<String, dynamic> tpl) {
    final rawBeams = tpl['beams'] as List? ?? [];
    if (rawBeams.isEmpty) return;

    final filled = rawBeams.map<EditableBeam>((b) {
      final secs = (b['sections'] as List? ?? []).map<EditableBeamSection>((s) {
        return EditableBeamSection(
          warpYarnId:   s['warpYarnId']?.toString(),
          warpYarnName: s['warpYarnName']?.toString() ?? '',
          ends:         (s['ends'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (secs.isEmpty) secs.add(EditableBeamSection());
      return EditableBeam(
        beamNo:   (b['beamNo'] as num?)?.toInt() ?? 1,
        sections: secs,
      );
    }).toList();

    beams.assignAll(filled);
    beamCount.value = filled.length;
    // Sync text controllers AFTER beams are set
    _syncEndsControllers();
    aiRemarks.value = '✦ Pre-filled from elastic warping plan template — review and adjust.';
  }

  void updateBeamCount(int n) {
    if (n <= 0) return;
    beamCount.value = n;
    beams.assignAll(List.generate(n, (i) => EditableBeam(beamNo: i + 1)));
    _syncEndsControllers();
  }

  void addSection(int beamIndex) {
    beams[beamIndex].sections.add(EditableBeamSection());
    beams.refresh();
    _syncEndsControllers();
  }

  void removeSection(int beamIndex, int sectionIndex) {
    if (beams[beamIndex].sections.length > 1) {
      beams[beamIndex].sections.removeAt(sectionIndex);
      beams.refresh();
      _syncEndsControllers();
    }
  }

  void updateYarn(int beamIndex, int sectionIndex, WarpYarnOption yarn) {
    beams[beamIndex].sections[sectionIndex].warpYarnId   = yarn.id;
    beams[beamIndex].sections[sectionIndex].warpYarnName = yarn.name;
    beams.refresh();
  }

  void updateEnds(int beamIndex, int sectionIndex, int ends) {
    beams[beamIndex].sections[sectionIndex].ends = ends;
    // Don't call _syncEndsControllers here — user is typing, ctrl already has the value
    beams.refresh();
  }

  // ── AI Generation ────────────────────────────────────────
  Future<void> generateFromAi() async {
    if (isGenerating.value) return;
    isGenerating.value = true;
    try {
      final res = await _aiDio.post('/ai/generate-warping-plan', data: {
        'jobId':     jobId,
        'warpingId': warpingId,
      });
      final plan    = res.data['plan'] as Map<String, dynamic>;
      final rawBeams = (plan['beams'] as List? ?? []);
      final generated = rawBeams.map<EditableBeam>((b) {
        final secs = (b['sections'] as List? ?? []).map<EditableBeamSection>((s) {
          return EditableBeamSection(
            warpYarnId:   s['warpYarnId']?.toString(),
            warpYarnName: s['warpYarnName']?.toString() ?? '',
            ends:         (s['ends'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        return EditableBeam(beamNo: (b['beamNo'] as num).toInt(), sections: secs);
      }).toList();
      beams.assignAll(generated);
      beamCount.value = generated.length;
      _syncEndsControllers();
      aiRemarks.value = plan['remarks']?.toString() ?? '';
      _snack('AI plan generated — review and edit below', isError: false);
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] as String? ?? 'AI generation failed', isError: true);
    } catch (e) {
      _snack('Unexpected error: $e', isError: true);
    } finally {
      isGenerating.value = false;
    }
  }

  void clearAiBadge() => aiRemarks.value = null;

  Future<void> submit() async {
    isSaving.value = true;
    try {
      final plan = await WarpingApi.createPlan(warpingId: warpingId, beams: beams);
      // Pop with the result; the caller (Warping_detail.dart) shows
      // the success snackbar on the parent overlay so it survives
      // the route teardown. Firing the snack from this controller
      // before/after pop racing the overlay teardown is what made
      // the toast invisible.
      Get.back(result: plan);
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] as String? ?? 'Failed to save', isError: true);
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      isSaving.value = false;
    }
  }

  void _snack(String msg, {required bool isError}) => Get.snackbar(
    isError ? 'Error' : 'Success', msg,
    backgroundColor: isError ? ErpColors.errorRed : ErpColors.successGreen,
    colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );
}
// ══════════════════════════════════════════════════════════════
//  WARPING BATCH CONTROLLER
//
//  The batches raised against one warping, and everything the sheet
//  that raises a new one needs: the beams the plan defines, which of
//  them are already claimed, and the open lots per warp yarn.
//
//  Beams already covered by a live batch are filtered out here rather
//  than left for the server to reject. The server does reject them —
//  two batches on one beam means the yarn is issued twice for it — but
//  discovering that after filling in a whole sheet is a poor way to
//  learn it. A cancelled batch drew nothing, so it releases its beams,
//  which is why the filter looks at status and not merely at presence.
// ══════════════════════════════════════════════════════════════
class WarpingBatchController extends GetxController {
  final String warpingId;
  final String jobId;
  WarpingBatchController({required this.warpingId, required this.jobId});

  final batches    = <WarpingBatchModel>[].obs;
  final isLoading  = true.obs;
  final isActing   = false.obs;
  final errorMsg   = Rxn<String>();

  /// Warp yarns on the job, and the open lots for each.
  final warpYarns  = <WarpYarnOption>[].obs;
  final lotStock   = <String, YarnLotStock>{}.obs;
  final contextLoaded = false.obs;

  /// Beam numbers the plan defines. Empty until a plan exists.
  final planBeamNos = <int>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([fetchBatches(), fetchContext(), fetchPlanBeams()]);
  }

  Future<void> fetchBatches() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      batches.value = await WarpingApi.listBatches(warpingId: warpingId);
    } on DioException catch (e) {
      errorMsg.value =
          e.response?.data?['message'] as String? ?? 'Failed to load batches';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchContext() async {
    try {
      final ctx = await WarpingApi.fetchPlanContext(jobId);
      warpYarns.value = ctx['warpYarns'] as List<WarpYarnOption>;
      lotStock.value = {
        for (final s in ctx['lotStock'] as List<YarnLotStock>) s.warpYarnId: s,
      };
      contextLoaded.value = true;
    } catch (_) {
      // Not fatal: the batch list still reads. The create sheet says so
      // itself rather than offering an empty lot picker.
      contextLoaded.value = false;
    }
  }

  Future<void> fetchPlanBeams() async {
    try {
      final plan = await WarpingApi.fetchPlan(warpingId);
      planBeamNos.value = (plan?.beams ?? []).map((b) => b.beamNo).toList()
        ..sort();
    } catch (_) {
      planBeamNos.clear();
    }
  }

  /// beamNo → the batch that already holds it.
  Map<int, String> get claimedBeams {
    final out = <int, String>{};
    for (final b in batches) {
      if (b.status == 'cancelled') continue;
      for (final n in b.beamNos) {
        out[n] = b.batchNo;
      }
    }
    return out;
  }

  List<int> get freeBeamNos {
    final taken = claimedBeams;
    return planBeamNos.where((n) => !taken.containsKey(n)).toList();
  }

  YarnLotStock lotsFor(String yarnId) =>
      lotStock[yarnId] ?? YarnLotStock.empty;

  /// Returns null on success, or a message to show.
  Future<String?> create({
    required List<int> beamNos,
    required List<BatchAllocation> allocations,
    String remarks = '',
  }) async {
    isActing.value = true;
    try {
      await WarpingApi.createBatch(
        warpingId: warpingId,
        beamNos: beamNos,
        allocations: allocations,
        remarks: remarks,
      );
      await fetchBatches();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Could not raise the batch';
    } catch (e) {
      return e.toString();
    } finally {
      isActing.value = false;
    }
  }

  Future<String?> issue(String id)    => _act(() => WarpingApi.issueBatch(id));
  Future<String?> complete(String id) => _act(() => WarpingApi.completeBatch(id));
  Future<String?> cancel(String id)   => _act(() => WarpingApi.cancelBatch(id));

  Future<String?> _act(Future<WarpingBatchModel> Function() run) async {
    isActing.value = true;
    try {
      await run();
      // Re-read rather than patching the row in place: issuing moves lot
      // balances, so the lot figures the create sheet shows are stale
      // the moment a batch is issued.
      await Future.wait([fetchBatches(), fetchContext()]);
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'The batch could not be updated';
    } catch (e) {
      return e.toString();
    } finally {
      isActing.value = false;
    }
  }
}
