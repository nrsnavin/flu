import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// Mirrors GET /api/v2/wastage/root-cause (prod/api/wastage.js).

class RcTotals {
  final num qty, count, penalty;
  RcTotals(this.qty, this.count, this.penalty);
  factory RcTotals.fromJson(Map<String, dynamic> j) =>
      RcTotals((j['qty'] ?? 0) as num, (j['count'] ?? 0) as num, (j['penalty'] ?? 0) as num);
}

class RcRow {
  final String label, sub;
  final num qty, count;
  RcRow(this.label, this.sub, this.qty, this.count);
}

class RcInsight {
  final String severity, title, detail;
  RcInsight(this.severity, this.title, this.detail);
}

class WastageRootCause {
  final RcTotals totals;
  final List<RcRow> byReason, byOperator, byMachine, reasonMachine;
  final List<RcInsight> insights;
  final String? aiSummary;
  WastageRootCause(this.totals, this.byReason, this.byOperator, this.byMachine,
      this.reasonMachine, this.insights, this.aiSummary);

  factory WastageRootCause.fromJson(Map<String, dynamic> j) {
    List<RcRow> rows(String key, String Function(Map) label, String Function(Map) sub) =>
        (j[key] as List? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e);
          return RcRow(label(m), sub(m), (m['qty'] ?? 0) as num, (m['count'] ?? 0) as num);
        }).toList();
    return WastageRootCause(
      RcTotals.fromJson(Map<String, dynamic>.from(j['totals'] ?? {})),
      rows('byReason', (m) => '${m['reason'] ?? '—'}', (_) => ''),
      rows('byOperator', (m) => '${m['name'] ?? 'Unknown'}', (m) => '${m['department'] ?? ''}'),
      rows('byMachine', (m) => 'Machine ${m['machineID'] ?? '—'}', (_) => ''),
      rows('reasonMachine', (m) => '${m['reason'] ?? '—'}', (m) => '${m['machineID'] ?? '—'}'),
      (j['insights'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e);
        return RcInsight('${m['severity'] ?? 'info'}', '${m['title'] ?? ''}', '${m['detail'] ?? ''}');
      }).toList(),
      j['aiSummary']?.toString(),
    );
  }
}

class WastageRootCauseController extends GetxController {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/wastage');

  final data = Rxn<WastageRootCause>();
  final isLoading = false.obs;
  final errorMsg = Rxn<String>();
  final days = 30.obs;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  void setDays(int d) {
    days.value = d;
    fetch();
  }

  Future<void> fetch() async {
    isLoading.value = true;
    errorMsg.value = null;
    try {
      final res = await _dio.get('/root-cause', queryParameters: {'days': days.value});
      data.value = WastageRootCause.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      errorMsg.value = 'Could not load root-cause insights';
    } finally {
      isLoading.value = false;
    }
  }
}
