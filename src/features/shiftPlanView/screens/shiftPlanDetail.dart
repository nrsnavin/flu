import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/shiftPlanView/screens/pdf.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_plan_detail_controller.dart';
import '../models/shiftPlanDetail.dart';

class ShiftPlanDetailPage extends StatefulWidget {
  const ShiftPlanDetailPage({super.key});

  @override
  State<ShiftPlanDetailPage> createState() => _ShiftPlanDetailPageState();
}

class _ShiftPlanDetailPageState extends State<ShiftPlanDetailPage> {
  final controller = Get.put(ShiftPlanDetailController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: "Shift Plan Detail",
        actions: [
          TextButton.icon(
            onPressed: () => Get.to(() => ShiftPlanSummaryPdf()),
            icon: const Icon(Icons.picture_as_pdf, size: 15, color: ErpColors.accentLight),
            label: const Text(
              "PDF",
              style: TextStyle(color: ErpColors.accentLight, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        if (controller.shiftDetail.value == null) {
          return const Center(
            child: Text("No data found", style: TextStyle(color: ErpColors.textSecondary)),
          );
        }

        final shift = controller.shiftDetail.value!;
        return RefreshIndicator(
          onRefresh: controller.fetchShiftDetail,
          color: ErpColors.accentBlue,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _headerCard(shift),
              const SizedBox(height: 14),
              ErpSectionLabel(text: "Machines Running (${shift.machines.length})"),
              const SizedBox(height: 4),
              ...shift.machines.asMap().entries.map(
                    (e) => _machineRow(e.value, e.key.isOdd),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _headerCard(ShiftPlanDetailModel shift) {
    final isNight = shift.shift.toLowerCase().contains('night');
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ErpColors.navyMid, ErpColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isNight ? ErpColors.accentBlue : const Color(0xFFF59E0B),
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                color: isNight ? ErpColors.accentLight : const Color(0xFFFBBF24),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                "${shift.shift.toUpperCase()} SHIFT",
                style: const TextStyle(
                  color: ErpColors.textOnDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(shift.date),
                  style: const TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (shift.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              shift.description,
              style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 12),
            ),
          ],

          const SizedBox(height: 14),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
          const SizedBox(height: 14),

          // KPI row
          Row(
            children: [
              _headerKpi("MACHINES", shift.machines.length.toString(), Icons.precision_manufacturing_outlined),
              _headerKpi("OPERATORS", shift.operatorCount.toString(), Icons.people_outline),
              _headerKpi("PRODUCTION", "${shift.totalProduction} m", Icons.straighten),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerKpi(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: ErpColors.accentLight, size: 14),
          const SizedBox(height: 4),
          Text(value, style: ErpTextStyles.kpiValue.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: ErpTextStyles.kpiLabel.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _machineRow(ShiftMachineDetail machine, bool isAlt) {
    final isClosed = machine.status.toLowerCase() == "closed";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Machine header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAlt ? ErpColors.bgMuted : ErpColors.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              border: const Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.navyDark,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    machine.machineName,
                    style: const TextStyle(
                      color: ErpColors.textOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Job #${machine.jobOrderNo}",
                  style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? ErpColors.statusCompletedBg
                        : ErpColors.statusPartialBg,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isClosed
                          ? ErpColors.statusCompletedBorder
                          : ErpColors.statusPartialBorder,
                    ),
                  ),
                  child: Text(
                    machine.status.toUpperCase(),
                    style: TextStyle(
                      color: isClosed
                          ? ErpColors.statusCompletedText
                          : ErpColors.statusPartialText,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Machine details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _detailChip(Icons.person_outline, machine.operatorName),
                ),
                const SizedBox(width: 8),
                _miniStat("${machine.production} m", "Production"),
                const SizedBox(width: 8),
                _miniStat(machine.timer, "Run Time"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ErpColors.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ErpColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: ErpColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}