import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:production/src/features/elastic/models/cost.dart';
import 'package:production/src/features/elastic/models/raw_material.dart';
import 'package:production/src/features/elastic/models/warp_yarn_input.dart';
import 'package:production/src/features/elastic/screens/elastic_list_page.dart';

class AddElasticController extends GetxController {
  final Dio _dio = Dio(BaseOptions(
    baseUrl:        "http://13.233.117.153:2701/api/v2",
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final Map<String, dynamic>? cloneData;
  final Map<String, dynamic>? editData;
  AddElasticController({this.cloneData, this.editData});

  bool get isEditMode => editData != null;
  String? editElasticId;

  // ── Basic info ─────────────────────────────────────────────
  final nameCtrl        = TextEditingController();
  final weaveTypeCtrl   = TextEditingController(text: "8");
  final pickCtrl        = TextEditingController();
  final noOfHookCtrl    = TextEditingController();
  final weightCtrl      = TextEditingController();
  final spandexEndsCtrl = TextEditingController();

  // ── Testing parameters ────────────────────────────────────
  final widthCtrl      = TextEditingController();
  final elongationCtrl = TextEditingController(text: "120");
  final recoveryCtrl   = TextEditingController(text: "90");
  final stretchCtrl    = TextEditingController();

  // ── State ─────────────────────────────────────────────────
  final isLoading          = true.obs;
  final loading            = false.obs;
  final searchQuery        = "".obs;
  final rawMaterialsLoaded = false.obs;
  final validationErrors   = <String, String>{}.obs;

  // ── Materials ─────────────────────────────────────────────
  final allMaterials      = <RawMaterialMini>[].obs;
  final warpMaterials     = <RawMaterialMini>[].obs;
  final rubberMaterials   = <RawMaterialMini>[].obs;
  final weftMaterials     = <RawMaterialMini>[].obs;
  final coveringMaterials = <RawMaterialMini>[].obs;

  // ── Selected materials ────────────────────────────────────
  final warpSpandex     = Rx<RawMaterialMini?>(null);
  final weftYarn        = Rx<RawMaterialMini?>(null);
  final spandexCovering = Rx<RawMaterialMini?>(null);

  final warpSpandexWeightCtrl = TextEditingController();
  final weftWeightCtrl        = TextEditingController();
  final coveringWeightCtrl    = TextEditingController();

  // ── Warp yarn rows ────────────────────────────────────────
  final warpYarns = <WarpYarnRow>[].obs;

  // ── Cost ──────────────────────────────────────────────────
  final totalCost     = 0.0.obs;
  final costBreakdown = <CostItem>[].obs;

  // ═══════════════════════════════════════════════════════════
  //  WARPING PLAN TEMPLATE STATE
  // ═══════════════════════════════════════════════════════════
  // planBeams drives the UI — one PlanBeam per beam card.
  // Each PlanBeam has >= 1 PlanSection (yarn dropdown + ends).
  final planBeamCount = 1.obs;
  final planBeams     = <PlanBeam>[].obs;

  /// Yarn options in plan dropdowns = warp yarns added above.
  /// Called reactively so dropdowns update as warp yarns are
  /// added / removed in the Warp Yarn Configuration section.
  List<RawMaterialMini> get planYarnOptions =>
      warpYarns
          .where((r) => r.material != null)
          .map((r) => r.material!)
          .toList();

  // ──────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _resetPlanBeams(1);   // start with 1 beam, 1 section
    fetchRawMaterials();
    addWarpYarnRow();
  }

  // ── Fetch raw materials ───────────────────────────────────
  Future<void> fetchRawMaterials() async {
    try {
      isLoading.value = true;
      final res = await _dio.get("/materials/get-raw-materials");

      allMaterials.assignAll(
        (res.data["materials"] as List)
            .map((e) => RawMaterialMini.fromJson(e))
            .toList(),
      );
      rubberMaterials.value  = allMaterials.where((m) => m.category == "Rubber").toList();
      warpMaterials.value    = allMaterials.where((m) => m.category == "warp").toList();
      weftMaterials.value    = allMaterials.where((m) => m.category == "weft").toList();
      coveringMaterials.value = allMaterials.where((m) => m.category == "covering").toList();

      if (cloneData != null) prefillFromElastic(cloneData!, isClone: true);
      if (editData   != null) prefillFromElastic(editData!,  isClone: false);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to load materials";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value          = false;
      rawMaterialsLoaded.value = true;
    }
  }

  List<RawMaterialMini> filteredMaterials(List<RawMaterialMini> source) {
    final q = searchQuery.value.toLowerCase();
    if (q.isEmpty) return source;
    return source.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  // ── Warp yarn row management ──────────────────────────────
  void addWarpYarnRow() => warpYarns.add(WarpYarnRow());

  void removeWarpYarnRow(int index) {
    warpYarns[index].dispose();
    warpYarns.removeAt(index);
    planBeams.refresh(); // dropdown options may have changed
    calculateCost();
  }

  // ── Cost calculation ──────────────────────────────────────
  void calculateCost() {
    double total = 0;
    final breakdown = <CostItem>[];

    void addItem(RawMaterialMini mat, double w, String cat) {
      final cost = mat.price * w / 1000;
      total += cost;
      breakdown.add(CostItem(name: mat.name, category: cat,
          weight: w, rate: mat.price, cost: cost));
    }

    final wsw = double.tryParse(warpSpandexWeightCtrl.text) ?? 0;
    if (warpSpandex.value != null && wsw > 0)
      addItem(warpSpandex.value!, wsw, "Spandex");

    final cw = double.tryParse(coveringWeightCtrl.text) ?? 0;
    if (spandexCovering.value != null && cw > 0)
      addItem(spandexCovering.value!, cw, "Covering");

    final ww = double.tryParse(weftWeightCtrl.text) ?? 0;
    if (weftYarn.value != null && ww > 0)
      addItem(weftYarn.value!, ww, "Weft");

    for (final row in warpYarns) {
      final rw = double.tryParse(row.weightCtrl.text) ?? 0;
      if (row.material != null && rw > 0)
        addItem(row.material!, rw, "Warp Yarn");
    }

    totalCost.value = total;
    costBreakdown.assignAll(breakdown);
  }

  // ═══════════════════════════════════════════════════════════
  //  WARPING PLAN TEMPLATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════

  /// Rebuild the beam list from scratch (used on init & prefill).
  void _resetPlanBeams(int count) {
    for (final b in planBeams) b.dispose();
    planBeams.assignAll(List.generate(count, (i) => PlanBeam(beamNo: i + 1)));
    planBeamCount.value = count;
  }

  /// Called when the beam-count stepper changes.
  void updatePlanBeamCount(int n) {
    if (n < 1 || n > 12) return;
    final current = planBeams.length;
    if (n > current) {
      for (var i = current; i < n; i++) {
        planBeams.add(PlanBeam(beamNo: i + 1));
      }
    } else {
      for (var i = current - 1; i >= n; i--) {
        planBeams[i].dispose();
        planBeams.removeAt(i);
      }
    }
    planBeamCount.value = n;
  }

  void addPlanSection(int beamIdx) {
    planBeams[beamIdx].sections.add(PlanSection());
    planBeams.refresh();
  }

  void removePlanSection(int beamIdx, int secIdx) {
    if (planBeams[beamIdx].sections.length <= 1) return;
    planBeams[beamIdx].sections[secIdx].dispose();
    planBeams[beamIdx].sections.removeAt(secIdx);
    planBeams.refresh();
  }

  void setPlanSectionYarn(int beamIdx, int secIdx, RawMaterialMini mat) {
    planBeams[beamIdx].sections[secIdx].warpYarnId   = mat.id;
    planBeams[beamIdx].sections[secIdx].warpYarnName = mat.name;
    planBeams.refresh();
  }

  /// Returns the warpingPlanTemplate payload map, or null if the
  /// user left the plan empty (no valid yarn+ends anywhere).
  Map<String, dynamic>? _buildPlanPayload() {
    bool hasAny = false;
    final beams = planBeams.map((b) {
      final sections = b.sections
          .where((s) => s.warpYarnId != null && s.ends > 0)
          .map((s) => {"warpYarn": s.warpYarnId, "ends": s.ends})
          .toList();
      if (sections.isNotEmpty) hasAny = true;
      final total = sections.fold<int>(0, (s, sec) => s + (sec["ends"] as int));
      return {"beamNo": b.beamNo, "totalEnds": total, "sections": sections};
    }).toList();

    if (!hasAny) return null;
    return {"noOfBeams": beams.length, "beams": beams};
  }

  // ── Form validation ───────────────────────────────────────
  bool _validate() {
    final errors = <String, String>{};

    if (nameCtrl.text.trim().isEmpty)
      errors['name'] = "Elastic name is required";

    if (pickCtrl.text.trim().isEmpty)
      errors['pick'] = "Pick is required";
    else if (double.tryParse(pickCtrl.text.trim()) == null)
      errors['pick'] = "Must be a number";

    if (noOfHookCtrl.text.trim().isEmpty)
      errors['noOfHook'] = "No. of hooks is required";
    else if (int.tryParse(noOfHookCtrl.text.trim()) == null)
      errors['noOfHook'] = "Must be a whole number";

    if (weightCtrl.text.trim().isEmpty)
      errors['weight'] = "Weight is required";
    else if (double.tryParse(weightCtrl.text.trim()) == null)
      errors['weight'] = "Must be a number";

    if (spandexEndsCtrl.text.trim().isEmpty)
      errors['spandexEnds'] = "Spandex ends is required";
    else if (int.tryParse(spandexEndsCtrl.text.trim()) == null)
      errors['spandexEnds'] = "Must be a whole number";

    if (warpSpandex.value == null)
      errors['warpSpandex'] = "Warp spandex material is required";
    else if (warpSpandexWeightCtrl.text.trim().isEmpty)
      errors['warpSpandexWeight'] = "Spandex weight is required";
    else if (double.tryParse(warpSpandexWeightCtrl.text.trim()) == null)
      errors['warpSpandexWeight'] = "Must be a number";

    if (widthCtrl.text.isNotEmpty &&
        double.tryParse(widthCtrl.text.trim()) == null)
      errors['width'] = "Must be a number";
    if (elongationCtrl.text.isNotEmpty &&
        double.tryParse(elongationCtrl.text.trim()) == null)
      errors['elongation'] = "Must be a number";
    if (recoveryCtrl.text.isNotEmpty &&
        double.tryParse(recoveryCtrl.text.trim()) == null)
      errors['recovery'] = "Must be a number";

    for (var i = 0; i < warpYarns.length; i++) {
      final row = warpYarns[i];
      if (row.material != null && row.weightCtrl.text.trim().isEmpty)
        errors['warpYarn_$i'] = "Weight required";
    }

    validationErrors.assignAll(errors);
    return errors.isEmpty;
  }

  void clearError(String key) {
    if (validationErrors.containsKey(key)) validationErrors.remove(key);
  }

  // ── Build payload ─────────────────────────────────────────
  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      "name":        nameCtrl.text.trim(),
      "weaveType":   weaveTypeCtrl.text.trim().isEmpty ? "8" : weaveTypeCtrl.text.trim(),
      "pick":        double.tryParse(pickCtrl.text)       ?? 0,
      "noOfHook":    int.tryParse(noOfHookCtrl.text)      ?? 0,
      "weight":      double.tryParse(weightCtrl.text)     ?? 0.0,
      "spandexEnds": int.tryParse(spandexEndsCtrl.text)   ?? 0,
      "testingParameters": {
        "width":      double.tryParse(widthCtrl.text)       ?? 0,
        "elongation": double.tryParse(elongationCtrl.text)  ?? 120,
        "recovery":   double.tryParse(recoveryCtrl.text)    ?? 90,
        "strech":     stretchCtrl.text.trim(),
      },
      "warpYarn": warpYarns
          .where((r) => r.material != null)
          .map((r) => {
        "id":     r.material!.id,
        "weight": double.tryParse(r.weightCtrl.text) ?? 0,
        "ends":   int.tryParse(r.endsCtrl.text)      ?? 0,
        "type":   r.typeCtrl.text,
      })
          .toList(),
    };

    if (warpSpandex.value != null) {
      payload["warpSpandex"] = {
        "id":     warpSpandex.value!.id,
        "weight": double.tryParse(warpSpandexWeightCtrl.text) ?? 0,
      };
    }
    if (weftYarn.value != null) {
      payload["weftYarn"] = {
        "id":     weftYarn.value!.id,
        "weight": double.tryParse(weftWeightCtrl.text) ?? 0,
      };
    }
    if (spandexCovering.value != null) {
      payload["spandexCovering"] = {
        "id":     spandexCovering.value!.id,
        "weight": double.tryParse(coveringWeightCtrl.text) ?? 0,
      };
    }

    // Attach plan only if user configured something
    final plan = _buildPlanPayload();
    if (plan != null) payload["warpingPlanTemplate"] = plan;

    return payload;
  }

