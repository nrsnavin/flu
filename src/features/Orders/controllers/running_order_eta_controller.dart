import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

/// Per-elastic remaining + rate breakdown inside one in-flight job.
class RunningEtaElastic {
  final String elastic;
  final int plannedMeters;
  final int producedMeters;
  final int remainingMeters;
  final int headsAssigned;
  final int metersPerMachineDay;
  final int? shifts;
  final int? days;
  final String rateSource;        // posterior | plant | coldstart | missing
  final int posteriorObservations;

  const RunningEtaElastic({
    required this.elastic,
    required this.plannedMeters,
    required this.producedMeters,
    required this.remainingMeters,
    required this.headsAssigned,
    required this.metersPerMachineDay,
    required this.shifts,
    required this.days,
    required this.rateSource,
    required this.posteriorObservations,
  });
}

/// One job inside the order. Order ETA = max(job ETAs) + finish buffer.
class RunningEtaJob {
  final String? job;
  final num? jobOrderNo;
  final String? status;
  final String? machineLabel;
  final int? noOfHead;
  final int jobShifts;
  final int jobDays;
  final List<RunningEtaElastic> perElastic;

  const RunningEtaJob({
    required this.job,
    required this.jobOrderNo,
    required this.status,
    required this.machineLabel,
    required this.noOfHead,
    required this.jobShifts,
    required this.jobDays,
    required this.perElastic,
  });
}

/// Snapshot of the running-order completion-date prediction.
class RunningEtaResult {
  final DateTime expectedDate;
  final int workingDays;
  final int weavingDays;
  final int leadDays;
  final List<RunningEtaJob> jobs;
  final List<String> assumptions;
  final Map<String, int> rateSources;
  final bool late;
  final int lateWorkingDays;

  const RunningEtaResult({
    required this.expectedDate,
    required this.workingDays,
    required this.weavingDays,
    required this.leadDays,
    required this.jobs,
    required this.assumptions,
    required this.rateSources,
    required this.late,
    required this.lateWorkingDays,
  });

  factory RunningEtaResult.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) => DateTime.parse(v.toString());

    final risk = (j['risk'] as Map?) ?? const {};
    final rateSourcesRaw = (j['rateSources'] as Map?) ?? const {};

    List<RunningEtaJob> parseJobs() {
      final raw = (j['perJob'] as List?) ?? const [];
      return raw.whereType<Map>().map((m) {
        final elasticsRaw = (m['perElastic'] as List?) ?? const [];
        return RunningEtaJob(
          job:          m['job']?.toString(),
          jobOrderNo:   m['jobOrderNo'] as num?,
          status:       m['status']?.toString(),
          machineLabel: m['machineLabel']?.toString(),
          noOfHead:     (m['noOfHead'] as num?)?.toInt(),
          jobShifts:    (m['jobShifts']  as num?)?.toInt() ?? 0,
          jobDays:      (m['jobDays']    as num?)?.toInt() ?? 0,
          perElastic:   elasticsRaw.whereType<Map>().map((e) {
            return RunningEtaElastic(
              elastic:        e['elastic']?.toString() ?? '',
              plannedMeters:  (e['plannedMeters']        as num?)?.toInt() ?? 0,
              producedMeters: (e['producedMeters']       as num?)?.toInt() ?? 0,
              remainingMeters:(e['remainingMeters']      as num?)?.toInt() ?? 0,
              headsAssigned:  (e['headsAssigned']        as num?)?.toInt() ?? 0,
              metersPerMachineDay:(e['metersPerMachineDay'] as num?)?.toInt() ?? 0,
              shifts:         (e['shifts']               as num?)?.toInt(),
              days:           (e['days']                 as num?)?.toInt(),
              rateSource:     e['rateSource']?.toString() ?? 'missing',
              posteriorObservations:
                              (e['posteriorObservations'] as num?)?.toInt() ?? 0,
            );
          }).toList(),
        );
      }).toList();
    }

    // Defensive — backend should always include expectedDate when
    // ok:true, but if it's missing we fall back to "now" rather than
    // throwing a parse exception that silently hides the card.
    DateTime safeDate(dynamic v) {
      if (v == null) return DateTime.now();
      try { return parseDate(v); } catch (_) { return DateTime.now(); }
    }

    return RunningEtaResult(
      expectedDate:    safeDate(j['expectedDate']),
      workingDays:     (j['workingDays'] as num?)?.toInt() ?? 0,
      weavingDays:     (j['weavingDays'] as num?)?.toInt() ?? 0,
      leadDays:        (j['leadDays']    as num?)?.toInt() ?? 0,
      jobs:            parseJobs(),
      assumptions:     List<String>.from((j['assumptions'] as List?) ?? const []),
      rateSources: rateSourcesRaw.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      ),
      late:            risk['late'] == true,
      lateWorkingDays: (risk['lateWorkingDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Live ETA for an already-running order on the order detail screen.
/// Fetches once on view, and again on pull-to-refresh; degrades
/// silently if the backend is unreachable.
class RunningOrderEtaController extends GetxController {
  RunningOrderEtaController(this.orderId);
  final String orderId;

  final loading  = false.obs;
  final result   = Rxn<RunningEtaResult>();
  final errorMsg = Rxn<String>();
  final notApplicable = false.obs;     // backend told us NO_ACTIVE_JOBS / NO_RATE

  final _dio = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/order',
  );

  @override
  void onInit() {
    super.onInit();
    refreshEta();
  }

  Future<void> refreshEta() async {
    if (loading.value) return;
    loading.value = true;
    errorMsg.value = null;
    notApplicable.value = false;
    try {
      final res = await _dio.get('/$orderId/running-eta');
      final data = res.data is Map ? res.data as Map<String, dynamic> : const {};
      if (data['ok'] == true) {
        result.value = RunningEtaResult.fromJson(Map<String, dynamic>.from(data));
      } else if (data['success'] == true) {
        // Successful response, but no estimate produced — e.g. no
        // active jobs yet, or every job missing rate data. Hide
        // the card cleanly rather than showing an error.
        result.value = null;
        notApplicable.value = true;
      } else {
        result.value = null;
        errorMsg.value = data['message']?.toString();
      }
    } on DioException catch (e) {
      result.value = null;
      errorMsg.value = e.response?.data is Map
          ? (e.response?.data['message'] as String?)
          : null;
    } catch (e) {
      result.value = null;
      errorMsg.value = e.toString();
    } finally {
      loading.value = false;
    }
  }
}
