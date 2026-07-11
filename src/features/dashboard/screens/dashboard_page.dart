import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../ai_advisor/widgets/ai_suggestions_strip.dart';
import '../../ai_advisor/services/ai_advisor.dart';
import '../../announcement/screens/announcement_list.dart';
import '../../assistant/screens/assistant_chat_page.dart';
import '../../Orders/screens/delivery_risk_page.dart';
import '../../qc/screens/qc_list_page.dart';
import '../../feedback/screens/feedback_admin_list.dart';
import '../../Job/screens/job_list_screen.dart';
import '../../employees/screens/empList.dart';
import '../../materials/screens/material_list_screenn.dart';
import '../../shift/screens/pending_verification_page.dart';
import '../../elastic/screens/stock_map_page.dart';
import '../controllers/dashboard_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD
// ══════════════════════════════════════════════════════════════
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dashboard', style: ErpTextStyles.pageTitle),
            Text('Today at a glance',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: () => ctrl.fetch(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.attTotalEmployees.value == 0) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.attTotalEmployees.value == 0) {
          return _ErrorState(
            message: ctrl.errorMsg.value!,
            onRetry: ctrl.fetch,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ctrl.fetch(),
              AIAdvisor.instance.refreshNow(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              const AISuggestionsStrip(),
              const SizedBox(height: 14),
              _KpiGrid(ctrl: ctrl),
              const SizedBox(height: 12),
              _PendingShiftsBanner(ctrl: ctrl),
              const SizedBox(height: 18),
              _AttendanceCard(ctrl: ctrl),
              const SizedBox(height: 14),
              _LowStockCard(ctrl: ctrl),
              const SizedBox(height: 14),
              _QuickLinks(),
            ],
          ),
        );
      }),
    );
  }
}

