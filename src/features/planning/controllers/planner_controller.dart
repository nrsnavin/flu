import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

// Mirrors GET /api/v2/planner/suggest-plan, POST /accept, GET /latest
// (prod/api/planner.js). The optimiser numbers are all computed on the
// server; the client renders them and posts the accepted plan back
// verbatim. Accepting freezes the plan of record — it does not create
// jobs or move machines.

class PlanRow {
  final int orderNo;
  final String customer;
  final String elasticName;
  final num qtyMeters;
  final int heads;
  final int sequence;
  final int weavingDays;
  final String? projectedFinish;
  final String? dueDate;
  final bool late;
  final int lateWorkingDays;
  final bool changeover;
  final String rateSource; // posterior | plant | coldstart

  PlanRow.fromJson(Map<String, dynamic> j)
      : orderNo = (j['orderNo'] as num?)?.toInt() ?? 0,
        customer = '${j['customer'] ?? '—'}',
        elasticName = '${j['elasticName'] ?? 'Elastic'}',
        qtyMeters = (j['qtyMeters'] as num?) ?? 0,
        heads = (j['heads'] as num?)?.toInt() ?? 0,
        sequence = (j['sequence'] as num?)?.toInt() ?? 0,
        weavingDays = (j['weavingDays'] as num?)?.toInt() ?? 0,
        projectedFinish = j['projectedFinish']?.toString(),
        dueDate = j['dueDate']?.toString(),
        late = j['late'] == true,
        lateWorkingDays = (j['lateWorkingDays'] as num?)?.toInt() ?? 0,
        changeover = j['changeover'] == true,
        rateSource = '${j['rateSource'] ?? 'coldstart'}';
}

class MachinePlan {
  final String machineId;
  final String machineID;
  final int heads;
  final int changeovers;
  final List<PlanRow> rows;

  MachinePlan.fromJson(Map<String, dynamic> j)
      : machineId = '${j['machineId'] ?? ''}',
        machineID = '${j['machineID'] ?? '—'}',
        heads = (j['heads'] as num?)?.toInt() ?? 0,
        changeovers = (j['changeovers'] as num?)?.toInt() ?? 0,
        rows = (j['rows'] as List? ?? [])
            .map((e) => PlanRow.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

class PlanObjective {
  final int lines, placed, unplaceable, onTime, late, totalLateDays, changeovers, machinesUsed;
  PlanObjective.fromJson(Map<String, dynamic> j)
      : lines = (j['lines'] as num?)?.toInt() ?? 0,
        placed = (j['placed'] as num?)?.toInt() ?? 0,
        unplaceable = (j['unplaceable'] as num?)?.toInt() ?? 0,
        onTime = (j['onTime'] as num?)?.toInt() ?? 0,
        late = (j['late'] as num?)?.toInt() ?? 0,
        totalLateDays = (j['totalLateDays'] as num?)?.toInt() ?? 0,
        changeovers = (j['changeovers'] as num?)?.toInt() ?? 0,
        machinesUsed = (j['machinesUsed'] as num?)?.toInt() ?? 0;
}

class UnplaceableLine {
  final int orderNo;
  final String customer, elasticName, reason;
  final num qtyMeters;
  UnplaceableLine.fromJson(Map<String, dynamic> j)
      : orderNo = (j['orderNo'] as num?)?.toInt() ?? 0,
        customer = '${j['customer'] ?? '—'}',
        elasticName = '${j['elasticName'] ?? 'Elastic'}',
        reason = '${j['reason'] ?? ''}',
        qtyMeters = (j['qtyMeters'] as num?) ?? 0;
}

class PlannerController extends GetxController {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: 'http://13.233.117.153:2701/api/v2/planner');

  final horizon = 7.obs;
  final isLoading = false.obs;
  final isAccepting = false.obs;
  final errorMsg = RxnString();

  final objective = Rxn<PlanObjective>();
  final machines = <MachinePlan>[].obs;
  final unplaceable = <UnplaceableLine>[].obs;
  final assumptions = <String>[].obs;
  final aiRationale = RxnString();

  // Latest accepted plan-of-record summary.
  final acceptedAt = RxnString();
  final acceptedBy = RxnString();
  final acceptedCount = 0.obs;

  // Raw suggest payload, kept so /accept can round-trip it unchanged.
  Map<String, dynamic>? _raw;

  @override
  void onInit() {
    super.onInit();
    suggest();
    fetchLatest();
  }

  void setHorizon(int d) {
    if (horizon.value == d) return;
    horizon.value = d;
    suggest();
  }

  Future<void> suggest() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/suggest-plan', queryParameters: {'horizonDays': horizon.value});
      final data = Map<String, dynamic>.from(res.data as Map);
      _raw = data;
      objective.value = PlanObjective.fromJson(Map<String, dynamic>.from(data['objective'] ?? {}));
      machines.assignAll((data['machines'] as List? ?? [])
          .map((e) => MachinePlan.fromJson(Map<String, dynamic>.from(e)))
          .toList());
      unplaceable.assignAll((data['unplaceable'] as List? ?? [])
          .map((e) => UnplaceableLine.fromJson(Map<String, dynamic>.from(e)))
          .toList());
      assumptions.assignAll((data['assumptions'] as List? ?? []).map((e) => '$e').toList());
      final r = data['aiRationale']?.toString();
      aiRationale.value = (r != null && r.trim().isNotEmpty) ? r.trim() : null;
    } catch (_) {
      errorMsg.value = "Couldn't generate a plan";
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> accept() async {
    final raw = _raw;
    if (raw == null) return false;
    isAccepting.value = true;
    try {
      await _dio.post('/accept', data: {
        'generatedAt': raw['generatedAt'],
        'horizonDays': raw['horizonDays'],
        'objective': raw['objective'],
        'machines': raw['machines'],
        'assumptions': raw['assumptions'],
      });
      await fetchLatest();
      return true;
    } catch (_) {
      return false;
    } finally {
      isAccepting.value = false;
    }
  }

  Future<void> fetchLatest() async {
    try {
      final res = await _dio.get('/latest');
      final plan = (res.data is Map ? res.data['plan'] : null);
      if (plan is Map) {
        acceptedAt.value = plan['acceptedAt']?.toString();
        acceptedBy.value = plan['acceptedBy']?.toString();
        acceptedCount.value = (plan['assignments'] as List?)?.length ?? 0;
      } else {
        acceptedAt.value = null;
      }
    } catch (_) {
      // Non-fatal — the banner just won't show.
    }
  }
}