  // ── Create ────────────────────────────────────────────────
  Future<void> submitElastic() async {
    if (!_validate()) {
      Get.snackbar("Validation Failed",
          "Please fix the highlighted errors before saving.",
          backgroundColor: const Color(0xFFD97706),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3));
      return;
    }

    bool success = false;
    try {
      loading.value = true;
      await _dio.post("/elastic/create-elastic", data: _buildPayload());
      success = true;
      Get.snackbar("Success", "Elastic created successfully",
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to create elastic";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      if (success) Get.to(ElasticListPage());
    }
  }

  // ── Update ────────────────────────────────────────────────
  VoidCallback? onSuccessCallback;

  Future<void> updateElastic() async {
    if (editElasticId == null) return;
    if (!_validate()) {
      Get.snackbar("Validation Failed",
          "Please fix the highlighted errors before saving.",
          backgroundColor: const Color(0xFFD97706),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3));
      return;
    }

    bool success = false;
    try {
      loading.value = true;
      final payload  = _buildPayload();
      payload["_id"] = editElasticId;
      await _dio.put("/elastic/update-elastic", data: payload);
      success = true;
      Get.snackbar("Updated", "Elastic updated successfully",
          backgroundColor: const Color(0xFF16A34A),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? "Failed to update elastic";
      Get.snackbar("Error", msg,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
      if (success) onSuccessCallback?.call();
    }
  }

  // ── Prefill (clone or edit) ───────────────────────────────
  void prefillFromElastic(Map<String, dynamic> e, {required bool isClone}) {
    nameCtrl.text        = isClone ? "${e["name"]} (Clone)" : (e["name"] ?? "");
    weaveTypeCtrl.text   = e["weaveType"]?.toString()   ?? "8";
    pickCtrl.text        = e["pick"]?.toString()        ?? "";
    noOfHookCtrl.text    = e["noOfHook"]?.toString()    ?? "";
    weightCtrl.text      = e["weight"]?.toString()      ?? "";
    spandexEndsCtrl.text = e["spandexEnds"]?.toString() ?? "";

    if (!isClone) editElasticId = e["_id"]?.toString();

    if (e["testingParameters"] != null) {
      final tp = e["testingParameters"] as Map;
      widthCtrl.text      = tp["width"]?.toString()      ?? "";
      elongationCtrl.text = tp["elongation"]?.toString() ?? "120";
      recoveryCtrl.text   = tp["recovery"]?.toString()   ?? "90";
      stretchCtrl.text    = (tp["strech"] ?? tp["stretch"])?.toString() ?? "";
    }

    if (e["warpSpandex"] != null) {
      final raw = e["warpSpandex"];
      final id  = raw["id"] is Map ? raw["id"]["_id"] : raw["id"]?.toString();
      warpSpandex.value = rubberMaterials.firstWhereOrNull((m) => m.id == id);
      warpSpandexWeightCtrl.text = (raw["weight"] ?? 0).toString();
    }
    if (e["spandexCovering"] != null) {
      final raw = e["spandexCovering"];
      final id  = raw["id"] is Map ? raw["id"]["_id"] : raw["id"]?.toString();
      spandexCovering.value = coveringMaterials.firstWhereOrNull((m) => m.id == id);
      coveringWeightCtrl.text = (raw["weight"] ?? 0).toString();
    }
    if (e["weftYarn"] != null) {
      final raw = e["weftYarn"];
      final id  = raw["id"] is Map ? raw["id"]["_id"] : raw["id"]?.toString();
      weftYarn.value = weftMaterials.firstWhereOrNull((m) => m.id == id);
      weftWeightCtrl.text = (raw["weight"] ?? 0).toString();
    }

    for (final row in warpYarns) row.dispose();
    warpYarns.clear();
    for (final w in (e["warpYarn"] as List? ?? [])) {
      final id  = w["id"] is Map ? w["id"]["_id"] : w["id"]?.toString();
      final row = WarpYarnRow()
        ..prefill(
          mat: warpMaterials.firstWhereOrNull((m) => m.id == id),
          w: (w["weight"] ?? 0).toDouble(),
          e: w["ends"] ?? 0,
          t: w["type"] ?? "",
        );
      warpYarns.add(row);
    }
    if (warpYarns.isEmpty) addWarpYarnRow();

    // ── Prefill warping plan template ─────────────────────
    final tpl = e["warpingPlanTemplate"];
    if (tpl != null && (tpl["beams"] as List?)?.isNotEmpty == true) {
      for (final b in planBeams) b.dispose();
      planBeams.clear();
      for (final b in (tpl["beams"] as List)) {
        final sections = (b["sections"] as List? ?? []).map((s) {
          // warpYarn may be populated (Map) or just an ID string
          final yarnId = s["warpYarn"] is Map
              ? (s["warpYarn"]["_id"] ?? s["warpYarn"]["id"])?.toString()
              : s["warpYarn"]?.toString();
          final mat = allMaterials.firstWhereOrNull((m) => m.id == yarnId);
          return PlanSection(
            warpYarnId:   yarnId,
            warpYarnName: mat?.name ?? s["warpYarnName"]?.toString() ?? "",
            initialEnds:  (s["ends"] ?? 0) as int,
          );
        }).toList();
        planBeams.add(PlanBeam(
          beamNo:   (b["beamNo"] as num?)?.toInt() ?? planBeams.length + 1,
          sections: sections,
        ));
      }
      planBeamCount.value = planBeams.length;
      if (planBeams.isEmpty) _resetPlanBeams(1);
    }

    calculateCost();
  }

  @override
  void onClose() {
    for (final ctrl in [
      nameCtrl, weaveTypeCtrl, pickCtrl, noOfHookCtrl, weightCtrl,
      spandexEndsCtrl, widthCtrl, elongationCtrl, recoveryCtrl, stretchCtrl,
      warpSpandexWeightCtrl, weftWeightCtrl, coveringWeightCtrl,
    ]) ctrl.dispose();
    for (final row in warpYarns) row.dispose();
    for (final b in planBeams) b.dispose();
    super.onClose();
  }
}

// ══════════════════════════════════════════════════════════════
//  WarpYarnRow  (unchanged from original)
// ══════════════════════════════════════════════════════════════
class WarpYarnRow {
  RawMaterialMini? material;
  final endsCtrl   = TextEditingController();
  final typeCtrl   = TextEditingController();
  final weightCtrl = TextEditingController();

