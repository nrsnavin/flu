// ══════════════════════════════════════════════════════════════
//  PRODUCTION ANALYTICS PAGE  v2 — GAMIFIED
//  File: lib/src/features/production/screens/analytics_page.dart
// ══════════════════════════════════════════════════════════════

//
//  Tabs: Overview · Machines · Employees · ⚡ Arena · Alerts
//
//  New features:
//    ■ Arena tab: XP leaderboard, player cards, level badges
//    ■ Achievement showcase per employee
//    ■ Consistency score rings
//    ■ Efficiency-per-head metric for machines
//    ■ Weekly heatmap (Sun-Sat)
//    ■ Day vs Night production donut
//    ■ Improvement arrows with % change
//    ■ Streak fire badges
//    ■ Utilisation progress bars for machines
//    ■ XP breakdown drill-down card
//    ■ Percentile rank indicator

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/analytics_controller.dart';
import '../models/analytics_model.dart';


// ── Colour tokens ──────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF080F1A);
  static const surface   = Color(0xFF0E1829);
  static const surface2  = Color(0xFF162035);
  static const surface3  = Color(0xFF1C2A42);
  static const border    = Color(0xFF1C3050);
  static const borderBrt = Color(0xFF264070);

  static const blue      = Color(0xFF2563EB);
  static const blueLt    = Color(0xFF3B82F6);
  static const cyan      = Color(0xFF06B6D4);
  static const cyanLt    = Color(0xFF22D3EE);
  static const green     = Color(0xFF10B981);
  static const greenLt   = Color(0xFF34D399);
  static const amber     = Color(0xFFF59E0B);
  static const orange    = Color(0xFFF97316);
  static const red       = Color(0xFFEF4444);
  static const redLt     = Color(0xFFFCA5A5);
  static const purple    = Color(0xFF8B5CF6);
  static const purpleLt  = Color(0xFFA78BFA);
  static const pink      = Color(0xFFEC4899);
  static const gold      = Color(0xFFFFD700);
  static const silver    = Color(0xFFC0C0C0);
  static const bronze    = Color(0xFFCD7F32);

  static const textPrim  = Color(0xFFF1F5F9);
  static const textSec   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  static const xpColor   = Color(0xFF818CF8);  // indigo for XP
  static const xpGlow    = Color(0xFF6366F1);
}

// ── Typography shortcuts ───────────────────────────────────────
const _t10  = TextStyle(fontSize:10, color:_C.textSec,  letterSpacing:0.4);
const _t10b = TextStyle(fontSize:10, color:_C.textPrim, fontWeight:FontWeight.w700, letterSpacing:0.4);
const _t11  = TextStyle(fontSize:11, color:_C.textSec);
const _t11b = TextStyle(fontSize:11, color:_C.textPrim, fontWeight:FontWeight.w700);
const _t12  = TextStyle(fontSize:12, color:_C.textSec);
const _t12b = TextStyle(fontSize:12, color:_C.textPrim, fontWeight:FontWeight.w700);
const _t13b = TextStyle(fontSize:13, color:_C.textPrim, fontWeight:FontWeight.w800);
const _t14b = TextStyle(fontSize:14, color:_C.textPrim, fontWeight:FontWeight.w800);
const _t16b = TextStyle(fontSize:16, color:_C.textPrim, fontWeight:FontWeight.w900);
const _t20b = TextStyle(fontSize:20, color:_C.textPrim, fontWeight:FontWeight.w900, letterSpacing:-0.5);
const _t24b = TextStyle(fontSize:24, color:_C.textPrim, fontWeight:FontWeight.w900, letterSpacing:-0.8);

// ── Number formatter ───────────────────────────────────────────
String _fmt(num n) {
  if (n >= 1000) return '${(n/1000).toStringAsFixed(1)}k';
  return n.toInt().toString();
}

// ── Month name list ────────────────────────────────────────────
const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

//  PAGE ENTRY POINT
class ProductionAnalyticsPage extends StatelessWidget {
  const ProductionAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.delete<AnalyticsController>(force: true);
    final c = Get.put(AnalyticsController());

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _AppBar(c: c),
        _DateFilterBar(c: c),
        _ShiftTabBar(c: c),
        _ActiveFiltersStrip(c: c),
        Expanded(child: Obx(() {
          if (c.isLoading.value) return const _LoadingView();
          if (c.errorMsg.value != null) return _ErrorView(c: c);
          if (c.data.value == null)     return const _EmptyView();
          return _TabBody(c: c);
        })),
      ]),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final AnalyticsController c;
  const _AppBar({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top+10, 16, 10),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: Get.back,
          child: Container(
            width:34, height:34,
            decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(8),
                border:Border.all(color:_C.border)),
            child: const Icon(Icons.arrow_back_ios_new, size:14, color:_C.textSec),
          ),
        ),
        const SizedBox(width:12),
        Expanded(
          child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width:6, height:6, margin:const EdgeInsets.only(right:6),
                  decoration: BoxDecoration(color:_C.green, shape:BoxShape.circle,
                      boxShadow:[BoxShadow(color:_C.green.withOpacity(0.6), blurRadius:8)])),
              const Text('Production Analytics',
                  style: TextStyle(color:_C.textPrim, fontSize:15, fontWeight:FontWeight.w800)),
            ]),
            const Text('Machines · Arena · Insights · Anomalies',
                style: TextStyle(color:_C.textMuted, fontSize:10)),
          ]),
        ),
        Obx(() {
          final cnt = c.highAnomalyCount;
          return Stack(clipBehavior:Clip.none, children: [
            GestureDetector(
              onTap: () => c.activeTab.value = AnalyticsTab.anomalies,
              child: Container(
                width:34, height:34,
                decoration: BoxDecoration(
                  color: cnt>0 ? _C.red.withOpacity(0.15) : _C.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cnt>0 ? _C.red.withOpacity(0.4) : _C.border),
                ),
                child: Icon(Icons.warning_amber_rounded, size:16,
                    color: cnt>0 ? _C.red : _C.textMuted),
              ),
            ),
            if (cnt > 0)
              Positioned(right:-4, top:-4,
                  child: Container(width:16, height:16, alignment:Alignment.center,
                      decoration: BoxDecoration(color:_C.red, shape:BoxShape.circle,
                          boxShadow:[BoxShadow(color:_C.red.withOpacity(0.5), blurRadius:4)]),
                      child: Text('$cnt',
                          style:const TextStyle(color:Colors.white, fontSize:9, fontWeight:FontWeight.w900)))),
          ]);
        }),
        const SizedBox(width:8),
        GestureDetector(
          onTap: c.fetch,
          child: Container(width:34, height:34,
              decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(8),
                  border:Border.all(color:_C.border)),
              child: const Icon(Icons.refresh_rounded, size:16, color:_C.textSec)),
        ),
      ]),
    );
  }
}

// ── Date + preset bar ─────────────────────────────────────────
class _DateFilterBar extends StatelessWidget {
  final AnalyticsController c;
  const _DateFilterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(14,8,14,10),
      child: Column(children: [
        Obx(() => Row(children: [
          _datePill(context, 'From', c.startDate.value, (d) =>
              c.setDateRange(d, c.endDate.value.isBefore(d) ? d : c.endDate.value)),
          Padding(padding:const EdgeInsets.symmetric(horizontal:8),
              child: Container(width:18, height:1, color:_C.borderBrt)),
          _datePill(context, 'To', c.endDate.value, (d) =>
              c.setDateRange(c.startDate.value.isAfter(d) ? d : c.startDate.value, d)),
        ])),
        const SizedBox(height:8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _presetChip(context, c, 'Today',   'today'),
            _presetChip(context, c, '7 Days',  'week'),
            _presetChip(context, c, '30 Days', 'month'),
            _presetChip(context, c, 'Quarter', 'quarter'),
          ]),
        ),
      ]),
    );
  }

  Widget _datePill(BuildContext ctx, String label, DateTime dt, void Function(DateTime) cb) {
    final s = '${dt.day.toString().padLeft(2,'0')} ${_months[dt.month-1]} ${dt.year}';
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx, initialDate: dt,
          firstDate: DateTime(2023), lastDate: DateTime.now(),
          builder: (c2, child) => Theme(
              data: Theme.of(c2).copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary:_C.blue, surface:_C.surface2, onSurface:_C.textPrim)),
              child: child!),
        );
        if (d != null) cb(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:10, vertical:6),
        decoration: BoxDecoration(color:_C.surface3, borderRadius:BorderRadius.circular(8),
            border:Border.all(color:_C.border)),
        child: Row(mainAxisSize:MainAxisSize.min, children: [
          Text('$label  ', style: _t10),
          const Icon(Icons.calendar_month_rounded, size:11, color:_C.textMuted),
          const SizedBox(width:4),
          Text(s, style: _t11b),
        ]),
      ),
    );
  }

  Widget _presetChip(BuildContext ctx, AnalyticsController c, String label, String key) {
    return Obx(() {
      // Determine if this preset is currently active
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool active = false;
      if (key=='today')   active = c.startDate.value == today && c.endDate.value == today;
      if (key=='week')    active = c.startDate.value == today.subtract(const Duration(days:6)) && c.endDate.value == today;
      if (key=='month')   active = c.startDate.value == today.subtract(const Duration(days:29)) && c.endDate.value == today;
      if (key=='quarter') active = c.startDate.value == today.subtract(const Duration(days:89)) && c.endDate.value == today;

      return GestureDetector(
        onTap: () => c.applyPreset(key),
        child: Container(
          margin: const EdgeInsets.only(right:6),
          padding: const EdgeInsets.symmetric(horizontal:10, vertical:5),
          decoration: BoxDecoration(
            color: active ? _C.blue.withOpacity(0.2) : _C.surface3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? _C.blue.withOpacity(0.6) : _C.border),
          ),
          child: Text(label, style: TextStyle(
              fontSize:11, fontWeight:FontWeight.w600,
              color: active ? _C.blueLt : _C.textSec)),
        ),
      );
    });
  }
}

