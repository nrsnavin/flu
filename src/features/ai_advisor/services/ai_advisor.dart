import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';

/// Severity drives card colour + sort order. `high` floats to the
/// front, `low` sinks to the back.
enum AISuggestionPriority { high, med, low }

/// One actionable nudge shown in the dashboard strip.
///
/// `moduleId` is a NavRegistry id — tapping the card routes through
/// `NavRegistry.instance.open(moduleId)` so recents/pinned stay in
/// sync with anything else in the app.
class AISuggestion {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final AISuggestionPriority priority;
  final String moduleId;

  const AISuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.priority,
    required this.moduleId,
  });
}

/// Heuristic suggestion engine. No LLM — derives "what should the
/// admin do right now?" directly from existing ERP endpoints:
///
///   - /dashboard/kpis    → low stock, pending leaves, open jobs,
///                          attendance unmarked
///   - /shift/pending-verification → shifts awaiting approval
///   - /machine/maintenance-due    → overdue services
///   - /supplier/po-receipt-aging  → POs past expected receipt
///
/// All fetches happen in parallel; any single endpoint failing only
/// drops its own suggestions, the rest still render.
class AIAdvisor extends GetxController {
  static AIAdvisor get instance => Get.isRegistered<AIAdvisor>()
      ? Get.find<AIAdvisor>()
      : Get.put(AIAdvisor(), permanent: true);

  final suggestions = <AISuggestion>[].obs;
  final loading     = false.obs;

