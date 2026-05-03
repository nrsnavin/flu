import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/models.dart';
import '../screens/pdf.dart';
import 'package:production/src/features/Orders/controllers/add_order_controller.dart'
    show buildActorPayload;

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

  // Backend switched these endpoints from PUT to POST so the JSON
  // body always survives reverse-proxy hops. `id` now rides in body.
  static Future<void> start(String id) async =>
      _dio.post('/start', data: {'id': id, 'actor': buildActorPayload()});

  static Future<void> complete(String id) async =>
      _dio.post('/complete', data: {'id': id, 'actor': buildActorPayload()});

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
//  KEY DESIGN: All TextEditingControllers (ends + maxMeters) are
//  owned here. _syncControllers() is called after every structural
//  change to beams so text fields always reflect current model data.
//
//  COPY TEMPLATE:  prefillTemplate is stored after fetch.
//  copyTemplate() appends a fresh set of beams from the template,
//  renumbered from (current beam count + 1).
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

  // ── Combine beams mode ──────────────────────────────────
  final isCombineMode = false.obs;
  final selectedBeams = <int>[].obs; // indices of beams selected for combine

  void toggleCombineMode() {
    isCombineMode.value = !isCombineMode.value;
    selectedBeams.clear();
  }

  void toggleBeamSelection(int beamIndex) {
    if (!isCombineMode.value) return;
    if (selectedBeams.contains(beamIndex)) {
      selectedBeams.remove(beamIndex);
    } else if (selectedBeams.length < 2) {
      selectedBeams.add(beamIndex);
      if (selectedBeams.length == 2) {
        _executeCombine(selectedBeams[0], selectedBeams[1]);
      }
    }
  }

  void _executeCombine(int bi1, int bi2) {
    if (bi1 == bi2) { selectedBeams.clear(); return; }
    final idx1 = bi1 < bi2 ? bi1 : bi2;
    final idx2 = bi1 < bi2 ? bi2 : bi1;

    final b1 = beams[idx1];
    final b2 = beams[idx2];

    final allSections = [...b1.sections, ...b2.sections];

    final halfA = <EditableBeamSection>[];
    final halfB = <EditableBeamSection>[];

    // For odd-ends sections: alternate which beam gets the +1
    // so both beams end up with the same (or ±1) total ends.
    bool aGetsExtra = true; // flip on each odd section

    for (final s in allSections) {
      final isOdd  = s.ends.isOdd;
      final half   = s.ends ~/ 2;         // floor
      final aEnds  = isOdd && aGetsExtra  ? half + 1 : half;
      final bEnds  = isOdd && !aGetsExtra ? half + 1 : half;

      halfA.add(EditableBeamSection(
        warpYarnId:   s.warpYarnId,
        warpYarnName: s.warpYarnName,
        ends:         aEnds > 0 ? aEnds : 1,
        maxMeters:    s.maxMeters,
      ));
      halfB.add(EditableBeamSection(
        warpYarnId:   s.warpYarnId,
        warpYarnName: s.warpYarnName,
        ends:         bEnds > 0 ? bEnds : 1,
        maxMeters:    s.maxMeters,
      ));

      if (isOdd) aGetsExtra = !aGetsExtra; // flip for next odd section
    }

    final newList = beams.toList();
    final beamA = EditableBeam(beamNo: b1.beamNo, sections: halfA, pairedBeamNo: b2.beamNo);
    final beamB = EditableBeam(beamNo: b2.beamNo, sections: halfB, pairedBeamNo: b1.beamNo);
    newList[idx1] = beamA;
    newList[idx2] = beamB;
    beams.assignAll(newList);
    beamCount.value = beams.length;
    _syncControllers();
    selectedBeams.clear();
    isCombineMode.value = false;
    _snack(
      'Beam ${b1.beamNo} + Beam ${b2.beamNo} combined — ends split across both beams',
      isError: false,
    );
  }  // ── TextEditingControllers owned here ────────────────────
  final Map<String, TextEditingController> _endsCtrlMap      = {};
  final Map<String, TextEditingController> _maxMetersCtrlMap = {};

  TextEditingController endsCtrl(int bi, int si) {
    final key = '${bi}_$si';
    return _endsCtrlMap.putIfAbsent(key, () => TextEditingController());
  }

  TextEditingController maxMetersCtrl(int bi, int si) {
    final key = '${bi}_$si';
    return _maxMetersCtrlMap.putIfAbsent(key, () => TextEditingController());
  }

  void _syncControllers() {
    for (int bi = 0; bi < beams.length; bi++) {
      for (int si = 0; si < beams[bi].sections.length; si++) {
        final sec = beams[bi].sections[si];

        // ends
        final endsText = sec.ends > 0 ? '${sec.ends}' : '';
        final ec = endsCtrl(bi, si);
        if (ec.text != endsText) {
          ec.value = ec.value.copyWith(
            text: endsText,
            selection: TextSelection.collapsed(offset: endsText.length),
          );
        }

        // maxMeters
        final mmText = sec.maxMeters > 0 ? _fmtDouble(sec.maxMeters) : '';
        final mc = maxMetersCtrl(bi, si);
        if (mc.text != mmText) {
          mc.value = mc.value.copyWith(
            text: mmText,
            selection: TextSelection.collapsed(offset: mmText.length),
          );
        }
      }
    }
    // Remove controllers for positions that no longer exist
    void pruneMap(Map<String, TextEditingController> map) {
      map.removeWhere((key, ctrl) {
        final parts = key.split('_');
        final bi = int.tryParse(parts[0]) ?? 999;
        final si = int.tryParse(parts[1]) ?? 999;
        if (bi >= beams.length) { ctrl.dispose(); return true; }
        if (si >= beams[bi].sections.length) { ctrl.dispose(); return true; }
        return false;
      });
    }
    pruneMap(_endsCtrlMap);
    pruneMap(_maxMetersCtrlMap);
  }

  String _fmtDouble(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
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
    for (final c in _endsCtrlMap.values)      c.dispose();
    for (final c in _maxMetersCtrlMap.values)  c.dispose();
    _endsCtrlMap.clear();
    _maxMetersCtrlMap.clear();
    super.onClose();
  }

  void _initBeams() {
    beams.assignAll([EditableBeam(beamNo: 1)]);
    _syncControllers();
  }

  Future<void> _fetchContext() async {
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final ctx = await WarpingApi.fetchPlanContext(jobId);
      warpYarns.value = ctx['warpYarns'] as List<WarpYarnOption>;
      // Auto-prefill from first elastic template
      final tpl = ctx['prefillTemplate'] as Map<String, dynamic>?;
      if (tpl != null) {
        _prefillFromTemplate(tpl, announce: true);
      }
    } on DioException catch (e) {
      errorMsg.value = e.response?.data?['message'] as String? ?? 'Failed to load warp yarns';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _prefillFromTemplate(Map<String, dynamic> tpl, {bool announce = false}) {
    final rawBeams = tpl['beams'] as List? ?? [];
    if (rawBeams.isEmpty) return;
    final filled = _beamsFromRaw(rawBeams, startBeamNo: 1);
    beams.assignAll(filled);
    beamCount.value = filled.length;
    _syncControllers();
    if (announce) {
      aiRemarks.value = '✦ Pre-filled from elastic warping plan template — review and adjust.';
    }
  }

  /// Duplicates the beam at [beamIndex], appended as the next beam.
  void repeatBeam(int beamIndex) {
    if (beamIndex < 0 || beamIndex >= beams.length) return;
    final src    = beams[beamIndex];
    final newNo  = beams.length + 1;
    final copy   = EditableBeam(
      beamNo: newNo,
      sections: src.sections.map((s) => EditableBeamSection(
        warpYarnId:   s.warpYarnId,
        warpYarnName: s.warpYarnName,
        ends:         s.ends,
        maxMeters:    s.maxMeters,
      )).toList(),
    );
    beams.add(copy);
    beamCount.value = beams.length;
    _syncControllers();
    _snack('Beam ${src.beamNo} repeated as Beam $newNo', isError: false);
  }

  List<EditableBeam> _beamsFromRaw(List raw, {required int startBeamNo}) {
    return raw.asMap().entries.map<EditableBeam>((entry) {
      final b    = entry.value as Map<String, dynamic>;
      final secs = (b['sections'] as List? ?? []).map<EditableBeamSection>((s) {
        return EditableBeamSection(
          warpYarnId:   s['warpYarnId']?.toString(),
          warpYarnName: s['warpYarnName']?.toString() ?? '',
          ends:         (s['ends']      as num?)?.toInt()    ?? 0,
          maxMeters:    (s['maxMeters'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
      if (secs.isEmpty) secs.add(EditableBeamSection());
      return EditableBeam(beamNo: startBeamNo + entry.key, sections: secs);
    }).toList();
  }

  void updateBeamCount(int n) {
    if (n <= 0) return;
    beamCount.value = n;
    beams.assignAll(List.generate(n, (i) => EditableBeam(beamNo: i + 1)));
    _syncControllers();
  }

  void addSection(int beamIndex) {
    beams[beamIndex].sections.add(EditableBeamSection());
    beams.refresh();
    _syncControllers();
  }

  void removeSection(int beamIndex, int sectionIndex) {
    if (beams[beamIndex].sections.length > 1) {
      beams[beamIndex].sections.removeAt(sectionIndex);
      beams.refresh();
      _syncControllers();
    }
  }

  void updateYarn(int beamIndex, int sectionIndex, WarpYarnOption yarn) {
    beams[beamIndex].sections[sectionIndex].warpYarnId   = yarn.id;
    beams[beamIndex].sections[sectionIndex].warpYarnName = yarn.name;
    beams.refresh();
  }

  void updateEnds(int beamIndex, int sectionIndex, int ends) {
    beams[beamIndex].sections[sectionIndex].ends = ends;
    beams.refresh();
  }

  void updateMaxMeters(int beamIndex, int sectionIndex, double maxMeters) {
    beams[beamIndex].sections[sectionIndex].maxMeters = maxMeters;
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
      final plan     = res.data['plan'] as Map<String, dynamic>;
      final rawBeams = plan['beams'] as List? ?? [];
      final generated = _beamsFromRaw(rawBeams, startBeamNo: 1);
      beams.assignAll(generated);
      beamCount.value = generated.length;
      _syncControllers();
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