// ── Shift tab bar ─────────────────────────────────────────────
class _ShiftTabBar extends StatelessWidget {
  final AnalyticsController c;
  const _ShiftTabBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(14,0,14,10),
      child: Obx(() => Row(children: [
        _tab(c, 'All', 'all',     Icons.all_inclusive_rounded),
        const SizedBox(width:6),
        _tab(c, 'Day', 'DAY',    Icons.wb_sunny_rounded),
        const SizedBox(width:6),
        _tab(c, 'Night', 'NIGHT', Icons.nights_stay_rounded),
      ])),
    );
  }

  Widget _tab(AnalyticsController c, String label, String val, IconData icon) {
    final active = c.shiftFilter.value == val;
    return GestureDetector(
      onTap: () => c.setShift(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
        decoration: BoxDecoration(
          color: active ? _C.blue.withOpacity(0.2) : _C.surface3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? _C.blue.withOpacity(0.6) : _C.border),
        ),
        child: Row(mainAxisSize:MainAxisSize.min, children: [
          Icon(icon, size:12, color: active ? _C.blueLt : _C.textMuted),
          const SizedBox(width:5),
          Text(label, style: TextStyle(
              fontSize:11, fontWeight:FontWeight.w600,
              color: active ? _C.blueLt : _C.textSec)),
        ]),
      ),
    );
  }
}

// ── Active filter strip ────────────────────────────────────────
class _ActiveFiltersStrip extends StatelessWidget {
  final AnalyticsController c;
  const _ActiveFiltersStrip({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!c.hasActiveFilters) return const SizedBox.shrink();
      final data = c.data.value;
      final mach = data?.byMachine.where((m)=>m.machineId==c.filterMachineId.value).firstOrNull;
      final emp  = data?.byEmployee.where((e)=>e.employeeId==c.filterEmployeeId.value).firstOrNull;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal:14, vertical:7),
        color: _C.amber.withOpacity(0.08),
        child: Row(children: [
          const Icon(Icons.filter_alt_rounded, size:12, color:_C.amber),
          const SizedBox(width:6),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              if (c.shiftFilter.value != 'all')
                _filterTag('Shift: ${c.shiftFilter.value}', () => c.setShift('all')),
              if (mach != null)
                _filterTag('Machine: ${mach.machineNo}', c.clearMachineFilter),
              if (emp != null)
                _filterTag('Employee: ${emp.name}', c.clearEmployeeFilter),
            ]),
          )),
          GestureDetector(
            onTap: c.clearAllFilters,
            child: const Text('Clear all',
                style: TextStyle(color:_C.amber, fontSize:11, fontWeight:FontWeight.w600)),
          ),
        ]),
      );
    });
  }

  Widget _filterTag(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right:6),
      padding: const EdgeInsets.fromLTRB(8,3,4,3),
      decoration: BoxDecoration(
        color: _C.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color:_C.amber.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize:MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color:_C.amber, fontSize:10, fontWeight:FontWeight.w600)),
        const SizedBox(width:4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size:11, color:_C.amber),
        ),
      ]),
    );
  }
}

// ── Tab navigation row ─────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final AnalyticsController c;
  const _NavRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(children: [
          _navTab(c, '📊 Overview',  AnalyticsTab.overview),
          _navTab(c, '⚙️ Machines',  AnalyticsTab.byMachine),
          _navTab(c, '👷 Employees', AnalyticsTab.byEmployee),
          _navTab(c, '⚡ Arena',     AnalyticsTab.arena),
          _navTabWithBadge(c, '🚨 Alerts', AnalyticsTab.anomalies),
        ])),
      ),
    );
  }

  Widget _navTab(AnalyticsController c, String label, AnalyticsTab tab) {
    final active = c.activeTab.value == tab;
    return GestureDetector(
      onTap: () => c.activeTab.value = tab,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:14, vertical:12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
              color: active ? _C.blue : Colors.transparent, width:2)),
        ),
        child: Text(label, style: TextStyle(
            fontSize:12, fontWeight:FontWeight.w700,
            color: active ? _C.blueLt : _C.textMuted)),
      ),
    );
  }

  Widget _navTabWithBadge(AnalyticsController c, String label, AnalyticsTab tab) {
    return Obx(() {
      final cnt    = c.highAnomalyCount;
      final active = c.activeTab.value == tab;
      return GestureDetector(
        onTap: () => c.activeTab.value = tab,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal:14, vertical:12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
                color: active ? _C.red : Colors.transparent, width:2)),
          ),
          child: Stack(clipBehavior:Clip.none, children: [
            Text(label, style: TextStyle(
                fontSize:12, fontWeight:FontWeight.w700,
                color: active ? _C.red : _C.textMuted)),
            if (cnt > 0)
              Positioned(right:-8, top:-4,
                  child: Container(width:14, height:14, alignment:Alignment.center,
                      decoration: BoxDecoration(color:_C.red, shape:BoxShape.circle),
                      child: Text('$cnt',
                          style:const TextStyle(color:Colors.white, fontSize:8, fontWeight:FontWeight.w900)))),
          ]),
        ),
      );
    });
  }
}

// ── Tab body ───────────────────────────────────────────────────
class _TabBody extends StatelessWidget {
  final AnalyticsController c;
  const _TabBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _NavRow(c: c),
      Expanded(child: Obx(() => IndexedStack(
        index: c.activeTab.value.index,
        children: [
          _OverviewTab(c: c),
          _MachinesTab(c: c),
          _EmployeesTab(c: c),
          _ArenaTab(c: c),
          _AnomaliesTab(c: c),
        ],
      ))),
    ]);
  }
}


// ══════════════════════════════════════════════════════════════