  final _dash = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/dashboard',
  );
  final _shift = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/shift',
  );
  final _machine = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/machine',
  );
  final _supplier = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/supplier',
  );
  final _materials = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/materials',
  );
  final _leave = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/leave',
  );
  final _attendance = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/attendance',
  );
  final _employee = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/employee',
  );
  final _payroll = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/payroll',
  );
  final _job = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/job',
  );
  final _shiftAdvisor = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/shift',
  );

  /// `false` until we've issued the once-per-session payroll
  /// auto-generate POST. Prevents the advisor from refiring the
  /// trigger every 10 minutes when the periodic refresh kicks in.
  bool _autoPayrollTriedThisSession = false;

  @override
  void onInit() {
    super.onInit();
    refreshNow();
  }

  Future<void> refreshNow() async {
    loading.value = true;
    try {
      final results = await Future.wait([
        _dash.get('/kpis').catchError((_) => null),
        _shift.get('/pending-verification').catchError((_) => null),
        _machine.get('/maintenance-due', queryParameters: {'days': 14})
            .catchError((_) => null),
        _supplier.get('/po-receipt-aging').catchError((_) => null),
        _materials.get('/low-stock').catchError((_) => null),
        _leave.get('/conflicts').catchError((_) => null),
        _attendance.get('/recurring-latecomers').catchError((_) => null),
        _employee.get('/performance-delta').catchError((_) => null),
        _attendance.get('/repeatedly-unmarked').catchError((_) => null),
        _autoGeneratePayrollIfDue(),
        _job.get('/stale').catchError((_) => null),
        _shiftAdvisor.get('/attendance-mismatch').catchError((_) => null),
        _shiftAdvisor.get('/production-anomalies').catchError((_) => null),
      ]);

      final next = <AISuggestion>[];
      _fromKpis(results[0], next);
      _fromPendingShifts(results[1], next);
      _fromMaintenance(results[2], next);
      _fromPoAging(results[3], next);
      _fromLowStockMaterials(results[4], next);
      _fromLeaveConflicts(results[5], next);
      _fromLatecomers(results[6], next);
      _fromPerfDelta(results[7], next);
      _fromUnmarkedPattern(results[8], next);
      _fromAutoPayroll(results[9], next);
      _fromStaleJobs(results[10], next);
      _fromShiftAttendanceMismatch(results[11], next);
      _fromProductionAnomalies(results[12], next);

      // Stable sort by priority, then title.
      next.sort((a, b) {
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : a.title.compareTo(b.title);
      });
      suggestions.assignAll(next);
    } finally {
      loading.value = false;
    }
  }

  // ── KPIs ────────────────────────────────────────────────────
  void _fromKpis(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final data = (res.data is Map ? res.data['data'] : null) as Map? ?? {};

    final lowStock = (data['lowStock'] as Map?) ?? const {};
    final lowCount = (lowStock['count'] as num?)?.toInt() ?? 0;
    if (lowCount > 0) {
      out.add(AISuggestion(
        id: 'low_stock',
        title: '$lowCount item${lowCount == 1 ? '' : 's'} below min stock',
        subtitle: lowCount >= 5
            ? 'Critical — raise POs or rebalance now'
            : 'Plan a PO before production hits the floor',
        icon: Icons.warning_amber_rounded,
        priority: lowCount >= 5
            ? AISuggestionPriority.high
            : AISuggestionPriority.med,
        moduleId: 'elastic_stock',
      ));
    }

    final pendingLeaves =
        (data['pendingLeaves'] as num?)?.toInt() ?? 0;
    if (pendingLeaves > 0) {
      out.add(AISuggestion(
        id: 'pending_leaves',
        title: '$pendingLeaves leave request${pendingLeaves == 1 ? '' : 's'} pending',
        subtitle: 'Approve or reject so payroll stays accurate',
        icon: Icons.event_busy_outlined,
        priority: AISuggestionPriority.med,
        moduleId: 'attendance',
      ));
    }

    final attendance =
        (data['attendanceToday'] as Map?) ?? const {};
    final unmarked = (attendance['unmarked'] as num?)?.toInt() ?? 0;
    if (unmarked > 0) {
      out.add(AISuggestion(
        id: 'unmarked_attendance',
        title: '$unmarked employee${unmarked == 1 ? '' : 's'} without attendance today',
        subtitle: 'Mark before payroll cut-off',
        icon: Icons.how_to_reg_outlined,
        priority: AISuggestionPriority.low,
        moduleId: 'attendance',
      ));
    }

    final openJobs = (data['openJobs'] as num?)?.toInt() ?? 0;
    if (openJobs >= 20) {
      out.add(AISuggestion(
        id: 'job_backlog',
        title: '$openJobs open jobs — review priorities',
        subtitle: 'Consider closing or reassigning stale jobs',
        icon: Icons.assignment_outlined,
        priority: AISuggestionPriority.low,
        moduleId: 'jobs',
      ));
    }
  }

  // ── Pending shift verifications ─────────────────────────────
  void _fromPendingShifts(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data;
    final list = (body is Map
            ? (body['shifts'] as List?) ?? (body['data'] as List?)
            : null) ??
        const [];
    if (list.isEmpty) return;
    out.add(AISuggestion(
      id: 'pending_shifts',
      title: '${list.length} shift${list.length == 1 ? '' : 's'} await verification',
      subtitle: 'Approve so production figures finalize',
      icon: Icons.fact_check_outlined,
      priority: AISuggestionPriority.high,
      moduleId: 'pending_verification',
    ));
  }

  // ── Maintenance due ─────────────────────────────────────────
  void _fromMaintenance(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final overdue = (body['overdueCount'] as num?)?.toInt() ?? 0;
    final items = (body['data'] as List?) ?? const [];
    final dueCount = items.length;
    if (overdue > 0) {
      out.add(AISuggestion(
        id: 'maintenance_overdue',
        title: '$overdue machine${overdue == 1 ? '' : 's'} overdue maintenance',
        subtitle: 'Schedule service to prevent downtime',
        icon: Icons.engineering_outlined,
        priority: AISuggestionPriority.high,
        moduleId: 'maintenance_due',
      ));
    } else if (dueCount > 0) {
      out.add(AISuggestion(
        id: 'maintenance_due',
        title: '$dueCount machine${dueCount == 1 ? '' : 's'} due for service soon',
        subtitle: 'Plan maintenance within 14 days',
        icon: Icons.build_outlined,
        priority: AISuggestionPriority.low,
        moduleId: 'maintenance_due',
      ));
    }
  }

  // ── PO receipt aging ────────────────────────────────────────
  void _fromPoAging(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final buckets = (body['buckets'] as Map?) ?? const {};
    final critical = (buckets['critical'] as num?)?.toInt() ?? 0;
    final late = (buckets['late'] as num?)?.toInt() ?? 0;
    if (critical > 0) {
      out.add(AISuggestion(
        id: 'po_critical',
        title: '$critical PO${critical == 1 ? '' : 's'} critically overdue',
        subtitle: 'Escalate with suppliers today',
        icon: Icons.priority_high_rounded,
        priority: AISuggestionPriority.high,
        moduleId: 'po_aging',
      ));
    } else if (late > 0) {
      out.add(AISuggestion(
        id: 'po_late',
        title: '$late PO${late == 1 ? '' : 's'} late on receipt',
        subtitle: 'Chase suppliers for status',
        icon: Icons.hourglass_bottom_rounded,
        priority: AISuggestionPriority.med,
        moduleId: 'po_aging',
      ));
    }
  }

  // ── Low-stock raw materials → auto-draft PO ─────────────────
  void _fromLowStockMaterials(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['materials'] as List?) ?? const [];
    if (list.isEmpty) return;
    final supplierIds = <String>{};
    for (final m in list) {
      if (m is Map) {
        final sup = m['supplier'];
        if (sup is Map && sup['_id'] != null) {
          supplierIds.add(sup['_id'].toString());
        }
      }
    }
    final supplierCount = supplierIds.length;
    out.add(AISuggestion(
      id: 'low_stock_materials',
      title:
          '${list.length} material${list.length == 1 ? '' : 's'} below min stock',
      subtitle: supplierCount > 1
          ? 'Tap to draft POs to $supplierCount suppliers'
          : 'Tap to draft a PO',
      icon: Icons.edit_note_rounded,
      priority: list.length >= 5
          ? AISuggestionPriority.high
          : AISuggestionPriority.med,
      moduleId: 'low_stock_draft',
    ));
  }

  // ── Leave ↔ shift schedule conflicts ────────────────────────
  void _fromLeaveConflicts(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['conflicts'] as List?)?.length ?? 0);
    if (count <= 0) return;
    out.add(AISuggestion(
      id: 'leave_shift_conflicts',
      title: '$count schedule conflict${count == 1 ? '' : 's'}',
      subtitle: 'Approved leave overlaps a confirmed shift',
      icon: Icons.event_busy_outlined,
      priority: AISuggestionPriority.high,
      moduleId: 'pending_verification',
    ));
  }

  // ── Recurring latecomers ────────────────────────────────────
  void _fromLatecomers(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['employees'] as List?)?.length ?? 0);
    if (count <= 0) return;
    final days = (body['windowDays'] as num?)?.toInt() ?? 30;
    final threshold = (body['threshold'] as num?)?.toInt() ?? 3;
    out.add(AISuggestion(
      id: 'recurring_latecomers',
      title: '$count operator${count == 1 ? '' : 's'} frequently late',
      subtitle: '>$threshold late marks in $days days',
      icon: Icons.schedule_outlined,
      priority: AISuggestionPriority.med,
      moduleId: 'employees',
    ));
  }

  // ── Performance-delta (efficiency drop MoM) ─────────────────
  void _fromPerfDelta(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['employees'] as List?) ?? const [];
    if (list.isEmpty) return;
    out.add(AISuggestion(
      id: 'performance_delta',
      title:
          '${list.length} operator${list.length == 1 ? '' : 's'} dropping in efficiency',
      subtitle: 'Down >15% vs last month — review training',
      icon: Icons.trending_down_rounded,
      priority: AISuggestionPriority.med,
      moduleId: 'employees',
    ));
  }

  // ── Repeatedly-unmarked attendance pattern ──────────────────
  void _fromUnmarkedPattern(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['employees'] as List?)?.length ?? 0);
    if (count <= 0) return;
    final days = (body['windowDays'] as num?)?.toInt() ?? 7;
    final threshold = (body['threshold'] as num?)?.toInt() ?? 2;
    out.add(AISuggestion(
      id: 'unmarked_pattern',
      title: '$count operator${count == 1 ? '' : 's'} with attendance gaps',
      subtitle: '>$threshold unmarked working days in $days',
      icon: Icons.event_note_outlined,
      priority: AISuggestionPriority.med,
      moduleId: 'attendance',
    ));
  }

  // ── Payroll auto-trigger (1st-of-month idempotent kick) ─────
  //
  // The advisor itself doesn't run payroll; it asks the backend to
  // run it if the conditions are met. The backend's /auto-generate
  // is idempotent (ALREADY_GENERATED short-circuits), so calling
  // this every 10 minutes is technically safe, but we still gate
  // it to once per session to keep the dashboard cheap.
  Future<Response?> _autoGeneratePayrollIfDue() async {
    if (_autoPayrollTriedThisSession) return null;
    final day = DateTime.now().day;
    if (day > 5) return null;            // miss-window safety
    _autoPayrollTriedThisSession = true;
    try {
      return await _payroll.post('/auto-generate');
    } catch (_) {
      return null;
    }
  }

  void _fromAutoPayroll(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final triggered = body['triggered'] == true;
    final period    = body['period']?.toString() ?? '';

    if (triggered) {
      final result    = (body['result'] as Map?) ?? const {};
      final generated = (result['generated'] as num?)?.toInt() ?? 0;
      if (generated <= 0) return;
      out.add(AISuggestion(
        id: 'payroll_auto_generated',
        title: 'Payroll auto-generated for $period',
        subtitle: '$generated operator${generated == 1 ? '' : 's'} processed',
        icon: Icons.task_alt_rounded,
        priority: AISuggestionPriority.low,
        moduleId: 'payroll',
      ));
      return;
    }

    final reason = body['reason']?.toString();
    if (reason == 'ATTENDANCE_INCOMPLETE') {
      final pct = (body['completenessPct'] as num?)?.toInt() ?? 0;
      out.add(AISuggestion(
        id: 'payroll_blocked_attendance',
        title: 'Payroll pending — attendance $pct% complete',
        subtitle: 'Mark remaining days to unblock $period payroll',
        icon: Icons.warning_amber_rounded,
        priority: AISuggestionPriority.high,
        moduleId: 'attendance',
      ));
    }
    // ALREADY_GENERATED / NO_ACTIVE_EMPLOYEES → no card. Silence is correct.
  }

  // ── Stale jobs (idle > N days in same status) ───────────────
  void _fromStaleJobs(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['jobs'] as List?)?.length ?? 0);
    if (count <= 0) return;
    final days = (body['windowDays'] as num?)?.toInt() ?? 14;
    out.add(AISuggestion(
      id: 'stale_jobs',
      title: '$count job${count == 1 ? '' : 's'} idle >$days days',
      subtitle: 'Stuck in same stage — review or close',
      icon: Icons.history_toggle_off_rounded,
      priority: AISuggestionPriority.low,
      moduleId: 'jobs',
    ));
  }

  // ── Shift ↔ attendance mismatch ─────────────────────────────
  void _fromShiftAttendanceMismatch(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['mismatches'] as List?)?.length ?? 0);
    if (count <= 0) return;
    final days = (body['windowDays'] as num?)?.toInt() ?? 7;
    out.add(AISuggestion(
      id: 'shift_attendance_mismatch',
      title:
          '$count shift${count == 1 ? '' : 's'} without attendance',
      subtitle: 'Closed shifts in last $days days lacking a mark',
      icon: Icons.rule_folder_outlined,
      priority: AISuggestionPriority.med,
      moduleId: 'attendance',
    ));
  }

  // ── Production drop anomaly (per machine vs 30-day avg) ─────
  void _fromProductionAnomalies(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['machines'] as List?) ?? const [];
    if (list.isEmpty) return;
    out.add(AISuggestion(
      id: 'production_anomaly',
      title:
          '${list.length} machine${list.length == 1 ? '' : 's'} producing below trend',
      subtitle: 'Today is >30% under the 30-day average',
      icon: Icons.trending_down_rounded,
      priority: AISuggestionPriority.high,
      moduleId: 'analytics',
    ));
  }
}
