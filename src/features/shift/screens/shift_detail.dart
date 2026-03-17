import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_detail.dart';
import '../models/shift_detail_view_model.dart';

class ShiftDetailPage extends StatelessWidget {
  final String shiftId;

  const ShiftDetailPage({super.key, required this.shiftId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShiftDetailController(shiftId));

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: "Shift Entry"),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        final shift = controller.shift.value;
        if (shift == null) {
          return const Center(
            child: Text("Shift not found", style: TextStyle(color: ErpColors.textSecondary)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Shift Info Header ──────────────────────
              _shiftHeader(shift),
              const SizedBox(height: 14),

              // ── Machine Info ───────────────────────────
              ErpSectionCard(
                title: "Machine Info",
                icon: Icons.precision_manufacturing_outlined,
                child: Column(
                  children: [
                    ErpInfoRow("Machine ID", shift.machineName),
                    ErpInfoRow("Job Order", "#${shift.jobNo}"),
                    const SizedBox(height: 8),
                    if (shift.runningElastics.isNotEmpty) ...[
                      const Text(
                        "RUNNING ELASTICS",
                        style: ErpTextStyles.sectionHeader,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: shift.runningElastics
                            .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ErpColors.statusOpenBg,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: ErpColors.statusOpenBorder),
                          ),
                          child: Text(
                            e,
                            style: const TextStyle(
                              color: ErpColors.statusOpenText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Entry Form or Summary ──────────────────
              shift.status == "open"
                  ? _entryForm(controller)
                  : _summaryCard(shift),

              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _shiftHeader(ShiftDetailViewModel shift) {
    final isNight = shift.shift.toLowerCase().contains('night');
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Icon(
            isNight ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
            color: isNight ? ErpColors.accentLight : const Color(0xFFFBBF24),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${shift.shift.toUpperCase()} SHIFT",
                  style: const TextStyle(
                    color: ErpColors.textOnDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMEd().format(DateTime.parse(shift.date)),
                  style: const TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shift.employeeName,
                  style: const TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: shift.status == "open"
                  ? ErpColors.statusOpenBg
                  : ErpColors.statusCompletedBg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              shift.status.toUpperCase(),
              style: TextStyle(
                color: shift.status == "open"
                    ? ErpColors.statusOpenText
                    : ErpColors.statusCompletedText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryForm(ShiftDetailController controller) {
    return ErpFormSection(
      title: "Production Entry",
      children: [
        TextField(
          controller: controller.productionController,
          keyboardType: TextInputType.number,
          decoration: ErpDecorations.formInput(
            "Production (meters)",
            hint: "e.g. 850",
            prefix: const Icon(Icons.straighten, size: 18, color: ErpColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.timerController,
          decoration: ErpDecorations.formInput(
            "Run Time",
            hint: "HH:MM:SS",
            prefix: const Icon(Icons.timer_outlined, size: 18, color: ErpColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.feedbackController,
          maxLines: 2,
          decoration: ErpDecorations.formInput(
            "Feedback / Notes",
            hint: "Any issues or observations...",
            prefix: const Icon(Icons.notes, size: 18, color: ErpColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Obx(
              () => SizedBox(
            width: double.infinity,
            child: ErpPrimaryButton(
              label: "Submit Production",
              icon: Icons.check_circle_outline,
              isLoading: controller.isSaving.value,
              onPressed: () {
                // BUG FIX: guard against empty/invalid input
                final text = controller.productionController.text.trim();
                if (text.isEmpty || int.tryParse(text) == null) {
                  Get.snackbar(
                    "Validation Error",
                    "Please enter a valid production amount",
                    backgroundColor: ErpColors.warningAmber,
                    colorText: Colors.white,
                  );
                  return;
                }
                controller.saveShift();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(ShiftDetailViewModel s) {
    return ErpSectionCard(
      title: "Shift Completed",
      icon: Icons.check_circle_outline,
      accentColor: ErpColors.successGreen,
      child: Column(
        children: [
          ErpInfoRow("Production", "${s.production} meters"),
          ErpInfoRow("Run Time", s.timer),
          if (s.feedback.isNotEmpty) ErpInfoRow("Feedback", s.feedback),
        ],
      ),
    );
  }
}