  WarpYarnRow();

  void prefill({RawMaterialMini? mat, double w = 0, int e = 0, String t = ""}) {
    material        = mat;
    weightCtrl.text = w > 0 ? w.toString() : "";
    endsCtrl.text   = e > 0 ? e.toString() : "";
    typeCtrl.text   = t;
  }

  void dispose() {
    endsCtrl.dispose();
    typeCtrl.dispose();
    weightCtrl.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
//  PlanSection — one yarn + ends row inside a beam
// ══════════════════════════════════════════════════════════════
class PlanSection {
  String? warpYarnId;
  String? warpYarnName;
  final TextEditingController endsCtrl;

  PlanSection({
    this.warpYarnId,
    this.warpYarnName,
    int initialEnds = 0,
  }) : endsCtrl = TextEditingController(
      text: initialEnds > 0 ? initialEnds.toString() : "");

  int get ends => int.tryParse(endsCtrl.text.trim()) ?? 0;

  void dispose() => endsCtrl.dispose();
}

// ══════════════════════════════════════════════════════════════
//  PlanBeam — one beam card; contains 1..n PlanSections
// ══════════════════════════════════════════════════════════════
class PlanBeam {
  int beamNo;
  final List<PlanSection> sections;

  PlanBeam({required this.beamNo, List<PlanSection>? sections})
      : sections = sections ?? [PlanSection()];

  int get totalEnds => sections.fold(0, (s, sec) => s + sec.ends);

  void dispose() {
    for (final s in sections) s.dispose();
  }
}