// ── Overview tab ──────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final AnalyticsController c;
  const _OverviewTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final d = c.data.value!;
    return ListView(padding:const EdgeInsets.all(14), children: [
      // KPI row 1
      Row(children: [
        Expanded(child: _KpiCard(
          icon: Icons.straighten_rounded, iconColor: _C.cyan,
          value: _fmt(d.summary.totalProduction),
          unit: 'm', label: 'Total Production',
          sub: '${d.summary.activeShifts} shifts',
          gradient: [const Color(0xFF0F2030), const Color(0xFF0C2035)],
        )),
        const SizedBox(width:8),
        Expanded(child: _KpiCard(
          icon: Icons.speed_rounded, iconColor: _C.green,
          value: _fmt(d.summary.avgPerShift),
          unit: 'm', label: 'Avg Per Shift',
          sub: 'fleet avg',
          gradient: [const Color(0xFF0A2018), const Color(0xFF0C2518)],
        )),
      ]),
      const SizedBox(height:8),
      // KPI row 2
      Row(children: [
        Expanded(child: _KpiCard(
          icon: Icons.precision_manufacturing_rounded, iconColor: _C.purple,
          value: '${d.summary.activeMachines}',
          label: 'Machines',
          sub: '${d.summary.activeShifts} shifts logged',
          gradient: [const Color(0xFF15102A), const Color(0xFF18122F)],
        )),
        const SizedBox(width:8),
        Expanded(child: _KpiCard(
          icon: Icons.group_rounded, iconColor: _C.amber,
          value: '${d.summary.activeEmployees}',
          label: 'Operators',
          sub: 'active in period',
          gradient: [const Color(0xFF201A08), const Color(0xFF251E08)],
        )),
      ]),
      const SizedBox(height:8),
      // KPI row 3: consistency + efficiency
      Row(children: [
        Expanded(child: _KpiCard(
          icon: Icons.auto_graph_rounded, iconColor: _C.cyanLt,
          value: '${d.summary.factoryConsistency}',
          unit: '%', label: 'Consistency',
          sub: 'factory-wide score',
          gradient: [const Color(0xFF0A1F25), const Color(0xFF0C2228)],
        )),
        const SizedBox(width:8),
        Expanded(child: _KpiCard(
          icon: Icons.timer_rounded, iconColor: _C.orange,
          value: _fmtMinutes(d.summary.totalRunMinutes),
          label: 'Run Time',
          sub: 'total machine hours',
          gradient: [const Color(0xFF201408), const Color(0xFF25160A)],
        )),
      ]),
      const SizedBox(height:14),

      // Anomaly banner
      if (d.summary.anomalyCount > 0)
        _AnomalyBanner(count:d.summary.anomalyCount, onTap:() => c.activeTab.value=AnalyticsTab.anomalies),

      // Day vs Night split
      _SectionLabel(icon:Icons.compare_arrows_rounded, label:'Day vs Night Split', color:_C.blue),
      const SizedBox(height:8),
      _DayNightBar(dvn: d.summary.dayVsNight),
      const SizedBox(height:14),

      // Trend chart
      _SectionLabel(icon:Icons.trending_up_rounded, label:'Production Trend', color:_C.cyan),
      const SizedBox(height:8),
      if (d.trend.isEmpty)
        const _NoDataChip()
      else
        _TrendChart(trend:d.trend, overallAvg:d.summary.avgPerShift, c:c),
      const SizedBox(height:14),

      // Weekly heatmap
      if (d.weeklyPattern.isNotEmpty) ...[
        _SectionLabel(icon:Icons.calendar_view_week_rounded, label:'Weekly Pattern', color:_C.purple),
        const SizedBox(height:8),
        _WeeklyHeatmap(pattern: d.weeklyPattern, max: c.weeklyPatternMax),
        const SizedBox(height:14),
      ],

      // Top machines
      _SectionLabel(icon:Icons.precision_manufacturing_rounded, label:'Top Machines', color:_C.green),
      const SizedBox(height:8),
      ...d.byMachine.take(3).map((m) => _MachineRowCompact(m:m, max:c.machineMax, avg:d.summary.avgPerShift, c:c)),
      const SizedBox(height:14),

      // Top employees podium
      if (d.byEmployee.isNotEmpty) ...[
        _SectionLabel(icon:Icons.emoji_events_rounded, label:'Top Performers', color:_C.gold),
        const SizedBox(height:8),
        _PodiumWidget(employees: d.byEmployee.take(3).toList()),
      ],
      const SizedBox(height:20),
    ]);
  }
}

String _fmtMinutes(int mins) {
  if (mins <= 0) return '0h';
  final h = mins ~/ 60;
  if (h >= 100) return '${h}h';
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ── Day vs Night split bar ────────────────────────────────────
class _DayNightBar extends StatelessWidget {
  final DayVsNight dvn;
  const _DayNightBar({required this.dvn});

  @override
  Widget build(BuildContext context) {
    final total = dvn.total;
    if (total == 0) return const _NoDataChip();
    final dayPct   = dvn.dayPct;
    final nightPct = 1.0 - dayPct;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Column(children: [
        Row(children: [
          _splitLabel('☀️ Day', dvn.day, _C.amber),
          const Spacer(),
          _splitLabel('🌙 Night', dvn.night, _C.purple),
        ]),
        const SizedBox(height:10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height:16, color:_C.purple.withOpacity(0.3)),
            FractionallySizedBox(
              widthFactor: dayPct,
              child: Container(height:16,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors:[Color(0xFFB45309), Color(0xFFF59E0B)]))),
            ),
          ]),
        ),
        const SizedBox(height:6),
        Row(children: [
          Text('${(dayPct*100).toStringAsFixed(1)}%',
              style: const TextStyle(color:_C.amber, fontSize:11, fontWeight:FontWeight.w700)),
          const Spacer(),
          Text('${(nightPct*100).toStringAsFixed(1)}%',
              style: const TextStyle(color:_C.purple, fontSize:11, fontWeight:FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _splitLabel(String label, int val, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color:color, fontSize:12, fontWeight:FontWeight.w700)),
      Text('${_fmt(val)}m', style: const TextStyle(color:_C.textPrim, fontSize:16, fontWeight:FontWeight.w900)),
    ]);
  }
}

// ── Trend chart (custom painted) ───────────────────────────────
class _TrendChart extends StatelessWidget {
  final List<TrendPoint> trend;
  final int overallAvg;
  final AnalyticsController c;
  const _TrendChart({required this.trend, required this.overallAvg, required this.c});

  @override
  Widget build(BuildContext context) {
    final mx = c.trendMax.toDouble();
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8,12,8,8),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Stack(children: [
        CustomPaint(
          painter: _TrendPainter(
              trend: trend, max: mx, avgLine: overallAvg.toDouble()),
          size: Size.infinite,
        ),
        Positioned(bottom:0, left:0, right:0,
            child: CustomPaint(
              painter: _TrendLabelPainter(trend: trend),
              size: const Size(double.infinity, 16),
            )),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> trend;
  final double max;
  final double avgLine;
  _TrendPainter({required this.trend, required this.max, required this.avgLine});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty || max <= 0) return;
    final n       = trend.length;
    final barW    = math.max(3.0, (size.width / n) * 0.6);
    final spacing = size.width / n;
    final chartH  = size.height - 20;

    // Draw average dashed line
    if (avgLine > 0) {
      final avgY = chartH * (1 - avgLine / max);
      final dash = Paint()
        ..color = _C.cyan.withOpacity(0.4)
        ..strokeWidth = 1;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, avgY), Offset(x+6, avgY), dash);
        x += 10;
      }
    }

    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final p    = trend[i];
      final cx   = i * spacing + spacing / 2;
      final prod = p.production.toDouble();
      final h    = max <= 0 ? 0.0 : math.max(2.0, chartH * (prod / max));
      final top  = chartH - h;

      Color barColor;
      if (prod == 0)              barColor = _C.red;
      else if (prod < avgLine*0.7) barColor = _C.amber;
      else                         barColor = _C.cyan;

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin:Alignment.topCenter, end:Alignment.bottomCenter,
          colors:[barColor.withOpacity(0.9), barColor.withOpacity(0.3)],
        ).createShader(Rect.fromLTWH(cx-barW/2, top, barW, h));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx-barW/2, top, barW, h),
            const Radius.circular(2)),
        barPaint,
      );
      pts.add(Offset(cx, top));
    }

    // Line overlay
    if (pts.length > 1) {
      final linePaint = Paint()
        ..color = _C.green.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var p in pts.skip(1)) path.lineTo(p.dx, p.dy);
      canvas.drawPath(path, linePaint);
      // dots
      final dotPaint = Paint()..color = _C.green;
      for (var p in pts) {
        canvas.drawCircle(p, 2.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class _TrendLabelPainter extends CustomPainter {
  final List<TrendPoint> trend;
  _TrendLabelPainter({required this.trend});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;
    final n    = trend.length;
    final step = size.width / n;
    final maxLabels = math.min(n, 8);
    final every = math.max(1, (n / maxLabels).ceil());
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < n; i += every) {
      tp.text = TextSpan(
        text: trend[i].dayOfWeek,
        style: const TextStyle(color:_C.textMuted, fontSize:9),
      );
      tp.layout();
      tp.paint(canvas, Offset(i*step + step/2 - tp.width/2, 2));
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Weekly heatmap ────────────────────────────────────────────
class _WeeklyHeatmap extends StatelessWidget {
  final List<WeeklyPatternPoint> pattern;
  final int max;
  const _WeeklyHeatmap({required this.pattern, required this.max});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: pattern.map((p) => _dayCell(p)).toList(),
        ),
        const SizedBox(height:8),
        Row(children: [
          Container(width:8, height:8,
              decoration:BoxDecoration(color:_C.surface3, borderRadius:BorderRadius.circular(2))),
          const SizedBox(width:4),
          const Text('Low', style:_t10),
          const SizedBox(width:12),
          Container(width:8, height:8,
              decoration:BoxDecoration(color:_C.purple.withOpacity(0.5), borderRadius:BorderRadius.circular(2))),
          const SizedBox(width:4),
          const Text('Mid', style:_t10),
          const SizedBox(width:12),
          Container(width:8, height:8,
              decoration:BoxDecoration(color:_C.purple, borderRadius:BorderRadius.circular(2))),
          const SizedBox(width:4),
          const Text('Peak', style:_t10),
        ]),
      ]),
    );
  }

  Widget _dayCell(WeeklyPatternPoint p) {
    final ratio = max > 0 ? p.avgProduction / max : 0.0;
    final Color cellColor;
    if (ratio < 0.15)      cellColor = _C.surface3;
    else if (ratio < 0.40) cellColor = _C.purple.withOpacity(0.25);
    else if (ratio < 0.70) cellColor = _C.purple.withOpacity(0.55);
    else                   cellColor = _C.purple;

    return Column(children: [
      Text(p.dayName, style: _t10),
      const SizedBox(height:4),
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.border),
          boxShadow: ratio > 0.7
              ? [BoxShadow(color:_C.purple.withOpacity(0.4), blurRadius:6)] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          p.avgProduction > 0 ? _fmt(p.avgProduction) : '–',
          style: TextStyle(
              fontSize: 9, fontWeight:FontWeight.w700,
              color: ratio > 0.4 ? _C.textPrim : _C.textMuted),
        ),
      ),
      const SizedBox(height:3),
      Text('${p.shiftCount}s', style: const TextStyle(color:_C.textMuted, fontSize:8)),
    ]);
  }
}

