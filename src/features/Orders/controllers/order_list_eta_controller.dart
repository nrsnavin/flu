import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

/// Compact ETA summary for a single order row — what the list chip needs.
class OrderEtaSummary {
  final DateTime expectedDate;
  final int workingDays;
  final bool late;
  final int lateWorkingDays;
  final int posteriorElastics;   // how many pairs used learned posterior
  final int totalElastics;       // total pairs scored — denominator for the badge

  const OrderEtaSummary({
    required this.expectedDate,
    required this.workingDays,
    required this.late,
    required this.lateWorkingDays,
    required this.posteriorElastics,
    required this.totalElastics,
  });

  factory OrderEtaSummary.fromJson(Map<String, dynamic> j) {
    final sources = (j['rateSources'] as Map?) ?? const {};
    int sum(String k) => (sources[k] as num?)?.toInt() ?? 0;
    return OrderEtaSummary(
      expectedDate:    DateTime.parse(j['expectedDate'].toString()),
      workingDays:     (j['workingDays']     as num?)?.toInt() ?? 0,
      late:            j['late'] == true,
      lateWorkingDays: (j['lateWorkingDays'] as num?)?.toInt() ?? 0,
      posteriorElastics: sum('posterior'),
      totalElastics:
          sum('posterior') + sum('plant') + sum('coldstart') + sum('missing'),
    );
  }
}

/// Drives the per-row ETA chip on the order list. Fetches ETAs for
/// many orders in one bulk request after the list loads. Lives
/// alongside the OrderListController so a status-tab change can
/// re-fetch only the ETAs that matter.
class OrderListEtaController extends GetxController {
  final byOrderId = <String, OrderEtaSummary>{}.obs;
  // Per-order reason for orders the backend returned ok:false on.
  // Lets the chip placeholder render 'ETA: <reason>' so the admin
  // sees *why* a specific row has no estimate (NOT_FOUND,
  // NOTHING_REMAINING, NO_RATE, COMPUTE_ERROR, NOT_RUNNING, …).
  final reasonByOrderId = <String, String>{}.obs;
  final loading   = false.obs;
  // Captured on the last failed bulk fetch so each row's placeholder
  // chip can show *why* the fetch failed instead of a silent "ETA
  // unavailable". Cleared when the next fetch succeeds.
  final lastError = RxnString();

  final _dio = ApiClient.buildClient(
    baseUrl: '${ApiConfig.baseUrl}/order',
  );

  /// Trigger a bulk fetch for the visible set of orders. Filters to
  /// in-flight statuses before hitting the network so we don't ask
  /// the backend for ETAs that'll come back NOT_RUNNING anyway.
  Future<void> fetchForOrders(
    List<({String id, String status})> orders,
  ) async {
    final ids = [
      for (final o in orders)
        if (o.status == 'Approved' || o.status == 'InProgress') o.id,
    ];
    if (ids.isEmpty) {
      byOrderId.clear();
      return;
    }
    loading.value = true;
    lastError.value = null;
    try {
      // Backend caps at 50 per call — chunk if the visible list is bigger.
      final all     = <String, OrderEtaSummary>{};
      final reasons = <String, String>{};
      for (var i = 0; i < ids.length; i += 50) {
        final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
        final res = await _dio.post('/running-eta-bulk', data: {'orderIds': chunk});
        final data = res.data is Map ? res.data as Map<String, dynamic> : const {};
        final etas = (data['etas'] as Map?) ?? const {};
        etas.forEach((k, v) {
          if (v is! Map) return;
          if (v['ok'] == true) {
            all[k.toString()] =
                OrderEtaSummary.fromJson(Map<String, dynamic>.from(v));
          } else {
            // Capture the reason the backend gave so the chip
            // placeholder is diagnostic, not generic.
            reasons[k.toString()] =
                (v['reason']?.toString() ?? 'UNKNOWN');
          }
        });
      }
      byOrderId.assignAll(all);
      reasonByOrderId.assignAll(reasons);
    } on DioException catch (e) {
      // Don't toast — surface inline on the chip placeholder so an
      // admin sees the failure but the page stays usable.
      lastError.value = _formatDioError(e);
    } catch (e) {
      lastError.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  String _formatDioError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String? bodyMsg;
    if (data is Map && data['message'] is String) {
      bodyMsg = data['message'] as String;
    } else if (data is String && data.isNotEmpty) {
      bodyMsg = data.length > 60 ? '${data.substring(0, 60)}…' : data;
    }
    if (code != null) {
      switch (code) {
        case 401: return 'Auth failed (401)';
        case 403: return 'Forbidden (403)';
        case 404: return 'Bulk route 404 — backend not updated';
        case 500: return 'Backend 500${bodyMsg != null ? ': $bodyMsg' : ''}';
      }
      return 'HTTP $code${bodyMsg != null ? ' — $bodyMsg' : ''}';
    }
    return e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout
        ? 'Timed out'
        : 'Network: ${e.message ?? e.type.name}';
  }

  void clear() => byOrderId.clear();
}
