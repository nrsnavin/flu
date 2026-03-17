import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../shift/screens/shift_detail.dart';
import '../../shiftProgram/screens/shiftDetailScreen.dart';
import '../controllers/employee_controller.dart';
import '../models/employee.dart';


// ══════════════════════════════════════════════════════════════
//  EMPLOYEE DETAIL PAGE
// ══════════════════════════════════════════════════════════════

class EmployeeDetailPage extends StatefulWidget {
  final String employeeId;
  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  late final EmployeeDetailController c;

  @override
  void initState() {
    super.initState();
    Get.delete<EmployeeDetailController>(force: true);
    c = Get.put(EmployeeDetailController(widget.employeeId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _ErrorState(
              message: c.errorMsg.value!, onRetry: c.fetchDetail);
        }
        final emp = c.employee.value;
        if (emp == null) {
          return _ErrorState(
              message: 'Employee not found', onRetry: c.fetchDetail);
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(children: [
              _HeroCard(emp: emp),
              const SizedBox(height: 12),
              _InfoCard(emp: emp),
              const SizedBox(height: 12),
              _PerformanceStats(c: c),
              const SizedBox(height: 12),
              _ShiftHistorySection(c: c),
            ]),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final emp = c.employee.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emp?.name ?? 'Employee Detail',
                style: ErpTextStyles.pageTitle),
            const Text('Employees  ›  Detail',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        );
      }),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetchDetail,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD  (avatar + name + role + dept)
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final EmployeeDetail emp;
  const _HeroCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    final perfColor = emp.performance >= 80
        ? ErpColors.successGreen
        : emp.performance >= 60
        ? ErpColors.warningAmber
        : emp.performance > 0
        ? ErpColors.errorRed
        : ErpColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        // ── Navy header ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Avatar circle
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(
                    color: ErpColors.accentBlue.withOpacity(0.6), width: 2),
              ),
              child: Center(
                child: Text(emp.initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emp.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(emp.role,
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.business_outlined,
                        size: 11, color: ErpColors.textOnDarkSub),
                    const SizedBox(width: 4),
                    Text(
                      emp.department[0].toUpperCase() +
                          emp.department.substring(1),
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub,
                          fontSize: 11),
                    ),
                  ]),
                ],
              ),
            ),
            // Performance badge
            if (emp.performance > 0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: perfColor.withOpacity(0.22),
                  border: Border.all(color: perfColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${emp.performance.toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: perfColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  Text('rating',
                      style: TextStyle(
                          color: perfColor.withOpacity(0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        // ── Stats strip ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            _StatBox(Icons.badge_outlined, 'EMP ID', emp.id),
            _vDiv(),
            _StatBox(Icons.phone_outlined, 'PHONE', emp.phoneNumber),
            _vDiv(),
            _StatBox(Icons.work_history_outlined, 'SHIFTS',
                '${emp.totalShifts}'),
          ]),
        ),
      ]),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 36, color: ErpColors.borderLight);
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBox(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 13, color: ErpColors.textMuted),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
      const SizedBox(height: 3),
      Text(value,
          style: const TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  INFO CARD
// ══════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final EmployeeDetail emp;
  const _InfoCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'EMPLOYEE INFORMATION',
      icon: Icons.person_outline_rounded,
      child: Column(children: [
        ErpInfoRow('Full Name',   emp.name),
        ErpInfoRow('Phone',       emp.phoneNumber),
        ErpInfoRow('Aadhaar',     emp.aadhar),
        ErpInfoRow('Department',
            emp.department[0].toUpperCase() + emp.department.substring(1)),
        ErpInfoRow('Role',        emp.role),
        ErpInfoRow('Employee ID', emp.id),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PERFORMANCE STATS  (computed from real shift data)
//
//  FIX: original showed hardcoded "82%", "24", "980 m", "7h 30m"
//  constants — completely disconnected from real data.
//  Now computed live from c.shifts using controller helpers.
// ══════════════════════════════════════════════════════════════
class _PerformanceStats extends StatelessWidget {
  final EmployeeDetailController c;
  const _PerformanceStats({required this.c});

  @override
  Widget build(BuildContext context) {
    if (c.shifts.isEmpty) return const SizedBox.shrink();

    final avgEff = c.avgEfficiency;
    final avgOut = c.avgOutput;
    final count  = c.shifts.length;

    Color effColor;
    if (avgEff >= 80) {
      effColor = ErpColors.successGreen;
    } else if (avgEff >= 60) {
      effColor = ErpColors.warningAmber;
    } else {
      effColor = ErpColors.errorRed;
    }

    return ErpSectionCard(
      title: 'PERFORMANCE SUMMARY  (last $count shifts)',
      icon: Icons.bar_chart_rounded,
      accentColor: effColor,
      child: Column(children: [
        // ── 4 stat boxes ─────────────────────────────────────
        Row(children: [
          _PerfBox(
            label: 'AVG EFFICIENCY',
            value: '${avgEff.toStringAsFixed(1)}%',
            sub: 'per shift',
            color: effColor,
            icon: Icons.speed_rounded,
          ),
          _divider(),
          _PerfBox(
            label: 'AVG OUTPUT',
            value: '${avgOut.toStringAsFixed(0)} m',
            sub: 'per shift',
            color: ErpColors.accentBlue,
            icon: Icons.straighten_outlined,
          ),
          _divider(),
          _PerfBox(
            label: 'AVG RUNTIME',
            value: c.avgRuntimeFormatted,
            sub: 'per shift',
            color: ErpColors.warningAmber,
            icon: Icons.timer_outlined,
          ),
          _divider(),
          _PerfBox(
            label: 'TOTAL SHIFTS',
            value: '$count',
            sub: 'recorded',
            color: ErpColors.textSecondary,
            icon: Icons.calendar_month_outlined,
          ),
        ]),
        const SizedBox(height: 14),
        // ── Efficiency bar ────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Average Efficiency',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${avgEff.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: effColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (avgEff / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: ErpColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(effColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            _Legend(ErpColors.successGreen, '≥ 80%  Good'),
            const SizedBox(width: 12),
            _Legend(ErpColors.warningAmber, '60–79%  Fair'),
            const SizedBox(width: 12),
            _Legend(ErpColors.errorRed, '< 60%  Poor'),
          ]),
        ]),
      ]),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 52, color: ErpColors.borderLight);
}

