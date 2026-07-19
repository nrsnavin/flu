import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// One entry in the "what-if M machines" curve returned by the
/// backend so the UI can show the trade-off live.
class WhatIfPoint {
  final int machines;
  final int workingDays;
  final DateTime expectedDate;
  const WhatIfPoint({
    required this.machines,
    required this.workingDays,
    required this.expectedDate,
  });
}

/// Snapshot of the heuristic prediction the backend returned. Keeps
/// the controller thin and the UI declarative.
class OrderEtaResult {
  final DateTime expectedDate;
  final DateTime optimistic;
  final DateTime pessimistic;
  final int workingDays;
  final int weavingDays;
  final int leadDays;
  final int optimisticDays;
  final int pessimisticDays;
  final int machineDays;
  final int machines;
  final int totalMeters;
  final int effRate;
  final double confidence;
  final bool usedColdStart;
  final List<String> assumptions;
  final List<WhatIfPoint> whatIf;
  final bool late;
  final int lateWorkingDays;

  const OrderEtaResult({
    required this.expectedDate,
    required this.optimistic,
    required this.pessimistic,
    required this.workingDays,
    required this.weavingDays,
    required this.leadDays,
    required this.optimisticDays,
    required this.pessimisticDays,
    required this.machineDays,
    required this.machines,
    required this.totalMeters,
    required this.effRate,
    required this.confidence,
    required this.usedColdStart,
    required this.assumptions,
    required this.whatIf,
    required this.late,
    required this.lateWorkingDays,
  });

  factory OrderEtaResult.fromJson(Map<String, dynamic> j) {
    DateTime parse(dynamic v) => DateTime.parse(v.toString());
    final whatIfList = (j['whatIf'] as List?) ?? const [];
    final risk = (j['risk'] as Map?) ?? const {};
    return OrderEtaResult(
      expectedDate:    parse(j['expectedDate']),
      optimistic:      parse(j['optimistic']),
      pessimistic:     parse(j['pessimistic']),
      workingDays:     (j['workingDays']     as num?)?.toInt() ?? 0,
      weavingDays:     (j['weavingDays']     as num?)?.toInt() ?? 0,
      leadDays:        (j['leadDays']        as num?)?.toInt() ?? 0,
      optimisticDays:  (j['optimisticDays']  as num?)?.toInt() ?? 0,
      pessimisticDays: (j['pessimisticDays'] as num?)?.toInt() ?? 0,
      machineDays:     ((j['machineDays']    as num?) ?? 0).round(),
      machines:        (j['machines']        as num?)?.toInt() ?? 1,
      totalMeters:     (j['totalMeters']     as num?)?.toInt() ?? 0,
      effRate:         (j['effRate']         as num?)?.toInt() ?? 0,
      confidence:      ((j['confidence']     as num?) ?? 0.7).toDouble(),
      usedColdStart:   j['usedColdStart'] == true,
      assumptions:     List<String>.from((j['assumptions'] as List?) ?? const []),
      late:            risk['late'] == true,
      lateWorkingDays: (risk['lateWorkingDays'] as num?)?.toInt() ?? 0,
      whatIf: whatIfList.whereType<Map>().map((m) => WhatIfPoint(
            machines:     (m['machines']    as num?)?.toInt() ?? 1,
            workingDays:  (m['workingDays'] as num?)?.toInt() ?? 0,
            expectedDate: parse(m['expectedDate']),
          )).toList(),
    );
  }
}

/// Live ETA for the order the admin is composing. Debounced so it
/// doesn't fire on every keystroke. Silently degrades — if the
/// backend is unreachable, the UI just hides the card; nothing
/// blocks the order-creation flow.
class OrderEtaController extends GetxController {
  final loading  = false.obs;
  final result   = Rxn<OrderEtaResult>();
  final errorMsg = Rxn<String>();

  /// Optional admin override of "how many machines do we dedicate?".
  /// Null = backend decides.
  final machinesOverride = RxnInt();

  Timer? _debounce;

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/order',
  );

  void scheduleEstimate({
    required List<Map<String, dynamic>> elasticOrdered,
    DateTime? supplyDate,
  }) {
    _debounce?.cancel();
    if (elasticOrdered.isEmpty) {
      result.value = null;
      errorMsg.value = null;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _estimate(elasticOrdered: elasticOrdered, supplyDate: supplyDate);
    });
  }

  Future<void> _estimate({
    required List<Map<String, dynamic>> elasticOrdered,
    DateTime? supplyDate,
  }) async {
    if (loading.value) return;
    loading.value = true;
    errorMsg.value = null;
    try {
      final body = <String, dynamic>{
        'elasticOrdered': elasticOrdered,
        if (supplyDate != null) 'supplyDate': supplyDate.toIso8601String(),
        if (machinesOverride.value != null) 'machines': machinesOverride.value,
      };
      final res = await _dio.post('/estimate-completion', data: body);
      final data = res.data is Map ? res.data as Map<String, dynamic> : const {};
      if (data['ok'] == true || data['success'] == true) {
        result.value = OrderEtaResult.fromJson(Map<String, dynamic>.from(data));
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

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