// ── Podium widget (top 3 employees) ───────────────────────────
class _PodiumWidget extends StatelessWidget {
  final List<EmployeeAnalytics> employees;
  const _PodiumWidget({required this.employees});

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) return const _NoDataChip();
    // Reorder: silver, gold, bronze
    final ordered = <EmployeeAnalytics>[];
    if (employees.length > 1) ordered.add(employees[1]);
    ordered.add(employees[0]);
    if (employees.length > 2) ordered.add(employees[2]);

    final heights = [80.0, 100.0, 60.0];
    final colors  = [_C.silver, _C.gold, _C.bronze];
    final crowns  = ['🥈', '🥇', '🥉'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(ordered.length, (i) {
          final emp = ordered[i];
          final isGold = i == 1;
          return Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(crowns[i], style: const TextStyle(fontSize:20)),
              const SizedBox(height:4),
              Container(
                width:40, height:40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i].withOpacity(0.15),
                  border: Border.all(color:colors[i], width:2),
                  boxShadow: isGold
                      ? [BoxShadow(color:_C.gold.withOpacity(0.4), blurRadius:12)] : [],
                ),
                child: Center(child: Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style: TextStyle(color:colors[i], fontSize:18, fontWeight:FontWeight.w900))),
              ),
              const SizedBox(height:6),
              Text(emp.name.split(' ').first,
                  style: TextStyle(color:isGold ? _C.gold : _C.textSec,
                      fontSize:10, fontWeight:FontWeight.w700),
                  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              Text('${_fmt(emp.totalProduction)}m',
                  style: TextStyle(color:isGold ? _C.gold : _C.textPrim,
                      fontSize:12, fontWeight:FontWeight.w900)),
              const SizedBox(height:4),
              Container(
                height: heights[i],
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin:Alignment.topCenter, end:Alignment.bottomCenter,
                      colors:[colors[i].withOpacity(0.4), colors[i].withOpacity(0.1)]),
                  borderRadius: const BorderRadius.vertical(top:Radius.circular(4)),
                ),
              ),
            ],
          ));
        }),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════

// ── Machines tab ──────────────────────────────────────────────
class _MachinesTab extends StatelessWidget {
  final AnalyticsController c;
  const _MachinesTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final machines = c.data.value?.byMachine ?? [];
    final avg      = c.data.value?.summary.avgPerShift ?? 0;
    if (machines.isEmpty) return const Center(child:_EmptyView());
    return ListView(padding:const EdgeInsets.all(14), children: [
      // Summary mini-cards
      _SectionLabel(icon:Icons.precision_manufacturing_rounded, label:'Machine Performance', color:_C.green),
      const SizedBox(height:8),
      Row(children: [
        Expanded(child: _MiniStat('Avg/Head', '${c.data.value?.summary.avgEfficiencyScore??0}m', Icons.hub_rounded, _C.cyan)),
        const SizedBox(width:8),
        Expanded(child: _MiniStat('Consistency', '${c.data.value?.summary.factoryConsistency??0}%', Icons.auto_graph_rounded, _C.purple)),
        const SizedBox(width:8),
        Expanded(child: _MiniStat('Machines', '${machines.length}', Icons.memory_rounded, _C.green)),
      ]),
      const SizedBox(height:14),
      ...machines.asMap().entries.map((e) => _MachineBigRow(
        m: e.value, rank: e.key+1,
        max: c.machineMax, avg: avg, c: c,
      )),
      const SizedBox(height:20),
    ]);
  }
}

class _MachineBigRow extends StatelessWidget {
  final MachineAnalytics m;
  final int rank;
  final int max;
  final int avg;
  final AnalyticsController c;
  const _MachineBigRow({required this.m, required this.rank, required this.max, required this.avg, required this.c});

