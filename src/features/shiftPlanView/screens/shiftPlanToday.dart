import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/shiftPlanView/controllers/shift_plan_view_controller.dart';
import 'package:production/src/features/shiftPlanView/screens/shiftPlanDetail.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../models/shiftSummary.dart';

class TodayShiftPage extends StatefulWidget {
  const TodayShiftPage({super.key});

  @override
  State<TodayShiftPage> createState() => _TodayShiftPageState();
}

class _TodayShiftPageState extends State<TodayShiftPage> {
  final controller = Get.put(ShiftController());

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toLocal();

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: "Today's Shifts",
        subtitle: DateFormat('EEEE, dd MMM yyyy').format(now),
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ErpColors.textOnDark, size: 20),
            onPressed: controller.fetchTodayShifts,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchTodayShifts,
          color: ErpColors.accentBlue,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              // ── Date Banner ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ErpColors.navyMid, ErpColors.navyDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: ErpColors.accentLight, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(now),
                      style: const TextStyle(
                        color: ErpColors.textOnDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: ErpColors.accentBlue.withOpacity(0.4)),
                      ),
                      child: Text(
                        DateFormat('HH:mm').format(now),
                        style: const TextStyle(
                          color: ErpColors.accentLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const ErpSectionLabel(text: "Shift Overview"),
              const SizedBox(height: 4),

              _shiftCard(
                title: 'DAY SHIFT',
                shift: controller.dayShift.value,
                icon: Icons.wb_sunny_outlined,
                accentColor: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              _shiftCard(
                title: 'NIGHT SHIFT',
                shift: controller.nightShift.value,
                icon: Icons.nightlight_outlined,
                accentColor: ErpColors.accentBlue,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _shiftCard({
    required String title,
    required ShiftSummaryModel? shift,
    required IconData icon,
    required Color accentColor,
  }) {
    // BUG FIX: null-safe check; fallback to empty shift
    if (shift == null || shift.id == "test") {
      return _emptyShift(title, icon, accentColor);
    }

    final isLocked = shift.status == "closed";

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(color: accentColor.withOpacity(0.15)),
                left: BorderSide(color: accentColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? ErpColors.statusCompletedBg
                        : ErpColors.statusOpenBg,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isLocked
                          ? ErpColors.statusCompletedBorder
                          : ErpColors.statusOpenBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLocked
                              ? ErpColors.successGreen
                              : ErpColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isLocked ? 'CLOSED' : 'RUNNING',
                        style: TextStyle(
                          color: isLocked
                              ? ErpColors.statusCompletedText
                              : ErpColors.statusOpenText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── KPI Row ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _kpiTile(
                  label: "MACHINES",
                  value: shift.runningMachines.toString(),
                  icon: Icons.precision_manufacturing_outlined,
                  color: const Color(0xFFDC2626),
                ),
                _divider(),
                _kpiTile(
                  label: "PRODUCTION",
                  value: "${shift.production.toStringAsFixed(0)} m",
                  icon: Icons.straighten_outlined,
                  color: ErpColors.accentBlue,
                ),
                _divider(),
                // BUG FIX: was showing runningMachines for operators
                _kpiTile(
                  label: "OPERATORS",
                  value: shift.operators.toString(),
                  icon: Icons.people_outline,
                  color: const Color(0xFFD97706),
                ),
              ],
            ),
          ),

          // ── Action ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () {
                  Get.to(
                        () => const ShiftPlanDetailPage(),
                    arguments: shift.id,
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                label: const Text(
                  "View Shift Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ErpColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: ErpColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 44,
      color: ErpColors.borderLight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _emptyShift(String title, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: ErpColors.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ErpTextStyles.cardTitle),
              const SizedBox(height: 3),
              const Text(
                "No shift plan created",
                style: TextStyle(color: ErpColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}