class _PerfBox extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;
  const _PerfBox({
    required this.label, required this.value,
    required this.sub, required this.color, required this.icon,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
        Text(label,
            style: const TextStyle(
                color: ErpColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2),
            textAlign: TextAlign.center),
        Text(sub,
            style: const TextStyle(
                color: ErpColors.textMuted, fontSize: 8)),
      ]),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  SHIFT HISTORY SECTION
// ══════════════════════════════════════════════════════════════
class _ShiftHistorySection extends StatelessWidget {
  final EmployeeDetailController c;
  const _ShiftHistorySection({required this.c});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'LAST ${c.shifts.length} SHIFTS',
      icon: Icons.schedule_outlined,
      child: c.shifts.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No shift history available',
              style:
              TextStyle(color: ErpColors.textMuted, fontSize: 12)),
        ),
      )
          : Column(
          children: c.shifts.map((sh) => _ShiftRow(shift: sh)).toList()),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final ShiftHistory shift;
  const _ShiftRow({required this.shift});

  @override
  Widget build(BuildContext context) {
    final effColor = shift.efficiency >= 80
        ? ErpColors.successGreen
        : shift.efficiency >= 60
        ? ErpColors.warningAmber
        : ErpColors.errorRed;

    final isDay = shift.shiftType == 'DAY';
    final shiftColor =
    isDay ? ErpColors.warningAmber : ErpColors.accentBlue;

    return GestureDetector(
      // FIX: was passing arguments: [shift.id] as a List
      //      → ShiftDetailScreen received List instead of String
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShiftDetailPage(shiftId: shift.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          // Shift type icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: shiftColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
              size: 17, color: shiftColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('dd MMM yyyy').format(shift.date)}  •  ${shift.shiftType}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        size: 11, color: ErpColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(shift.machineName,
                          style: const TextStyle(
                              color: ErpColors.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    _MicroChip(Icons.timer_outlined, shift.runtimeFormatted,
                        ErpColors.textSecondary),
                    const SizedBox(width: 8),
                    _MicroChip(Icons.straighten_outlined,
                        '${shift.outputMeters} m', ErpColors.accentBlue),
                  ]),
                ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${shift.efficiency.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: effColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            const Text('efficiency',
                style: TextStyle(color: ErpColors.textMuted, fontSize: 9)),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (shift.efficiency / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: ErpColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(effColor),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: ErpColors.textMuted, size: 16),
        ]),
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MicroChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );
}

// ── Error state ───────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Icon(Icons.error_outline,
            size: 34, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      const Text('Failed to load',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      Text(message,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue, elevation: 0),
        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
        label: const Text('Retry',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}