  @override
  Widget build(BuildContext context) {
    final isFiltered = c.filterMachineId.value == m.machineId;
    final aboveAvg   = m.avgPerShift > avg;
    final barRatio   = max > 0 ? m.totalProduction / max : 0.0;
    final barColor   = m.anomalyCount > 0 ? _C.red : aboveAvg ? _C.green : _C.blue;

    return GestureDetector(
      onTap: () => c.drillMachine(m.machineId),
      child: Container(
        margin: const EdgeInsets.only(bottom:8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isFiltered ? _C.blue.withOpacity(0.7) : _C.border, width:isFiltered?2:1),
          boxShadow: isFiltered
              ? [BoxShadow(color:_C.blue.withOpacity(0.15), blurRadius:8)] : [],
        ),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            _RankBadge(rank: rank, highlight: rank==1),
            const SizedBox(width:10),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Machine ${m.machineNo}', style:_t14b),
                if (m.isActive) ...[
                  const SizedBox(width:6),
                  _ActiveDot(),
                ],
              ]),
              Text('${m.manufacturer} · ${m.noOfHeads} heads · ${m.shiftCount} shifts',
                  style: _t11),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children: [
              Text('${_fmt(m.totalProduction)}m',
                  style: const TextStyle(color:_C.textPrim, fontSize:16, fontWeight:FontWeight.w900)),
              Text('${_fmt(m.avgPerShift)}m / shift', style:_t11),
            ]),
          ]),
          const SizedBox(height:12),

          // Bar chart row
          Row(children: [
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
              Stack(children: [
                Container(height:8, decoration:BoxDecoration(
                    color:_C.surface3, borderRadius:BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: barRatio.clamp(0.0,1.0),
                  child: Container(height:8, decoration:BoxDecoration(
                      borderRadius:BorderRadius.circular(4),
                      gradient: LinearGradient(colors:[barColor.withOpacity(0.6), barColor]))),
                ),
                // Average marker
                if (avg > 0 && max > 0)
                  FractionallySizedBox(
                    widthFactor: (avg / max * (barRatio.clamp(0.0,1.0) > 0 ? 1.0 : 0.0)).clamp(0.0,1.0),
                    child: Align(alignment:Alignment.centerRight,
                        child: Container(width:2, height:8,
                            decoration:BoxDecoration(color:_C.cyan, borderRadius:BorderRadius.circular(1)))),
                  ),
              ]),
            ])),
          ]),
          const SizedBox(height:10),

          // Stats row
          Row(children: [
            _StatChip(icon:Icons.hub_rounded, label:'${m.efficiencyPerHead}m/head', color:_C.cyan),
            const SizedBox(width:6),
            _StatChip(icon:Icons.auto_graph_rounded, label:'${m.consistencyScore}% consistent', color:_C.purple),
            const SizedBox(width:6),
            _TrendArrow(direction:m.trendDirection, improvement:m.improvement),
            const Spacer(),
            if (m.streak > 1)
              _StreakBadge(streak: m.streak),
          ]),
          const SizedBox(height:8),

          // Utilisation + best/worst
          Row(children: [
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
              Text('Utilisation', style:_t10),
              const SizedBox(height:3),
              Stack(children: [
                Container(height:4, decoration:BoxDecoration(
                    color:_C.surface3, borderRadius:BorderRadius.circular(2))),
                FractionallySizedBox(
                  widthFactor: (m.utilizationPct/100).clamp(0.0,1.0),
                  child: Container(height:4, decoration:BoxDecoration(
                      color:_C.amber, borderRadius:BorderRadius.circular(2))),
                ),
              ]),
              const SizedBox(height:2),
              Text('${m.utilizationPct}% of shift time running',
                  style:const TextStyle(color:_C.amber, fontSize:9, fontWeight:FontWeight.w600)),
            ])),
            const SizedBox(width:12),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children: [
              Text('Best: ${_fmt(m.bestShift)}m',
                  style:const TextStyle(color:_C.greenLt, fontSize:10, fontWeight:FontWeight.w600)),
              Text('Worst: ${_fmt(m.worstShift)}m',
                  style:const TextStyle(color:_C.red, fontSize:10, fontWeight:FontWeight.w600)),
            ]),
          ]),

          // Anomaly warning
          if (m.anomalyCount > 0) ...[
            const SizedBox(height:8),
            Container(
              padding:const EdgeInsets.symmetric(horizontal:8, vertical:4),
              decoration:BoxDecoration(
                  color:_C.red.withOpacity(0.1), borderRadius:BorderRadius.circular(4),
                  border:Border.all(color:_C.red.withOpacity(0.3))),
              child: Row(mainAxisSize:MainAxisSize.min, children:[
                const Icon(Icons.warning_rounded, size:10, color:_C.red),
                const SizedBox(width:4),
                Text('${m.anomalyCount} anomaly event${m.anomalyCount>1?"s":""}',
                    style:const TextStyle(color:_C.red, fontSize:10, fontWeight:FontWeight.w600)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Employees tab ─────────────────────────────────────────────
class _EmployeesTab extends StatelessWidget {
  final AnalyticsController c;
  const _EmployeesTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final emps = c.data.value?.byEmployee ?? [];
    if (emps.isEmpty) return const Center(child:_EmptyView());
    return ListView(padding:const EdgeInsets.all(14), children: [
      _SectionLabel(icon:Icons.people_rounded, label:'Employee Leaderboard', color:_C.gold),
      const SizedBox(height:8),
      ...emps.map((e) => _EmployeeDetailCard(emp:e, c:c)),
      const SizedBox(height:20),
    ]);
  }
}

class _EmployeeDetailCard extends StatelessWidget {
  final EmployeeAnalytics emp;
  final AnalyticsController c;
  const _EmployeeDetailCard({required this.emp, required this.c});

  Color get _badgeColor {
    switch (emp.badge) {
      case 'gold':   return _C.gold;
      case 'silver': return _C.silver;
      case 'bronze': return _C.bronze;
      case 'star':   return _C.purple;
      default:       return _C.surface3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = c.filterEmployeeId.value == emp.employeeId;
    return GestureDetector(
      onTap: () => c.drillEmployee(emp.employeeId),
      child: Container(
        margin: const EdgeInsets.only(bottom:8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isFiltered ? _C.blue.withOpacity(0.7) : _C.border,
              width: isFiltered ? 2 : 1),
        ),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            // Avatar
            Container(width:40, height:40,
                decoration:BoxDecoration(
                    shape:BoxShape.circle,
                    color:_badgeColor.withOpacity(0.15),
                    border:Border.all(color:_badgeColor, width:1.5)),
                child:Center(child:Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style:TextStyle(color:_badgeColor, fontSize:16, fontWeight:FontWeight.w900)))),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[
                Expanded(child:Text(emp.name, style:_t14b, overflow:TextOverflow.ellipsis)),
                _RankBadge(rank:emp.rank, highlight:emp.rank==1),
              ]),
              Text('${emp.department} · ${emp.skill}', style:_t11),
              if (emp.badgeLabel.isNotEmpty)
                Text(emp.badgeLabel, style:TextStyle(
                    color:_badgeColor, fontSize:10, fontWeight:FontWeight.w700)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Text('${_fmt(emp.totalProduction)}m',
                  style:TextStyle(
                      color:emp.badge=='gold'?_C.gold:_C.textPrim,
                      fontSize:18, fontWeight:FontWeight.w900)),
              Text('${_fmt(emp.avgPerShift)}m / shift', style:_t11),
            ]),
          ]),
          const SizedBox(height:12),

          // Stats row
          Row(children:[
            _StatChip(icon:Icons.auto_graph_rounded, label:'${emp.consistencyScore}% consist.', color:_C.cyan),
            const SizedBox(width:6),
            _TrendArrow(direction:emp.trendDirection, improvement:emp.improvement),
            const SizedBox(width:6),
            if (emp.streak > 1) _StreakBadge(streak:emp.streak),
            const Spacer(),
            Text('Top ${100-emp.percentile+1}%',
                style:TextStyle(color:emp.percentile>=90?_C.green:_C.textSec,
                    fontSize:10, fontWeight:FontWeight.w700)),
          ]),
          const SizedBox(height:10),

          // Best / worst / shifts
          Row(children:[
            Expanded(child:_InfoPill('🏆 Best', '${_fmt(emp.bestShift)}m', _C.greenLt)),
            const SizedBox(width:6),
            Expanded(child:_InfoPill('⚠️ Worst', '${_fmt(emp.worstShift)}m', _C.red)),
            const SizedBox(width:6),
            Expanded(child:_InfoPill('⏱ Time', _fmtMinutes(emp.totalRunMinutes), _C.amber)),
          ]),

          // Achievement chips
          if (emp.achievements.isNotEmpty) ...[
            const SizedBox(height:10),
            Wrap(spacing:4, runSpacing:4,
                children: emp.achievements.take(5).map((a) => _AchievementChip(a:a)).toList()),
          ],
        ]),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════

// ── Arena tab ─────────────────────────────────────────────────
class _ArenaTab extends StatelessWidget {
  final AnalyticsController c;
  const _ArenaTab({required this.c});

  @override
  Widget build(BuildContext context) {
    final emps = c.data.value?.byEmployee ?? [];
    if (emps.isEmpty) return const Center(child:_EmptyView());

    // Sort by XP
    final ranked = [...emps]..sort((a,b)=>b.xp-a.xp);

    return ListView(padding:const EdgeInsets.all(14), children: [
      // Arena header
      _ArenaHeader(leader: ranked.first),
      const SizedBox(height:14),

      // Level legend
      _LevelLegend(),
      const SizedBox(height:14),

      // Player cards
      _SectionLabel(icon:Icons.leaderboard_rounded, label:'XP Leaderboard', color:_C.xpColor),
      const SizedBox(height:8),
      ...ranked.asMap().entries.map((e) => _PlayerCard(emp:e.value, xpRank:e.key+1, c:c)),
      const SizedBox(height:14),

      // Achievement showcase
      _SectionLabel(icon:Icons.military_tech_rounded, label:'Achievement Showcase', color:_C.amber),
      const SizedBox(height:8),
      _AchievementShowcase(emps: emps),
      const SizedBox(height:20),
    ]);
  }
}

// ── Arena header card ─────────────────────────────────────────
class _ArenaHeader extends StatelessWidget {
  final EmployeeAnalytics leader;
  const _ArenaHeader({required this.leader});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
            begin:Alignment.topLeft, end:Alignment.bottomRight,
            colors:[Color(0xFF1A1435), Color(0xFF0F1A30), Color(0xFF0A1525)]),
        border: Border.all(color:_C.xpColor.withOpacity(0.4), width:1.5),
        boxShadow:[BoxShadow(color:_C.xpGlow.withOpacity(0.2), blurRadius:20)],
      ),
      child: Column(children: [
        Row(children: [
          const Text('⚡', style:TextStyle(fontSize:24)),
          const SizedBox(width:8),
          Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
            const Text('PRODUCTION ARENA',
                style:TextStyle(color:_C.xpColor, fontSize:14, fontWeight:FontWeight.w900, letterSpacing:2)),
            Text('XP-Ranked Performance System',
                style:TextStyle(color:_C.xpColor.withOpacity(0.6), fontSize:10)),
          ]),
        ]),
        const SizedBox(height:14),
        // Current XP leader spotlight
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.gold.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color:_C.gold.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(width:44, height:44,
                decoration:BoxDecoration(shape:BoxShape.circle,
                    color:_C.gold.withOpacity(0.2),
                    border:Border.all(color:_C.gold, width:2),
                    boxShadow:[BoxShadow(color:_C.gold.withOpacity(0.5), blurRadius:12)]),
                child:Center(child:Text(
                    leader.name.isNotEmpty ? leader.name[0].toUpperCase() : '?',
                    style:const TextStyle(color:_C.gold, fontSize:20, fontWeight:FontWeight.w900)))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[
                Text(leader.levelIcon, style:const TextStyle(fontSize:14)),
                const SizedBox(width:4),
                Text('${leader.levelLabel}', style:TextStyle(
                    color:Color(AnalyticsController.levelColorInt(leader.levelColor)),
                    fontSize:11, fontWeight:FontWeight.w700)),
              ]),
              Text(leader.name, style:const TextStyle(color:_C.gold, fontSize:14, fontWeight:FontWeight.w900)),
              Text('${leader.totalProduction}m produced · Level ${leader.level}',
                  style:const TextStyle(color:_C.textSec, fontSize:10)),
            ])),
            Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
              Row(children:[
                const Text('⚡', style:TextStyle(fontSize:12)),
                Text(' ${leader.xp}', style:const TextStyle(color:_C.xpColor,
                    fontSize:20, fontWeight:FontWeight.w900)),
                const Text(' XP', style:TextStyle(color:_C.xpColor, fontSize:11)),
              ]),
              const Text('🏆 Top Player', style:TextStyle(color:_C.gold, fontSize:10)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Level legend ──────────────────────────────────────────────
class _LevelLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const levels = [
      ('🌱','Rookie','50'),    ('⚙️','Operator','150'),
      ('🔧','Craftsman','300'),('⚡','Expert','600'),
      ('🔥','Master','1000'), ('👑','Legend','∞'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
        const Text('LEVEL TIERS', style:TextStyle(color:_C.textMuted, fontSize:9, letterSpacing:1.5)),
        const SizedBox(height:8),
        Wrap(spacing:8, runSpacing:6,
            children: levels.map((l) => Container(
              padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
              decoration: BoxDecoration(color:_C.surface3, borderRadius:BorderRadius.circular(6),
                  border:Border.all(color:_C.borderBrt)),
              child: Row(mainAxisSize:MainAxisSize.min, children:[
                Text(l.$1, style:const TextStyle(fontSize:11)),
                const SizedBox(width:4),
                Text(l.$2, style:const TextStyle(color:_C.textPrim, fontSize:10, fontWeight:FontWeight.w700)),
                const SizedBox(width:4),
                Text('≥${l.$3}', style:const TextStyle(color:_C.textMuted, fontSize:9)),
              ]),
            )).toList()),
      ]),
    );
  }
}