// Full-width banner sitting between the 2x2 KPI grid and the
// attendance card. Keeps the existing grid layout intact and gives
// pending-verification its own visual presence.
class _PendingShiftsBanner extends StatelessWidget {
  final DashboardController ctrl;
  const _PendingShiftsBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final n = ctrl.pendingShifts.value;
      final highlight = n > 0;
      return Material(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => Get.to(() => const PendingVerificationPage())
              ?.then((_) => ctrl.fetch()),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: highlight
                    ? ErpColors.warningAmber.withOpacity(0.55)
                    : ErpColors.borderLight,
              ),
              borderRadius: BorderRadius.circular(8),
              color: highlight
                  ? ErpColors.warningAmber.withOpacity(0.08)
                  : ErpColors.bgSurface,
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: ErpColors.warningAmber.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: ErpColors.warningAmber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SHIFTS PENDING VERIFICATION',
                          style: TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('$n',
                            style: const TextStyle(
                                color: ErpColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        const SizedBox(width: 8),
                        Text(
                          highlight
                              ? 'submitted shifts waiting for admin sign-off'
                              : 'nothing to verify right now',
                          style: const TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 12),
                        ),
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: ErpColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _KpiGrid extends StatelessWidget {
  final DashboardController ctrl;
  const _KpiGrid({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Obx(() => _KpiTile(
                    label: 'OPEN JOBS',
                    value: ctrl.openJobs.value.toString(),
                    icon: Icons.work_outline,
                    color: ErpColors.accentBlue,
                    onTap: () => Get.to(() => JobListPage()),
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() => _KpiTile(
                    label: 'PENDING LEAVES',
                    value: ctrl.pendingLeaves.value.toString(),
                    icon: Icons.event_busy_outlined,
                    color: ErpColors.warningAmber,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Obx(() => _KpiTile(
                    label: 'ATTENDANCE TODAY',
                    value: '${ctrl.attPct.value}%',
                    sub:
                        '${ctrl.attTotalMarked.value}/${ctrl.attTotalEmployees.value} marked',
                    icon: Icons.fact_check_outlined,
                    color: ErpColors.successGreen,
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Obx(() => _KpiTile(
                    label: 'LOW STOCK',
                    value: ctrl.lowStockCount.value.toString(),
                    icon: Icons.inventory_2_outlined,
                    color: ErpColors.errorRed,
                    onTap: () => Get.to(() => RawMaterialListPage()),
                  )),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(Icons.chevron_right,
                        color: ErpColors.textMuted, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
              if (sub != null) ...[
                const SizedBox(height: 4),
                Text(sub!,
                    style: const TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final DashboardController ctrl;
  const _AttendanceCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Icon(Icons.people_alt_outlined,
                    size: 14, color: ErpColors.textSecondary),
                SizedBox(width: 6),
                Text('ATTENDANCE TODAY',
                    style: ErpTextStyles.sectionHeader),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Obx(() {
              final total = ctrl.attTotalMarked.value;
              if (total == 0 && ctrl.attTotalEmployees.value > 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'No attendance marked yet · ${ctrl.attTotalEmployees.value} employees',
                    style: const TextStyle(
                        color: ErpColors.textSecondary, fontSize: 12),
                  ),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AttPill('Present', ctrl.attPresent.value,
                      ErpColors.successGreen),
                  _AttPill('Late', ctrl.attLate.value,
                      ErpColors.warningAmber),
                  _AttPill('Half day', ctrl.attHalfDay.value,
                      ErpColors.accentBlue),
                  _AttPill('On leave', ctrl.attOnLeave.value,
                      const Color(0xFF7C3AED)),
                  _AttPill('Absent', ctrl.attAbsent.value,
                      ErpColors.errorRed),
                  _AttPill('Unmarked', ctrl.attUnmarked.value,
                      ErpColors.textMuted),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AttPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AttPill(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label · $count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final DashboardController ctrl;
  const _LowStockCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                const Text('LOW STOCK',
                    style: ErpTextStyles.sectionHeader),
                const Spacer(),
                TextButton(
                  onPressed: () => Get.to(() => RawMaterialListPage()),
                  child: const Text('View all',
                      style: TextStyle(
                          color: ErpColors.accentBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          Obx(() {
            if (ctrl.lowStockItems.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Nothing is below minimum stock',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 12)),
              );
            }
            // Cap the inline preview so a long list doesn't blow out
            // the dashboard. Full list lives on StockMapPage.
            final items = ctrl.lowStockItems;
            const previewCap = 8;
            final shown = items.take(previewCap).toList();
            final overflow = items.length - shown.length;
            return Column(
              children: [
                ...shown.map((m) => _LowStockRow(item: m)),
                if (overflow > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                    child: Text(
                      '+ $overflow more — open Stock Map for the full list',
                      style: const TextStyle(
                          color: ErpColors.textSecondary, fontSize: 11),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LowStockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name     = item['name']     as String? ?? '';
    final category = item['category'] as String? ?? '';
    final stock    = (item['stock']    as num?)?.toDouble() ?? 0;
    final minStock = (item['minStock'] as num?)?.toDouble() ?? 0;
    final ratio    = minStock > 0 ? (stock / minStock).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                '${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1)} / ${minStock.toStringAsFixed(minStock.truncateToDouble() == minStock ? 0 : 1)}',
                style: const TextStyle(
                    color: ErpColors.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(category,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 11)),
            ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: ErpColors.borderLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(ErpColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _LinkRow(
            icon: Icons.inventory_outlined,
            label: 'Elastic Stock',
            onTap: () => Get.to(() => const StockMapPage()),
          ),
          _LinkRow(
            icon: Icons.people_outline_rounded,
            label: 'Employees',
            onTap: () => Get.to(() => const EmployeeListPage()),
          ),
          _LinkRow(
            icon: Icons.feedback_outlined,
            label: 'Employee Feedback',
            onTap: () => Get.to(() => const FeedbackAdminListPage()),
          ),
          _LinkRow(
            icon: Icons.campaign_outlined,
            label: 'Notice Board',
            onTap: () => Get.to(() => const AnnouncementListPage()),
          ),
          _LinkRow(
            icon: Icons.local_shipping_outlined,
            label: 'Delivery Risk',
            onTap: () => Get.to(() => const DeliveryRiskPage()),
          ),
          _LinkRow(
            icon: Icons.verified_outlined,
            label: 'Quality Control',
            onTap: () => Get.to(() => const QcListPage()),
          ),
          _LinkRow(
            icon: Icons.smart_toy_outlined,
            label: 'Ask Jarvis',
            onTap: () => Get.to(() => const AssistantChatPage()),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : ErpColors.borderLight,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: ErpColors.accentBlue, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right,
                color: ErpColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: ErpColors.errorRed),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ErpPrimaryButton(
                label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
