import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../models/models.dart';
import 'cont.dart' show WarpingApi;
import '../../../core/app_config.dart';

// Mirrors GET /api/v2/warping/optimize-layout/:warpingId (prod/api/warping.js).
// First-fit-decreasing bin-pack of warp-yarn ends into beams. Deterministic;
// the admin reviews the proposal and applies it via /warpingPlan/create.

class OptimBeamSection {
  final String warpYarnId;
  final String warpYarnName;
  final int ends;
  OptimBeamSection.fromJson(Map<String, dynamic> j)
      : warpYarnId = '${j['warpYarnId'] ?? ''}',
        warpYarnName = '${j['warpYarnName'] ?? 'Yarn'}',
        ends = (j['ends'] as num?)?.toInt() ?? 0;
}

class OptimBeam {
  final int beamNo;
  final int totalEnds;
  final int fillPct;
  final List<OptimBeamSection> sections;
  OptimBeam.fromJson(Map<String, dynamic> j)
      : beamNo = (j['beamNo'] as num?)?.toInt() ?? 0,
        totalEnds = (j['totalEnds'] as num?)?.toInt() ?? 0,
        fillPct = (j['fillPct'] as num?)?.toInt() ?? 0,
        sections = (j['sections'] as List? ?? [])
            .map((e) => OptimBeamSection.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

class OptimMetrics {
  final int beamsUsed, baselineBeams, beamsSaved, totalEnds, totalYarns, changeovers, fillRate;
  OptimMetrics.fromJson(Map<String, dynamic> j)
      : beamsUsed = (j['beamsUsed'] as num?)?.toInt() ?? 0,
        baselineBeams = (j['baselineBeams'] as num?)?.toInt() ?? 0,
        beamsSaved = (j['beamsSaved'] as num?)?.toInt() ?? 0,
        totalEnds = (j['totalEnds'] as num?)?.toInt() ?? 0,
        totalYarns = (j['totalYarns'] as num?)?.toInt() ?? 0,
        changeovers = (j['changeovers'] as num?)?.toInt() ?? 0,
        fillRate = (j['fillRate'] as num?)?.toInt() ?? 0;
}

class OptimizeLayoutController extends GetxController {
  final String warpingId;
  OptimizeLayoutController(this.warpingId);

  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/warping');

  final capacity = 600.obs;
  final isLoading = false.obs;
  final isApplying = false.obs;
  final errorMsg = RxnString();
  final message = RxnString(); // e.g. "no warp-yarn ends found"

  final metrics = Rxn<OptimMetrics>();
  final beams = <OptimBeam>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  void setCapacity(int c) {
    if (capacity.value == c) return;
    capacity.value = c;
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    message.value = null;
    try {
      final res = await _dio.get('/optimize-layout/$warpingId',
          queryParameters: {'capacity': capacity.value});
      final data = Map<String, dynamic>.from(res.data as Map);
      final m = data['metrics'];
      metrics.value = m is Map ? OptimMetrics.fromJson(Map<String, dynamic>.from(m)) : null;
      beams.assignAll((data['beams'] as List? ?? [])
          .map((e) => OptimBeam.fromJson(Map<String, dynamic>.from(e)))
          .toList());
      if (beams.isEmpty) {
        message.value = data['message']?.toString() ??
            'No warp-yarn ends found on this warping.';
      }
    } catch (_) {
      errorMsg.value = "Couldn't optimise this layout";
    } finally {
      isLoading.value = false;
    }
  }

  /// Applies the proposed layout as the warping plan of record.
  Future<bool> apply() async {
    if (beams.isEmpty) return false;
    isApplying.value = true;
    try {
      final editable = beams
          .map((b) => EditableBeam(
                beamNo: b.beamNo,
                sections: b.sections
                    .map((s) => EditableBeamSection(
                          warpYarnId: s.warpYarnId,
                          warpYarnName: s.warpYarnName,
                          ends: s.ends,
                        ))
                    .toList(),
              ))
          .toList();
      final m = metrics.value;
      await WarpingApi.createPlan(
        warpingId: warpingId,
        beams: editable,
        remarks: m != null
            ? 'AI-optimised layout · ${m.beamsUsed} beams · ${m.fillRate}% fill'
            : 'AI-optimised layout',
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      isApplying.value = false;
    }
  }
}