// ── Player card ───────────────────────────────────────────────
class _PlayerCard extends StatelessWidget {
  final EmployeeAnalytics emp;
  final int xpRank;
  final AnalyticsController c;
  const _PlayerCard({required this.emp, required this.xpRank, required this.c});

  @override
  Widget build(BuildContext context) {
    final lvlColor = Color(AnalyticsController.levelColorInt(emp.levelColor));
    final isTop    = xpRank <= 3;

    return Obx(() {
      final isExpanded = c.expandedXpId.value == emp.employeeId;
      return GestureDetector(
        onTap: () => c.toggleXpBreakdown(emp.employeeId),
        child: Container(
          margin: const EdgeInsets.only(bottom:8),
          decoration: BoxDecoration(
            color: _C.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isTop ? lvlColor.withOpacity(0.4) : _C.border,
                width: isTop ? 1.5 : 1),
            boxShadow: isTop
                ? [BoxShadow(color:lvlColor.withOpacity(0.1), blurRadius:8)] : [],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // XP rank number
                Container(width:28, height:28,
                    decoration:BoxDecoration(
                        color:isTop ? lvlColor.withOpacity(0.2) : _C.surface3,
                        shape:BoxShape.circle,
                        border:Border.all(color:isTop?lvlColor:_C.border)),
                    child:Center(child:Text('$xpRank',
                        style:TextStyle(color:isTop?lvlColor:_C.textMuted,
                            fontSize:11, fontWeight:FontWeight.w900)))),
                const SizedBox(width:10),
                // Level badge
                Container(
                    padding: const EdgeInsets.symmetric(horizontal:6, vertical:3),
                    decoration: BoxDecoration(
                        color: lvlColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color:lvlColor.withOpacity(0.4))),
                    child: Row(mainAxisSize:MainAxisSize.min, children:[
                      Text(emp.levelIcon, style:const TextStyle(fontSize:12)),
                      const SizedBox(width:3),
                      Text('Lv.${emp.level}', style:TextStyle(
                          color:lvlColor, fontSize:10, fontWeight:FontWeight.w900)),
                    ])),
                const SizedBox(width:8),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                  Text(emp.name, style:_t13b, overflow:TextOverflow.ellipsis),
                  Text(emp.levelLabel, style:TextStyle(
                      color:lvlColor, fontSize:10, fontWeight:FontWeight.w600)),
                ])),
                Column(crossAxisAlignment:CrossAxisAlignment.end, children:[
                  Row(children:[
                    const Text('⚡ ', style:TextStyle(fontSize:11)),
                    Text('${emp.xp}', style:const TextStyle(color:_C.xpColor,
                        fontSize:16, fontWeight:FontWeight.w900)),
                    const Text(' XP', style:TextStyle(color:_C.xpColor, fontSize:10)),
                  ]),
                  Text('${_fmt(emp.totalProduction)}m', style:_t11),
                ]),
              ]),
            ),

            // XP progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12,0,12,10),
              child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Progress to next level', style:_t10),
                  const Spacer(),
                  Text('${emp.levelProgress}%', style:TextStyle(
                      color:lvlColor, fontSize:10, fontWeight:FontWeight.w700)),
                ]),
                const SizedBox(height:4),
                Stack(children: [
                  Container(height:6, decoration:BoxDecoration(
                      color:_C.surface3, borderRadius:BorderRadius.circular(3))),
                  FractionallySizedBox(
                      widthFactor:(emp.levelProgress/100).clamp(0.0,1.0),
                      child: Container(height:6, decoration:BoxDecoration(
                          borderRadius:BorderRadius.circular(3),
                          gradient:LinearGradient(
                              colors:[lvlColor.withOpacity(0.5), lvlColor])))),
                ]),
                if (emp.nextLevelXp != null) ...[
                  const SizedBox(height:2),
                  Text('${emp.nextLevelXp! - emp.xp} XP to ${_nextLevelLabel(emp.level)}',
                      style:const TextStyle(color:_C.textMuted, fontSize:9)),
                ],
              ]),
            ),

            // Achievement mini row
            if (emp.achievements.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(12,0,12,10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: emp.achievements.take(6).map((a) =>
                            Tooltip(
                              message: a.desc,
                              child: Container(
                                  margin:const EdgeInsets.only(right:5),
                                  padding:const EdgeInsets.symmetric(horizontal:6, vertical:3),
                                  decoration:BoxDecoration(
                                      color:_C.amber.withOpacity(0.1),
                                      borderRadius:BorderRadius.circular(5),
                                      border:Border.all(color:_C.amber.withOpacity(0.2))),
                                  child:Text('${a.icon} ${a.label}',
                                      style:const TextStyle(color:_C.amber, fontSize:9, fontWeight:FontWeight.w600))),
                            )).toList()),
                  )),

            // XP breakdown (expandable)
            if (isExpanded && emp.xpBreakdown.isNotEmpty) ...[
              const Divider(color:_C.border, height:1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
                  const Text('XP BREAKDOWN',
                      style:TextStyle(color:_C.xpColor, fontSize:9, fontWeight:FontWeight.w700, letterSpacing:1.5)),
                  const SizedBox(height:6),
                  ...emp.xpBreakdown.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom:3),
                    child: Row(children: [
                      const Text('· ', style:TextStyle(color:_C.xpColor, fontSize:10)),
                      Expanded(child:Text(line,
                          style:const TextStyle(color:_C.textSec, fontSize:10))),
                    ]),
                  )),
                ]),
              ),
            ],
          ]),
        ),
      );
    });
  }

  String _nextLevelLabel(int currentLevel) {
    const labels = ['','Operator','Craftsman','Expert','Master','Legend',''];
    if (currentLevel < labels.length-1) return labels[currentLevel+1];
    return 'Max';
  }
}

