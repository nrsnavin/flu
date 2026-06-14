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
      ]);

      final next = <AISuggestion>[];
      _fromKpis(results[0], next);
      _fromPendingShifts(results[1], next);
      _fromMaintenance(results[2], next);
      _fromPoAging(results[3], next);

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
}
