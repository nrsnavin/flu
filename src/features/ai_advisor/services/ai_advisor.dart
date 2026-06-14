import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import 'advisor_prefs_store.dart';

/// Severity drives card colour + sort order. `high` floats to the
/// front, `low` sinks to the back.
enum AISuggestionPriority { high, med, low }

/// One row in the advisor diagnostic sheet. `count` is the raw
/// signal volume the endpoint reported (e.g. number of pending
/// shifts, number of low-stock materials) — when null it means the
/// endpoint didn't return anything we could parse. `reached: false`
/// means the catchError guard fired (network or auth failure).
class EndpointDiagnostic {
  final String label;
  final String path;
  final bool   reached;
  final int?   count;

  const EndpointDiagnostic({
    required this.label,
    required this.path,
    required this.reached,
    this.count,
  });
}

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

  /// Pre-filter snapshot kept so we can re-apply the category
  /// filter the moment the admin toggles a preference, without
  /// re-firing all 17 endpoints.
  List<AISuggestion> _lastUnfiltered = const [];

  /// Tracks the most recent successful end of `refreshNow`. `null`
  /// when the controller has never produced a response. Lets the
  /// strip widget distinguish "first paint, still loading" from
  /// "ran and got nothing".
  final lastFetchAt = Rxn<DateTime>();

  /// Number of endpoints that returned null in the last `refreshNow`
  /// pass (i.e. tripped the catchError fall-back). Lets the strip
  /// surface "Advisor offline" when most fetches failed, instead of
  /// silently masquerading as "all clear".
  final lastFailureCount = 0.obs;
  int _expectedFetchCount = 0;

  /// Per-endpoint diagnostic so the strip can show "why is it
  /// empty?" — every rule's last reach state plus the count it
  /// found. Populated at the end of every refresh round.
  final endpointDiagnostics = <EndpointDiagnostic>[].obs;

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
  final _order = ApiClient.buildClient(
    baseUrl: 'http://13.233.117.153:2701/api/v2/order',
  );

  /// `false` until we've issued the once-per-session payroll
  /// auto-generate POST. Prevents the advisor from refiring the
  /// trigger every 10 minutes when the periodic refresh kicks in.
  bool _autoPayrollTriedThisSession = false;

  /// How often the advisor re-fans its endpoints in the
  /// background. 10 minutes is long enough that the network cost
  /// is negligible and short enough that newly-breached thresholds
  /// (low stock, late PO, conflict) surface within one shift.
  static const _refreshInterval = Duration(minutes: 10);
  Timer? _refreshTimer;

  @override
  void onInit() {
    super.onInit();
    refreshNow();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      // Skip if a refresh (manual or scheduled) is already in flight;
      // back-pressure beats stacking parallel fan-outs.
      if (!loading.value) refreshNow();
    });
    // When the admin flips a category toggle, re-derive `suggestions`
    // from the cached unfiltered list — avoids hammering 17 endpoints
    // just because a preference changed.
    ever(AdvisorPrefsStore.instance.disabled, (_) => _applyCategoryFilter());
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.onClose();
  }

  /// Explicit try/catch wrapper. The previous code chained
  /// `.catchError((_) => null)` directly on `dio.get(...)`, but
  /// since Dart 2.12+ catchError on a non-nullable Future<Response>
  /// has an inferred return type of Response, not Response?. The
  /// `null` returned from the handler got coerced through unsafe
  /// cast paths and in some Dio configurations actually surfaced
  /// the original error instead of swallowing it — which then
  /// poisoned the whole `Future.wait`, leaving every result null.
  /// An explicit Future<Response?> async wrapper sidesteps that.
  Future<Response?> _safe(
    Dio client,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await client.get(path, queryParameters: query);
    } catch (e) {
      debugPrint('[AIAdvisor] $path failed: $e');
      return null;
    }
  }

  Future<void> refreshNow() async {
    loading.value = true;
    try {
      final results = await Future.wait<Response?>([
        _safe(_dash,        '/kpis'),
        _safe(_shift,       '/pending-verification'),
        _safe(_machine,     '/maintenance-due', query: {'days': 14}),
        _safe(_supplier,    '/po-receipt-aging'),
        _safe(_materials,   '/low-stock'),
        _safe(_leave,       '/conflicts'),
        _safe(_attendance,  '/recurring-latecomers'),
        _safe(_employee,    '/performance-delta'),
        _safe(_attendance,  '/repeatedly-unmarked'),
        _autoGeneratePayrollIfDue(),
        _safe(_job,         '/stale'),
        _safe(_shiftAdvisor,'/attendance-mismatch'),
        _safe(_shiftAdvisor,'/production-anomalies'),
        _safe(_materials,   '/projected-stockout'),
        _safe(_job,         '/wastage-outliers'),
        _safe(_order,       '/delivery-risk'),
        _safe(_payroll,     '/outstanding-advances'),
      ]);

      // One-line debug summary so the user can copy-paste from the
      // console if the strip still looks empty. Counts non-null
      // results and dumps a compact list of which slots reached.
      debugPrint(
        '[AIAdvisor] refresh complete — '
        '${results.where((r) => r != null).length}/${results.length} reached',
      );

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
      _fromProjectedStockout(results[13], next);
      _fromWastageOutliers(results[14], next);
      _fromDeliveryRisk(results[15], next);
      _fromOutstandingAdvances(results[16], next);

      // Stable sort by priority, then title.
      next.sort((a, b) {
        final p = a.priority.index.compareTo(b.priority.index);
        return p != 0 ? p : a.title.compareTo(b.title);
      });
      _lastUnfiltered = List.unmodifiable(next);
      _applyCategoryFilter();

      _expectedFetchCount = results.length;
      // results[9] is the payroll trigger, which legitimately returns
      // null after the once-per-session flag flips — don't count it
      // as a failed endpoint.
      lastFailureCount.value =
          results.where((r) => r == null).length -
              (results[9] == null ? 1 : 0);
      lastFetchAt.value = DateTime.now();

      // Snapshot per-endpoint reach status so the user can pop the
      // diagnostic sheet and answer "why is it empty?" themselves.
      endpointDiagnostics.assignAll([
        _diag('Dashboard KPIs',          '/dashboard/kpis',                results[0],  _countFromKpis),
        _diag('Pending shifts',          '/shift/pending-verification',    results[1],  (b) => _list(b, 'shifts').length),
        _diag('Maintenance due',         '/machine/maintenance-due',       results[2],  (b) => (b['overdueCount'] as num?)?.toInt() ?? _list(b, 'data').length),
        _diag('PO receipt aging',        '/supplier/po-receipt-aging',     results[3],  _countFromPoAging),
        _diag('Low-stock materials',     '/materials/low-stock',           results[4],  (b) => _list(b, 'materials').length),
        _diag('Leave-shift conflicts',   '/leave/conflicts',               results[5],  (b) => _list(b, 'conflicts').length),
        _diag('Recurring latecomers',    '/attendance/recurring-latecomers', results[6], (b) => _list(b, 'employees').length),
        _diag('Performance delta',       '/employee/performance-delta',    results[7],  (b) => _list(b, 'employees').length),
        _diag('Attendance gaps',         '/attendance/repeatedly-unmarked', results[8], (b) => _list(b, 'employees').length),
        _diag('Payroll auto-trigger',    '/payroll/auto-generate',         results[9],  (_) => null),
        _diag('Stale jobs',              '/job/stale',                     results[10], (b) => _list(b, 'jobs').length),
        _diag('Shift-attendance mismatch', '/shift/attendance-mismatch',   results[11], (b) => _list(b, 'mismatches').length),
        _diag('Production drop',         '/shift/production-anomalies',    results[12], (b) => _list(b, 'machines').length),
        _diag('Projected stockout',      '/materials/projected-stockout',  results[13], (b) => _list(b, 'materials').length),
        _diag('Wastage outliers',        '/job/wastage-outliers',          results[14], (b) => _list(b, 'machines').length),
        _diag('Order delivery risk',     '/order/delivery-risk',           results[15], (b) => _list(b, 'orders').length),
        _diag('Outstanding advances',    '/payroll/outstanding-advances',  results[16], (b) => _list(b, 'advances').length),
      ]);
    } finally {
      loading.value = false;
    }
  }

  // ── Diagnostic helpers ──────────────────────────────────────
  EndpointDiagnostic _diag(
    String label,
    String path,
    Response? res,
    int? Function(Map body) count,
  ) {
    if (res == null) {
      return EndpointDiagnostic(label: label, path: path, reached: false);
    }
    final body = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : <String, dynamic>{};
    return EndpointDiagnostic(
      label:   label,
      path:    path,
      reached: true,
      count:   count(body),
    );
  }

  List _list(Map body, String key) {
    final v = body[key];
    if (v is List) return v;
    return const [];
  }

  int? _countFromKpis(Map body) {
    final data = body['data'] is Map ? body['data'] as Map : null;
    if (data == null) return null;
    final low = data['lowStock'] is Map ? data['lowStock'] as Map : null;
    return (low?['count'] as num?)?.toInt() ?? 0;
  }

  int? _countFromPoAging(Map body) {
    final summary = (body['summary'] as Map?) ??
        (body['buckets'] as Map?) ??
        const {};
    int total = 0;
    for (final v in summary.values) {
      if (v is num) total += v.toInt();
    }
    return total;
  }

  /// True when most fetches in the last round failed — the strip
  /// surfaces an "offline" empty state instead of pretending all is
  /// well. Threshold: more than half of the expected endpoints
  /// returned null.
  bool get isOffline =>
      lastFetchAt.value != null &&
      _expectedFetchCount > 0 &&
      lastFailureCount.value * 2 > _expectedFetchCount;

  /// Total number of rules evaluated in the last `refreshNow` round
  /// (subtracting the side-effect payroll trigger). Used by the
  /// strip's empty-state to communicate "X signals checked".
  int get totalRules =>
      _expectedFetchCount > 0 ? _expectedFetchCount - 1 : 0;

  /// Number of rule endpoints that returned successfully — useful
  /// for the empty-state to surface "11/13 reachable" so a partial
  /// outage is visible even when it doesn't cross the offline gate.
  int get reachableRules =>
      _expectedFetchCount > 0
          ? totalRules - lastFailureCount.value
          : 0;

  /// Re-derives `suggestions` from `_lastUnfiltered` against the
  /// current AdvisorPrefsStore disabled set. Called both at the end
  /// of `refreshNow` and whenever the prefs change — lets the strip
  /// react to a toggle without re-firing endpoints.
  void _applyCategoryFilter() {
    final disabled = AdvisorPrefsStore.instance.disabled;
    final filtered = _lastUnfiltered.where((s) {
      final cat = _categoryFor(s.moduleId);
      if (cat == null) return true;
      return !disabled.contains(cat);
    }).toList(growable: false);
    suggestions.assignAll(filtered);
  }

  // ── Category routing (D5 user preferences) ──────────────────
  //
  // Maps a card's moduleId to a coarse category the admin can mute.
  // New rules pick this up for free as long as their moduleId is in
  // a registered bucket; an unrecognised moduleId stays visible.
  AdvisorCategory? _categoryFor(String moduleId) {
    switch (moduleId) {
      case 'elastic_stock':
      case 'low_stock_draft':
      case 'raw_materials':
        return AdvisorCategory.inventory;
      case 'pending_verification':
      case 'attendance':
      case 'employees':
      case 'payroll':
        return AdvisorCategory.people;
      case 'jobs':
      case 'analytics':
      case 'machine_issues':
      case 'wastage':
      case 'machines':
      case 'orders':
        return AdvisorCategory.production;
      case 'po_aging':
      case 'po_list':
        return AdvisorCategory.purchasing;
      default:
        return null;
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
    // Backend returns the bucket counts under `summary` (legacy code
    // here read `buckets` which never matched — POs over 30 days old
    // were silently invisible to the advisor).
    final summary = (body['summary'] as Map?) ??
        (body['buckets'] as Map?) ??
        const {};
    final critical = (summary['critical'] as num?)?.toInt() ?? 0;
    final late     = (summary['late']     as num?)?.toInt() ?? 0;
    final watch    = (summary['watch']    as num?)?.toInt() ?? 0;

    if (critical > 0) {
      out.add(AISuggestion(
        id: 'po_critical',
        title: '$critical PO${critical == 1 ? '' : 's'} critically overdue',
        subtitle: 'Open >60 days — escalate with suppliers',
        icon: Icons.priority_high_rounded,
        priority: AISuggestionPriority.high,
        moduleId: 'po_aging',
      ));
    } else if (late > 0) {
      out.add(AISuggestion(
        id: 'po_late',
        title: '$late PO${late == 1 ? '' : 's'} late on receipt',
        subtitle: 'Open 31–60 days — chase suppliers',
        icon: Icons.hourglass_bottom_rounded,
        priority: AISuggestionPriority.med,
        moduleId: 'po_aging',
      ));
    } else if (watch > 0) {
      // The "watch" bucket (8–30 days) used to be silent. Surfacing
      // it as a low-priority nudge keeps overdue receipts visible
      // before they age into the harder buckets.
      out.add(AISuggestion(
        id: 'po_watch',
        title: '$watch PO${watch == 1 ? '' : 's'} pending receipt >7 days',
        subtitle: 'Confirm expected delivery dates',
        icon: Icons.schedule_rounded,
        priority: AISuggestionPriority.low,
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

  // ── Projected stockout (predictive low-stock) ───────────────
  void _fromProjectedStockout(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['materials'] as List?) ?? const [];
    if (list.isEmpty) return;
    final horizon = (body['horizonDays'] as num?)?.toInt() ?? 7;
    // Soonest projected stockout drives the urgency copy.
    double soonest = double.infinity;
    for (final m in list) {
      if (m is Map) {
        final d = (m['daysToStockout'] as num?)?.toDouble();
        if (d != null && d < soonest) soonest = d;
      }
    }
    final soonestLabel = soonest.isFinite ? soonest.toStringAsFixed(0) : '?';
    out.add(AISuggestion(
      id: 'projected_stockout',
      title:
          '${list.length} material${list.length == 1 ? '' : 's'} projected to run out',
      subtitle: 'Soonest in ~${soonestLabel}d — draft now to stay ahead',
      icon: Icons.online_prediction_rounded,
      priority: soonest <= 3
          ? AISuggestionPriority.high
          : AISuggestionPriority.med,
      moduleId: 'low_stock_draft',
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

  // ── Wastage outliers (per-machine vs trailing baseline) ─────
  void _fromWastageOutliers(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['machines'] as List?) ?? const [];
    if (list.isEmpty) return;
    out.add(AISuggestion(
      id: 'wastage_outliers',
      title:
          '${list.length} machine${list.length == 1 ? '' : 's'} with high wastage',
      subtitle: 'Last 7 days >2σ above their own baseline',
      icon: Icons.report_problem_outlined,
      priority: AISuggestionPriority.med,
      moduleId: 'wastage',
    ));
  }

  // ── Order delivery risk (due in N days, still pending) ──────
  void _fromDeliveryRisk(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final list = (body['orders'] as List?) ?? const [];
    if (list.isEmpty) return;
    final horizon = (body['horizonDays'] as num?)?.toInt() ?? 7;
    // Soonest due date drives the urgency copy.
    int soonest = 1 << 30;
    for (final o in list) {
      if (o is Map) {
        final d = (o['daysToSupply'] as num?)?.toInt();
        if (d != null && d < soonest) soonest = d;
      }
    }
    final soonestLabel = soonest < (1 << 30) ? soonest.toString() : '?';
    out.add(AISuggestion(
      id: 'order_delivery_risk',
      title:
          '${list.length} order${list.length == 1 ? '' : 's'} at delivery risk',
      subtitle:
          'Soonest in ${soonestLabel}d (horizon $horizon) with pending production',
      icon: Icons.local_shipping_outlined,
      priority: soonest <= 2
          ? AISuggestionPriority.high
          : AISuggestionPriority.med,
      moduleId: 'orders',
    ));
  }

  // ── Outstanding advances past recovery month ────────────────
  void _fromOutstandingAdvances(Response? res, List<AISuggestion> out) {
    if (res == null) return;
    final body = res.data is Map ? res.data : const {};
    final count = (body['count'] as num?)?.toInt() ??
        ((body['advances'] as List?)?.length ?? 0);
    if (count <= 0) return;
    final total = (body['totalAmount'] as num?)?.toInt() ?? 0;
    out.add(AISuggestion(
      id: 'outstanding_advances',
      title:
          '$count advance${count == 1 ? '' : 's'} past recovery month',
      subtitle: total > 0
          ? '₹$total still to deduct — review payroll runs'
          : 'Review payroll runs for missed deductions',
      icon: Icons.account_balance_wallet_outlined,
      priority: AISuggestionPriority.high,
      moduleId: 'payroll',
    ));
  }
}
