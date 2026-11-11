import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../auth/controllers/emp_session.dart';

/// Backing controller for the rebuilt My Profile page.
///
/// Fans out four independent stat requests in parallel and tolerates
/// per-call failure — a single 500 from (e.g.) the bonus endpoint
/// must not black out the whole page. Each KPI is a `Rxn<num>`; the
/// view renders `—` whenever the value is null.
class EmpProfileController extends GetxController {
  Dio get _dio => ApiClient.instance.dio;

  // KPI tiles. Null → render as “—” (load failed or no data).
  final attendancePct      = Rxn<double>();
  final shiftsThisMonth    = Rxn<int>();
  final pendingLeaves      = Rxn<int>();
  final yearlyBonusTier    = Rxn<String>();

  // Last 5 closed shifts for the timeline.
  final recentShifts = <Map<String, dynamic>>[].obs;

  final isLoading = true.obs;
  final hasFatal  = false.obs;

  String get _empId => EmpSession.find.user.value.employeeId ?? '';

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    hasFatal.value  = false;
    final id = _empId;
    if (id.isEmpty) {
      // Without an employee link we still want the page to render —
      // identity + edit form are useful on their own. We just have
      // nothing to populate the stat grid with.
      isLoading.value = false;
      return;
    }

    // Parallel fan-out. `Future.wait(eagerError: false)` would still
    // throw on any failure; using individual try/catch wrappers keeps
    // each lane independent.
    await Future.wait([
      _loadAttendanceAndShifts(id),
      _loadPendingLeaves(id),
      _loadYearlyBonus(id),
      _loadRecentShifts(id),
    ]);

    isLoading.value = false;
  }

  // ── Attendance % + shift count (one call, two KPIs) ───────────
  Future<void> _loadAttendanceAndShifts(String id) async {
    try {
      final now   = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end   = DateTime(now.year, now.month + 1, 0);
      final fmt   = DateFormat('yyyy-MM-dd');
      final res = await _dio.get(
        '/attendance/employee/$id',
        queryParameters: {
          'startDate': fmt.format(start),
          'endDate':   fmt.format(end),
          'shift':     'all',
        },
      );
      final body = SafeJson.asMap(res.data);
      // The endpoint shape varies across deployments — try a couple of
      // known keys before giving up. We treat any present day-list as
      // the source of truth for the count, and look for a server-side
      // percentage in the same envelope.
      final list = SafeJson.asMapList(body['attendance'])
          .ifEmpty(SafeJson.asMapList(body['records']))
          .ifEmpty(SafeJson.asMapList(body['result']));
      shiftsThisMonth.value = list.length;
      final serverPct = SafeJson.asNum(body['attendancePercent'])
          ?? SafeJson.asNum(body['percent']);
      if (serverPct != null) {
        attendancePct.value = serverPct.toDouble();
      } else if (list.isNotEmpty) {
        // Fallback: present days / days elapsed so far this month.
        final present = list.where((d) =>
            SafeJson.asString(d['status']).toLowerCase() == 'present' ||
            SafeJson.asBool(d['present'])).length;
        final daysElapsed = now.day;
        attendancePct.value = daysElapsed == 0
            ? 0
            : (present * 100.0 / daysElapsed).clamp(0, 100).toDouble();
      }
    } catch (_) {
      // Leave both KPIs as null → view shows “—”.
    }
  }

  // ── Pending leave requests ─────────────────────────────
  Future<void> _loadPendingLeaves(String id) async {
    try {
      final now = DateTime.now();
      final res = await _dio.get(
        '/leave/employee/$id',
        queryParameters: {'year': now.year, 'month': now.month},
      );
      final body = SafeJson.asMap(res.data);
      final list = SafeJson.asMapList(body['leaves'])
          .ifEmpty(SafeJson.asMapList(body['result']))
          .ifEmpty(SafeJson.asMapList(res.data));
      pendingLeaves.value = list
          .where((l) =>
              SafeJson.asString(l['status']).toLowerCase() == 'pending')
          .length;
    } catch (_) {}
  }

  // ── Yearly bonus tier ────────────────────────────────
  Future<void> _loadYearlyBonus(String id) async {
    try {
      final res = await _dio.get(
        '/bonus/employee/$id',
        queryParameters: {'year': DateTime.now().year},
      );
      final body = SafeJson.asMap(res.data);
      // Tier may be a string label ("Gold") or a numeric percent;
      // accept either so we don't second-guess the backend.
      final tier = SafeJson.asStringOrNull(body['tier'])
          ?? SafeJson.asStringOrNull(body['bonusTier'])
          ?? SafeJson.asStringOrNull(SafeJson.asMap(body['bonus'])['tier']);
      if (tier != null) {
        yearlyBonusTier.value = tier;
      } else {
        final pct = SafeJson.asNum(body['bonusPercent'])
            ?? SafeJson.asNum(body['percent']);
        if (pct != null) yearlyBonusTier.value = '${pct.toStringAsFixed(0)}%';
      }
    } catch (_) {}
  }

  // ── Recent closed shifts (last 5) ───────────────────────
  Future<void> _loadRecentShifts(String id) async {
    try {
      final res = await _dio.get(
        '/shift/employee-closed-shifts',
        queryParameters: {'id': id},
      );
      final body = SafeJson.asMap(res.data);
      final list = SafeJson.asMapList(body['shifts'])
          .ifEmpty(SafeJson.asMapList(body['result']))
          .ifEmpty(SafeJson.asMapList(res.data));
      // Sort most-recent first if a date field is present.
      list.sort((a, b) {
        final da = SafeJson.asDateTime(a['date']) ??
            SafeJson.asDateTime(a['createdAt']) ?? DateTime(1970);
        final db = SafeJson.asDateTime(b['date']) ??
            SafeJson.asDateTime(b['createdAt']) ?? DateTime(1970);
        return db.compareTo(da);
      });
      recentShifts.assignAll(list.take(5).toList());
    } catch (_) {
      recentShifts.clear();
    }
  }
}

extension _IfEmpty<T> on List<T> {
  /// Tiny helper so the parallel fetch lanes can chain “try this key,
  /// fall back to that key” without three nested if-blocks each.
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}