// ── Achievement showcase ──────────────────────────────────────
class _AchievementShowcase extends StatelessWidget {
  final List<EmployeeAnalytics> emps;
  const _AchievementShowcase({required this.emps});

  @override
  Widget build(BuildContext context) {
    // Collect all unique achievements across all employees
    final Map<String, Map<String,dynamic>> aMap = {};
    for (final emp in emps) {
      for (final a in emp.achievements) {
        if (!aMap.containsKey(a.id)) {
          aMap[a.id] = { 'icon':a.icon, 'label':a.label, 'desc':a.desc, 'holders':<String>[] };
        }
        (aMap[a.id]!['holders'] as List<String>).add(emp.name.split(' ').first);
      }
    }

    if (aMap.isEmpty) return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: const Center(child: Text('No achievements unlocked yet',
          style:TextStyle(color:_C.textMuted, fontSize:12))),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(10),
          border:Border.all(color:_C.border)),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: aMap.entries.map((e) {
          final holders = e.value['holders'] as List<String>;
          final multi   = holders.length > 1;
          return Container(
            padding: const EdgeInsets.all(10),
            width: 140,
            decoration: BoxDecoration(
              color: _C.surface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: multi ? _C.amber.withOpacity(0.3) : _C.border),
            ),
            child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
              Text(e.value['icon'] as String, style:const TextStyle(fontSize:18)),
              const SizedBox(height:4),
              Text(e.value['label'] as String,
                  style:const TextStyle(color:_C.textPrim, fontSize:11, fontWeight:FontWeight.w700)),
              const SizedBox(height:2),
              Text(e.value['desc'] as String,
                  style:const TextStyle(color:_C.textMuted, fontSize:9), maxLines:2,
                  overflow:TextOverflow.ellipsis),
              const SizedBox(height:4),
              Text('${holders.take(2).join(', ')}${holders.length>2?" +${holders.length-2}":""}',
                  style:const TextStyle(color:_C.amber, fontSize:9, fontWeight:FontWeight.w600)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Anomalies tab ─────────────────────────────────────────────
class _AnomaliesTab extends StatelessWidget {
  final AnalyticsController c;
  const _AnomaliesTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SeverityFilterBar(c: c),
      Expanded(child: Obx(() {
        final anomalies = c.filteredAnomalies;
        if (anomalies.isEmpty) return const _NoAnomaliesView();
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: anomalies.length,
          itemBuilder: (_,i) => _AnomalyCard(a: anomalies[i]),
        );
      })),
    ]);
  }
}

class _SeverityFilterBar extends StatelessWidget {
  final AnalyticsController c;
  const _SeverityFilterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    final all = c.data.value?.anomalies ?? [];
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.symmetric(horizontal:14, vertical:8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(children: [
          _sevChip(c, 'All',    'all',    all.length,    _C.textSec),
          _sevChip(c, 'High',   'high',   all.where((a)=>a.isHigh).length,   _C.red),
          _sevChip(c, 'Medium', 'medium', all.where((a)=>a.isMedium).length, _C.amber),
          _sevChip(c, 'Spikes', 'low',    all.where((a)=>a.severity=='low').length, _C.green),
        ])),
      ),
    );
  }

  Widget _sevChip(AnalyticsController c, String label, String val, int cnt, Color color) {
    final active = c.anomalySeverity.value == val;
    return GestureDetector(
      onTap: () => c.anomalySeverity.value = val,
      child: Container(
        margin: const EdgeInsets.only(right:6),
        padding: const EdgeInsets.symmetric(horizontal:10, vertical:5),
        decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : _C.surface3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? color.withOpacity(0.5) : _C.border)),
        child: Row(mainAxisSize:MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize:11, fontWeight:FontWeight.w700,
              color: active ? color : _C.textSec)),
          if (cnt > 0) ...[
            const SizedBox(width:5),
            Container(
                width:16, height:16, alignment:Alignment.center,
                decoration: BoxDecoration(color:color.withOpacity(0.25), shape:BoxShape.circle),
                child: Text('$cnt', style:TextStyle(color:color, fontSize:9, fontWeight:FontWeight.w900))),
          ],
        ]),
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final ProductionAnomaly a;
  const _AnomalyCard({required this.a});

  Color get _color => a.isHigh ? _C.red : a.isMedium ? _C.amber : _C.green;

  @override
  Widget build(BuildContext context) {
    final pct = a.threshold > 0 ? (a.value / a.threshold * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom:8),
      decoration: BoxDecoration(
        color: _C.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color:_color, width:3), top:BorderSide(color:_C.border),
            right:BorderSide(color:_C.border), bottom:BorderSide(color:_C.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                decoration:BoxDecoration(color:_color.withOpacity(0.15),
                    borderRadius:BorderRadius.circular(4),
                    border:Border.all(color:_color.withOpacity(0.4))),
                child:Text(a.typeLabel, style:TextStyle(color:_color,
                    fontSize:9, fontWeight:FontWeight.w700, letterSpacing:0.5))),
            const SizedBox(width:6),
            _SevPill(a.severity, _color),
            const Spacer(),
            Text(a.dateLabel, style:_t10),
          ]),
          const SizedBox(height:8),
          Text(a.message, style:_t12b),
          const SizedBox(height:6),
          Row(children: [
            Icon(a.entityType=='machine' ? Icons.memory_rounded : Icons.person_rounded,
                size:11, color:_color),
            const SizedBox(width:4),
            Text(a.entityName, style:TextStyle(color:_color, fontSize:10, fontWeight:FontWeight.w700)),
            const Spacer(),
            Text('Output: ${a.value}m  |  Threshold: ${a.threshold}m  |  $pct% of normal',
                style:_t10),
          ]),
        ]),
      ),
    );
  }
}

class _SevPill extends StatelessWidget {
  final String severity;
  final Color color;
  const _SevPill(this.severity, this.color);
  @override
  Widget build(BuildContext context) {
    final label = severity=='high' ? '🔴 HIGH' : severity=='medium' ? '🟡 MED' : '🟢 SPIKE';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal:5, vertical:1),
        decoration:BoxDecoration(color:color.withOpacity(0.1), borderRadius:BorderRadius.circular(4)),
        child: Text(label, style:TextStyle(color:color, fontSize:8, fontWeight:FontWeight.w700, letterSpacing:0.5)));
  }
}

class _NoAnomaliesView extends StatelessWidget {
  const _NoAnomaliesView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment:MainAxisAlignment.center, children: [
      const Text('✅', style:TextStyle(fontSize:48)),
      const SizedBox(height:12),
      const Text('No Anomalies Detected', style:TextStyle(color:_C.green, fontSize:16, fontWeight:FontWeight.w700)),
      const SizedBox(height:6),
      const Text('All machines and operators are\nperforming within normal ranges.',
          style:TextStyle(color:_C.textMuted, fontSize:12), textAlign:TextAlign.center),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════

// ── KPI card ──────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData iconData;
  final Color    iconColor;
  final String   value;
  final String?  unit;
  final String   label;
  final String   sub;
  final List<Color> gradient;

  const _KpiCard({
    required IconData icon,
    required this.iconColor,
    required this.value,
    this.unit,
    required this.label,
    this.sub = '',
    required this.gradient,
  }) : iconData = icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin:Alignment.topLeft, end:Alignment.bottomRight, colors:gradient),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color:_C.border),
      ),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(iconData, size:14, color:iconColor),
          const Spacer(),
        ]),
        const SizedBox(height:8),
        Row(crossAxisAlignment:CrossAxisAlignment.end, children: [
          Text(value, style: TextStyle(color:iconColor, fontSize:22, fontWeight:FontWeight.w900, height:1)),
          if (unit != null)
            Padding(padding:const EdgeInsets.only(left:2, bottom:1),
                child:Text(unit!, style:TextStyle(color:iconColor.withOpacity(0.7), fontSize:11))),
        ]),
        const SizedBox(height:2),
        Text(label, style:_t11b),
        if (sub.isNotEmpty) Text(sub, style:_t10),
      ]),
    );
  }
}

