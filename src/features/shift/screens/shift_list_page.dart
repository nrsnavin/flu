import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/shift/screens/shift_detail.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/shift_list_controller.dart';

class ShiftListPage extends StatelessWidget {
  final controller = Get.put(ShiftControllerView());

  ShiftListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: "Open Shifts",
        subtitle: "Pending production entry",
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ErpColors.textOnDark, size: 20),
            onPressed: controller.fetchOpenShifts,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        if (controller.shifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: ErpColors.successGreen),
                const SizedBox(height: 12),
                const Text(
                  "No open shifts",
                  style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "All shifts have been completed",
                  style: TextStyle(color: ErpColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: controller.shifts.length,
          itemBuilder: (_, index) {
            final shift = controller.shifts[index];

            return GestureDetector(
              onTap: () => Get.to(() => ShiftDetailPage(shiftId: shift.id)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: ErpColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: ErpColors.navyDark.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: const BoxDecoration(
                        color: ErpColors.bgMuted,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                        border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
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
                              shift.machineName.isNotEmpty ? shift.machineName : "—",
                              style: const TextStyle(
                                color: ErpColors.textOnDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Job #${shift.jobNo.isNotEmpty ? shift.jobNo : '—'}",
                              style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Shift badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: shift.shift.toLowerCase().contains('night')
                                  ? ErpColors.statusOpenBg
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: shift.shift.toLowerCase().contains('night')
                                    ? ErpColors.statusOpenBorder
                                    : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  shift.shift.toLowerCase().contains('night')
                                      ? Icons.nightlight_outlined
                                      : Icons.wb_sunny_outlined,
                                  size: 10,
                                  color: shift.shift.toLowerCase().contains('night')
                                      ? ErpColors.statusOpenText
                                      : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shift.shift.toUpperCase(),
                                  style: TextStyle(
                                    color: shift.shift.toLowerCase().contains('night')
                                        ? ErpColors.statusOpenText
                                        : const Color(0xFFD97706),
                                    fontSize: 9,
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

                    // Details row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 13, color: ErpColors.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              shift.operatorName.isNotEmpty ? shift.operatorName : "—",
                              style: const TextStyle(
                                color: ErpColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.calendar_today_outlined, size: 11, color: ErpColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('dd MMM').format(shift.date),
                            style: const TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_ios, size: 12, color: ErpColors.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}