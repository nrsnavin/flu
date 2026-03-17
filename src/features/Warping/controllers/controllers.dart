import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../screens/pdf.dart';


// ── API ───────────────────────────────────────────────────────
class WarpingApi {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2/warping',
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

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

  static Future<void> start(String id) async =>
      _dio.put('/start', queryParameters: {'id': id});

  static Future<void> complete(String id) async =>
      _dio.put('/complete', queryParameters: {'id': id});

  // FIX: was { _id: id } on backend — now fixed to { warping: id }
  static Future<WarpingPlanDetail?> fetchPlan(String warpingId) async {
    final res = await _dio.get('/warpingPlan', queryParameters: {'id': warpingId});
    if (res.data['exists'] == true) {
      return WarpingPlanDetail.fromJson(res.data['plan'] as Map<String, dynamic>);
    }
    return null;
  }

  /// Returns { warpYarns: List<WarpYarnOption>, prefillTemplate: Map? }
  static Future<Map<String, dynamic>> fetchPlanContext(String jobId) async {
    final res = await _dio.get('/plan-context/$jobId');
    final yarns = (res.data['warpYarns'] as List? ?? [])
        .map((e) => WarpYarnOption.fromJson(e as Map<String, dynamic>))
        .toList();
    final template = res.data['prefillTemplate'] as Map<String, dynamic>?;
    return {'warpYarns': yarns, 'prefillTemplate': template};
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

  Future<bool> completeWarping() async {
    isActing.value = true;
    try {
      await WarpingApi.complete(warpingId);
      await fetchDetail();
      _snack('Warping completed successfully', isError: false);
      return true;
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] as String? ?? 'Failed to complete', isError: true);
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

  void _snack(String msg, {required bool isError}) => Get.snackbar(
    isError ? 'Error' : 'Success', msg,
    backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
    colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );
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

  static final _aiDio = Dio(BaseOptions(
    baseUrl:        'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

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
      _snack('Warping plan saved', isError: false);
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
    backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
    colorText: Colors.white, snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );
}