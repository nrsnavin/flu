// ══════════════════════════════════════════════════════════════
//  SHIFT PLAN DETAIL PAGE
//  File: lib/src/features/shiftPlanView/screens/shiftPlanDetail.dart
//
//  ADDED:
//  • Accepts shiftPlanId as constructor param OR Get.arguments
//    (backward-compat with TodayShiftPage which passes via arguments)
//  • Draft / Confirmed status badge in the header
//  • "Confirm Shift Plan" button shown only for draft plans
//  • Confirm dialog before posting the confirmation
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_plan_detail_controller.dart';
import '../models/shiftPlanDetail.dart';
import '../screens/pdf.dart';
import '../../shift/screens/shift_detail.dart'; // navigate on double-tap

class ShiftPlanDetailPage extends StatefulWidget {
  /// Pass the shift plan ObjectId directly when navigating from
  /// CreateShiftPlanPage. TodayShiftPage still passes via Get.arguments.
  final String? shiftPlanId;

  const ShiftPlanDetailPage({super.key, this.shiftPlanId});

  @override
  State<ShiftPlanDetailPage> createState() => _ShiftPlanDetailPageState();
}

class _ShiftPlanDetailPageState extends State<ShiftPlanDetailPage> {
  late final ShiftPlanDetailController c;

  @override
  void initState() {
    super.initState();
    // Prefer constructor param; fall back to Get.arguments for backward compat
    final id = (widget.shiftPlanId?.isNotEmpty == true)
        ? widget.shiftPlanId!
        : (Get.arguments as String? ?? '');

    Get.delete<ShiftPlanDetailController>(force: true);
    c = Get.put(ShiftPlanDetailController(shiftPlanId: id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }
        if (c.errorMsg.value != null) {
          return _ErrorBody(msg: c.errorMsg.value!, retry: c.fetchShiftDetail);
        }
        final detail = c.shiftDetail.value;
        if (detail == null) return const SizedBox.shrink();
        return _Body(detail: detail, c: c);
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    ),
    titleSpacing: 4,
    title: Obx(() {
      final d = c.shiftDetail.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Shift Plan Detail',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w800)),
          if (d != null)
            Text(
                '${d.shift} · ${DateFormat('dd MMM yyyy').format(d.date)}',
                style: const TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      );
    }),
    actions: [
      Obx(() => c.shiftDetail.value != null
          ? IconButton(
        icon: const Icon(Icons.picture_as_pdf_outlined,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShiftPlanSummaryPdf()),
        ),
      )
          : const SizedBox.shrink()),
      IconButton(
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        onPressed: c.fetchShiftDetail,
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  BODY
// ══════════════════════════════════════════════════════════════
class _Body extends StatelessWidget {
  final ShiftPlanDetailModel detail;
  final ShiftPlanDetailController c;
  const _Body({required this.detail, required this.c});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetchShiftDetail,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _HeroCard(detail: detail),
            const SizedBox(height: 12),
            if (detail.status == 'draft')
              _DraftBanner(c: c),
            if (detail.status == 'draft')
              const SizedBox(height: 12),
            _MachinesSection(detail: detail),
          ],
        ),
      ),
      // Sticky confirm bar — only for draft plans
      if (detail.status == 'draft')
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _ConfirmBar(c: c),
        ),
    ]);
  }
}

// ── Hero card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final ShiftPlanDetailModel detail;
  const _HeroCard({required this.detail});

  bool get _isDay   => detail.shift == 'DAY';
  bool get _isDraft => detail.status == 'draft';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ErpColors.navyDark,
            _isDay ? const Color(0xFF0D2A4A) : const Color(0xFF1A0D3D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _isDay ? ErpColors.warningAmber : ErpColors.accentBlue,
            width: 4,
          ),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: shift type + status badge
        Row(children: [
          // Shift icon + label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isDay ? ErpColors.warningAmber : ErpColors.accentBlue)
                  .withOpacity(0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  _isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                  color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(
                '${detail.shift} SHIFT',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Status badge
          _StatusBadge(status: detail.status),
          const Spacer(),
          // Date
          Text(
            DateFormat('dd MMM yyyy').format(detail.date),
            style: const TextStyle(
                color: ErpColors.textOnDarkSub,
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ]),

        const SizedBox(height: 14),

        // Total production
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${detail.totalProduction.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 36,
                fontWeight: FontWeight.w900, height: 1),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 4, left: 4),
            child: Text('m',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 2),
        const Text('Total Production',
            style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11)),

        if (detail.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              const Icon(Icons.notes_rounded,
                  color: ErpColors.textOnDarkSub, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(detail.description,
                    style: const TextStyle(
                        color: ErpColors.textOnDarkSub,
                        fontSize: 11, fontStyle: FontStyle.italic)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 12),

        // Machine count chip
        Row(children: [
          _HeroChip(
            Icons.precision_manufacturing_outlined,
            '${detail.machines.length}',
            'Machines',
          ),
          const SizedBox(width: 8),
          _HeroChip(
            Icons.group_outlined,
            '${detail.machines.where((m) => m.operatorName != '—').length}',
            'Operators',
          ),
        ]),
      ]),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _HeroChip(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: ErpColors.textOnDarkSub),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 8)),
      ]),
    ]),
  );
}