// ── Section label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _SectionLabel({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width:3, height:14, margin:const EdgeInsets.only(right:8),
        decoration:BoxDecoration(color:color, borderRadius:BorderRadius.circular(2))),
    Icon(icon, size:12, color:color),
    const SizedBox(width:5),
    Text(label.toUpperCase(),
        style:TextStyle(color:color, fontSize:10, fontWeight:FontWeight.w800, letterSpacing:1.2)),
  ]);
}

// ── Anomaly banner ────────────────────────────────────────────
class _AnomalyBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AnomalyBanner({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom:14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _C.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color:_C.red.withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size:14, color:_C.red),
        const SizedBox(width:8),
        Expanded(child:Text('$count high-severity anomaly event${count>1?"s":""} detected — Tap to review',
            style:const TextStyle(color:_C.red, fontSize:11, fontWeight:FontWeight.w700))),
        const Icon(Icons.arrow_forward_ios_rounded, size:11, color:_C.red),
      ]),
    ),
  );
}

// ── Rank badge ────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final int  rank;
  final bool highlight;
  const _RankBadge({required this.rank, this.highlight=false});
  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? _C.gold.withOpacity(0.2)
        : rank<=3 ? _C.surface3 : _C.surface3;
    final fg = highlight ? _C.gold
        : rank==2 ? _C.silver : rank==3 ? _C.bronze : _C.textSec;
    return Container(
      width:26, height:26,
      decoration:BoxDecoration(color:bg, shape:BoxShape.circle,
          border:Border.all(color:fg.withOpacity(0.5)),
          boxShadow: highlight ? [BoxShadow(color:_C.gold.withOpacity(0.4), blurRadius:8)] : []),
      child:Center(child:Text('#$rank',
          style:TextStyle(color:fg, fontSize:9, fontWeight:FontWeight.w900))),
    );
  }
}

// ── Active dot ────────────────────────────────────────────────
class _ActiveDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width:6, height:6,
    decoration:BoxDecoration(
        color:_C.green, shape:BoxShape.circle,
        boxShadow:[BoxShadow(color:_C.green.withOpacity(0.6), blurRadius:6)]),
  );
}

// ── Trend arrow ───────────────────────────────────────────────
class _TrendArrow extends StatelessWidget {
  final String direction;
  final int improvement;
  const _TrendArrow({required this.direction, required this.improvement});
  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    if (direction=='up')   { color=_C.green;  icon=Icons.trending_up_rounded; }
    else if (direction=='down') { color=_C.red;    icon=Icons.trending_down_rounded; }
    else                   { color=_C.textSec; icon=Icons.trending_flat_rounded; }
    final pctStr = improvement!=0 ? ' ${improvement>0?"+":""}$improvement%' : '';
    return Row(mainAxisSize:MainAxisSize.min, children:[
      Icon(icon, size:14, color:color),
      if (pctStr.isNotEmpty)
        Text(pctStr, style:TextStyle(color:color, fontSize:9, fontWeight:FontWeight.w700)),
    ]);
  }
}

// ── Streak badge ──────────────────────────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:6, vertical:2),
    decoration: BoxDecoration(color:_C.orange.withOpacity(0.15),
        borderRadius:BorderRadius.circular(4),
        border:Border.all(color:_C.orange.withOpacity(0.4))),
    child: Row(mainAxisSize:MainAxisSize.min, children:[
      const Text('🔥', style:TextStyle(fontSize:10)),
      const SizedBox(width:3),
      Text('$streak streak', style:const TextStyle(
          color:_C.orange, fontSize:9, fontWeight:FontWeight.w700)),
    ]),
  );
}

// ── Stat chip ─────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:6, vertical:3),
    decoration: BoxDecoration(color:color.withOpacity(0.1),
        borderRadius:BorderRadius.circular(4),
        border:Border.all(color:color.withOpacity(0.3))),
    child: Row(mainAxisSize:MainAxisSize.min, children:[
      Icon(icon, size:9, color:color),
      const SizedBox(width:3),
      Text(label, style:TextStyle(color:color, fontSize:9, fontWeight:FontWeight.w600)),
    ]),
  );
}

// ── Mini stat card ────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(8),
        border:Border.all(color:_C.border)),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Icon(icon, size:12, color:color),
      const SizedBox(height:4),
      Text(value, style:TextStyle(color:color, fontSize:16, fontWeight:FontWeight.w900)),
      Text(label, style:_t10),
    ]),
  );
}

// ── Info pill ─────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _InfoPill(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color:_C.surface3,
        borderRadius:BorderRadius.circular(6), border:Border.all(color:_C.border)),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Text(label, style:_t10),
      Text(value, style:TextStyle(color:color, fontSize:12, fontWeight:FontWeight.w800)),
    ]),
  );
}

// ── Achievement chip ──────────────────────────────────────────
class _AchievementChip extends StatelessWidget {
  final Achievement a;
  const _AchievementChip({required this.a});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:6, vertical:3),
    decoration: BoxDecoration(
        color: _C.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color:_C.amber.withOpacity(0.25))),
    child: Row(mainAxisSize:MainAxisSize.min, children:[
      Text(a.icon, style:const TextStyle(fontSize:10)),
      const SizedBox(width:3),
      Text(a.label, style:const TextStyle(color:_C.amber, fontSize:9, fontWeight:FontWeight.w600)),
    ]),
  );
}

// ── Compact machine row (overview) ────────────────────────────
class _MachineRowCompact extends StatelessWidget {
  final MachineAnalytics m;
  final int max;
  final int avg;
  final AnalyticsController c;
  const _MachineRowCompact({required this.m, required this.max, required this.avg, required this.c});
  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? m.totalProduction / max : 0.0;
    final color = m.avgPerShift > avg ? _C.green : _C.blue;
    return GestureDetector(
      onTap: () { c.drillMachine(m.machineId); c.activeTab.value=AnalyticsTab.byMachine; },
      child: Container(
        margin: const EdgeInsets.only(bottom:6),
        padding: const EdgeInsets.symmetric(horizontal:12, vertical:9),
        decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(8),
            border:Border.all(color:_C.border)),
        child: Row(children: [
          Text('M${m.machineNo}', style:_t12b),
          const SizedBox(width:10),
          Expanded(child:Stack(children:[
            Container(height:5, decoration:BoxDecoration(
                color:_C.surface3, borderRadius:BorderRadius.circular(3))),
            FractionallySizedBox(
                widthFactor:ratio.clamp(0.0,1.0),
                child:Container(height:5, decoration:BoxDecoration(
                    color:color, borderRadius:BorderRadius.circular(3)))),
          ])),
          const SizedBox(width:10),
          Text('${_fmt(m.totalProduction)}m', style:TextStyle(
              color:color, fontSize:11, fontWeight:FontWeight.w800)),
          const SizedBox(width:4),
          _TrendArrow(direction:m.trendDirection, improvement:m.improvement),
        ]),
      ),
    );
  }
}

// ── No data chip ──────────────────────────────────────────────
class _NoDataChip extends StatelessWidget {
  const _NoDataChip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
    decoration: BoxDecoration(color:_C.surface2, borderRadius:BorderRadius.circular(6),
        border:Border.all(color:_C.border)),
    child: const Text('No data for this period',
        style:TextStyle(color:_C.textMuted, fontSize:11)),
  );
}

// ── Loading / Error / Empty states ────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
      SizedBox(width:28, height:28,
          child:CircularProgressIndicator(color:_C.blue, strokeWidth:2)),
      SizedBox(height:12),
      Text('Loading analytics…', style:TextStyle(color:_C.textSec, fontSize:12)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final AnalyticsController c;
  const _ErrorView({required this.c});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
      const Icon(Icons.error_outline_rounded, color:_C.red, size:40),
      const SizedBox(height:10),
      Obx(() => Text(c.errorMsg.value??'Unknown error',
          style:const TextStyle(color:_C.red, fontSize:12), textAlign:TextAlign.center)),
      const SizedBox(height:12),
      GestureDetector(
          onTap: c.fetch,
          child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
              decoration:BoxDecoration(color:_C.blue.withOpacity(0.2),
                  borderRadius:BorderRadius.circular(8), border:Border.all(color:_C.blue.withOpacity(0.4))),
              child:const Text('Retry', style:TextStyle(color:_C.blueLt, fontWeight:FontWeight.w700)))),
    ]),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
      Icon(Icons.bar_chart_rounded, color:_C.textMuted, size:48),
      SizedBox(height:10),
      Text('No production data for this period',
          style:TextStyle(color:_C.textMuted, fontSize:13)),
    ]),
  );
}