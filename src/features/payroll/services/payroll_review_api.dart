import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../models/payroll_review_models.dart';

/// What the server said, in its words, or [fallback].
String payrollMessage(Object e, String fallback) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.response?.statusCode == 403) return 'You do not have access to payroll.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check the connection and try again.';
    }
  }
  return fallback;
}

class PayrollReviewApi {
  static final Dio _dio = ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/payroll');
  static final _ymd = DateFormat('yyyy-MM-dd');

  /// Every slip of the month against the worker's last three months.
  static Future<PayrollCheck> check({required int year, required int month}) async {
    final r = await _dio.get('/check', queryParameters: {'year': year, 'month': month});
    return PayrollCheck.fromJson(Map<String, dynamic>.from((r.data as Map)['data'] as Map));
  }

  /// A worker's ledger between two days, with the balance carried in.
  static Future<EmployeeLedger> ledger(String employeeId, {required DateTime from, required DateTime to}) async {
    final r = await _dio.get('/ledger/$employeeId', queryParameters: {'from': _ymd.format(from), 'to': _ymd.format(to)});
    return EmployeeLedger.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}