// ── Status badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDraft
            ? const Color(0xFF1D6AE5).withOpacity(0.2)
            : ErpColors.successGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDraft
              ? const Color(0xFF1D6AE5).withOpacity(0.5)
              : ErpColors.successGreen.withOpacity(0.5),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isDraft ? Icons.drafts_outlined : Icons.check_circle_outline,
          size: 11,
          color: isDraft ? const Color(0xFF93C5FD) : ErpColors.successGreen,
        ),
        const SizedBox(width: 4),
        Text(
          isDraft ? 'DRAFT' : 'CONFIRMED',
          style: TextStyle(
              color: isDraft ? const Color(0xFF93C5FD) : ErpColors.successGreen,
              fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ]),
    );
  }
}

// ── Draft banner ──────────────────────────────────────────────
class _DraftBanner extends StatelessWidget {
  final ShiftPlanDetailController c;
  const _DraftBanner({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: ErpColors.warningAmber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.drafts_outlined,
            size: 18, color: ErpColors.warningAmber),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This plan is a DRAFT',
              style: TextStyle(
                  color: ErpColors.warningAmber,
                  fontSize: 12, fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text(
            'Review the machine assignments below, then tap '
                '"Confirm Shift Plan" to make it active.',
            style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11),
          ),
        ]),
      ),
    ]),
  );
}

// ── Machines section ──────────────────────────────────────────
class _MachinesSection extends StatelessWidget {
  final ShiftPlanDetailModel detail;
  const _MachinesSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    if (detail.machines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.precision_manufacturing_outlined,
                size: 40, color: ErpColors.textMuted),
            SizedBox(height: 10),
            Text('No machines in this plan',
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
          ]),
        ),
      );
    }

    return ErpSectionCard(
      title: 'MACHINES  (${detail.machines.length})',
      icon: Icons.precision_manufacturing_outlined,
      child: Column(
        children: detail.machines
            .map((m) => _MachineRow(machine: m))
            .toList(),
      ),
    );
  }
}

class _MachineRow extends StatelessWidget {
  final ShiftMachineDetail machine;
  const _MachineRow({required this.machine});

  Color get _statusColor {
    switch (machine.status) {
      case 'closed':  return ErpColors.successGreen;
      case 'running': return ErpColors.accentBlue;
      default:        return ErpColors.warningAmber;
    }
  }

