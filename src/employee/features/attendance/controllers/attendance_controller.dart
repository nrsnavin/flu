import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

/// Loads the logged-in employee's monthly attendance grid from
/// `GET /attendance/monthly/:empId?year=&month=`. Each calendar
/// entry has shape:
///   { date, day, dayOfWeek, dayShift, nightShift, summary }
/// where `summary` is one of: present, late, half_day, absent,
/// on_leave, mixed, untracked.
class EmpAttendanceController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  final selectedYear  = DateTime.now().year.obs;
  final selectedMonth = DateTime.now().month.obs;

  final calendar    = <Map<String, dynamic>>[].obs;
  final stats       = Rxn<Map<String, dynamic>>();
  final daysInMonth = 0.obs;
  final isLoading   = true.obs;
  final errorMsg    = Rxn<String>();

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    fetchMonth();
  }

  Future<void> fetchMonth() async {
    if (_empId.isEmpty) {
      errorMsg.value = 'No employee record linked.';
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    errorMsg.value  = null;
    try {
      final res = await _dio.get(
        '/attendance/monthly/$_empId',
        queryParameters: {
          'year':  selectedYear.value,
          'month': selectedMonth.value,
        },
      );
      final body = SafeJson.asMap(res.data);
      stats.value       = SafeJson.asMapOrNull(body['stats']);
      daysInMonth.value = SafeJson.asInt(body['daysInMonth']);
      calendar.assignAll(SafeJson.asMapList(body['calendar']));
    } on DioException catch (e) {
      errorMsg.value = SafeJson.apiErrorMessage(e.response?.data) ??
          'Failed to load attendance';
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void changeMonth(int year, int month) {
    selectedYear.value  = year;
    selectedMonth.value = month;
    fetchMonth();
  }

  /// Lookup helper used by the calendar widget.
  Map<String, dynamic>? entryFor(DateTime day) {
    final key = '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    for (final e in calendar) {
      if (e['date'] == key) return e;
    }
    return null;
  }

  /// Attendance % (present + late + half_day*0.5) / total × 100.
  int get attendancePct {
    final s = stats.value;
    if (s == null) return 0;
    final total = SafeJson.asInt(s['total']);
    if (total == 0) return 0;
    final present = SafeJson.asDouble(s['present']);
    final late    = SafeJson.asDouble(s['late']);
    final halfDay = SafeJson.asDouble(s['halfDay']);
    return ((present + late + halfDay * 0.5) / total * 100).round();
  }
}