  bool get _hasProduction => machine.production > 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Double-tap → navigate to ShiftDetailPage for this machine
      onDoubleTap: machine.shiftDetailId.isNotEmpty
          ? () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ShiftDetailPage(shiftId: machine.shiftDetailId),
        ),
      )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hasProduction
                ? ErpColors.successGreen.withOpacity(0.35)
                : ErpColors.borderLight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.precision_manufacturing_outlined,
                    size: 18, color: ErpColors.accentBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machine.machineName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary)),
                    Row(children: [
                      Text('Job #${machine.jobOrderNo}',
                          style: const TextStyle(
                              color: ErpColors.textSecondary, fontSize: 11)),
                      const SizedBox(width: 6),
                      const Icon(Icons.person_outline_rounded,
                          size: 10, color: ErpColors.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(machine.operatorName,
                            style: const TextStyle(
                                color: ErpColors.textMuted, fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ),
              ),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _statusColor.withOpacity(0.35)),
                ),
                child: Text(
                  machine.status.toUpperCase(),
                  style: TextStyle(
                      color: _statusColor, fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
              ),
            ]),
          ),

          // ── Production stats ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              // Production — highlighted when > 0
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _hasProduction
                        ? ErpColors.successGreen.withOpacity(0.07)
                        : ErpColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _hasProduction
                          ? ErpColors.successGreen.withOpacity(0.3)
                          : ErpColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.straighten_rounded,
                            size: 10,
                            color: _hasProduction
                                ? ErpColors.successGreen
                                : ErpColors.textMuted),
                        const SizedBox(width: 3),
                        Text('Production',
                            style: TextStyle(
                                color: _hasProduction
                                    ? ErpColors.successGreen
                                    : ErpColors.textMuted,
                                fontSize: 8, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        _hasProduction
                            ? '${machine.production.toStringAsFixed(0)} m'
                            : '—',
                        style: TextStyle(
                            color: _hasProduction
                                ? ErpColors.successGreen
                                : ErpColors.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Timer
              Expanded(
                child: _Stat(
                  Icons.timer_outlined,
                  machine.status == 'open' ? '—' : machine.timer,
                  'Run Time',
                ),
              ),
            ]),
          ),

          // ── Double-tap hint ──────────────────────────────
          if (machine.shiftDetailId.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8)),
                border: Border(
                    top: BorderSide(color: ErpColors.borderLight)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 11, color: ErpColors.textMuted),
                  SizedBox(width: 4),
                  Text('Double-tap to view shift entry',
                      style: TextStyle(
                          color: ErpColors.textMuted,
                          fontSize: 9, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 10, color: ErpColors.textMuted),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 8,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 11, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  STICKY CONFIRM BAR  (draft only)
// ══════════════════════════════════════════════════════════════
class _ConfirmBar extends StatelessWidget {
  final ShiftPlanDetailController c;
  const _ConfirmBar({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: const Border(top: BorderSide(color: ErpColors.borderLight)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, -3)),
      ],
    ),
    child: Obx(() => SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: ErpColors.successGreen,
          disabledBackgroundColor: ErpColors.successGreen.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: c.isConfirming.value
            ? null
            : () => _showConfirmDialog(context),
        icon: c.isConfirming.value
            ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.check_circle_outline_rounded,
            color: Colors.white, size: 20),
        label: Text(
          c.isConfirming.value ? 'Confirming…' : 'Confirm Shift Plan',
          style: const TextStyle(
              color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
      ),
    )),
  );

  Future<void> _showConfirmDialog(BuildContext context) async {
    final detail = c.shiftDetail.value;
    if (detail == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(detail: detail),
    );

    if (confirmed == true) {
      await c.confirmShiftPlan();
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  CONFIRM DIALOG
// ══════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final ShiftPlanDetailModel detail;
  const _ConfirmDialog({required this.detail});

  bool get _isDay => detail.shift == 'DAY';

  @override
  Widget build(BuildContext context) {
    final accent = _isDay ? ErpColors.warningAmber : ErpColors.accentBlue;

    return Dialog(
      backgroundColor: ErpColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Icon ────────────────────────────────────────
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: ErpColors.successGreen.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: ErpColors.successGreen.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: ErpColors.successGreen, size: 32),
          ),
          const SizedBox(height: 16),

          // ── Title ────────────────────────────────────────
          const Text(
            'Confirm Shift Plan?',
            style: TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This will activate the ${detail.shift} shift plan for '
                '${DateFormat('dd MMM yyyy').format(detail.date)}. '
                'Operators will be able to enter production data.',
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Summary strip ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DialogStat(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: DateFormat('dd MMM').format(detail.date),
                  color: accent,
                ),
                Container(width: 1, height: 32, color: ErpColors.borderLight),
                _DialogStat(
                  icon: _isDay
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  label: 'Shift',
                  value: detail.shift,
                  color: accent,
                ),
                Container(width: 1, height: 32, color: ErpColors.borderLight),
                _DialogStat(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Machines',
                  value: '${detail.machines.length}',
                  color: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Buttons ───────────────────────────────────────
          Row(children: [
            // Cancel
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.borderLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            // Confirm
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.successGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Yes, Confirm',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _DialogStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DialogStat({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(height: 4),
    Text(value,
        style: TextStyle(
            color: color, fontSize: 14,
            fontWeight: FontWeight.w900)),
    Text(label,
        style: const TextStyle(
            color: ErpColors.textMuted,
            fontSize: 9, fontWeight: FontWeight.w600)),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  ERROR BODY
// ══════════════════════════════════════════════════════════════
class _ErrorBody extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorBody({required this.msg, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined,
            size: 48, color: ErpColors.textMuted),
        const SizedBox(height: 14),
        const Text('Failed to load shift plan',
            style: TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(msg,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: retry,
          style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
          label: const Text('Retry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}