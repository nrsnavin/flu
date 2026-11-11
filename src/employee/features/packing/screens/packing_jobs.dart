import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/packing_entry_controller.dart';
import 'packing_entry_form.dart';

// ═════════════════════════════════════════════════════════════
//  PACKING JOBS PAGE — packing-ready jobs, tap to enter a batch.
// ═════════════════════════════════════════════════════════════
class PackingJobsPage extends StatefulWidget {
  const PackingJobsPage({super.key});
  @override
  State<PackingJobsPage> createState() => _PackingJobsPageState();
}

class _PackingJobsPageState extends State<PackingJobsPage> {
  late final EmpPackingEntryController c;

  @override
  void initState() {
    super.initState();
    Get.delete<EmpPackingEntryController>(force: true);
    c = Get.put(EmpPackingEntryController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Packing Entry', style: ErpTextStyles.pageTitle),
                Text('${c.jobs.length} jobs ready for packing',
                    style: const TextStyle(
                        color: ErpColors.textOnDarkSub, fontSize: 10)),
              ],
            )),
        actions: [
          Obx(() => IconButton(
                icon: c.isLoading.value
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                onPressed: c.isLoading.value ? null : c.fetchJobs,
              )),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value && c.jobs.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.jobs.isEmpty) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchJobs);
        }
        if (c.jobs.isEmpty) {
          return const _EmptyState();
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchJobs,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            itemCount: c.jobs.length,
            itemBuilder: (ctx, i) => _PackingJobCard(
              job: c.jobs[i],
              onTap: () => Get.to(
                () => PackingEntryFormPage(
                  job: c.jobs[i],
                  controller: c,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PackingJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  const _PackingJobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final jobOrderNo = SafeJson.asInt(job['jobOrderNo']);
    final cust  = SafeJson.asMap(job['customer']);
    final custName = SafeJson.asStringOrNull(cust['name']) ??
        SafeJson.asStringOrNull(job['customerName']) ??
        SafeJson.asStringOrNull(job['customer']);
    final status = SafeJson.asString(job['status'], '—');
    final order  = SafeJson.asMap(job['order']);
    final orderNo = SafeJson.asStringOrNull(order['orderNo']);
    final pending = SafeJson.asNum(job['pendingPackingQty']) ??
        SafeJson.asNum(job['pendingQty']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: ErpColors.successGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ErpColors.successGreen.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: ErpColors.successGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job #$jobOrderNo',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary)),
                  if (custName != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.business_outlined,
                          size: 11, color: ErpColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(custName,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    _Pill(label: status.toUpperCase(),
                        color: ErpColors.accentBlue),
                    if (orderNo != null) ...[
                      const SizedBox(width: 6),
                      Text('Order $orderNo',
                          style: const TextStyle(
                              color: ErpColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ]),
          ),
          if (pending != null && pending > 0)
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${pending.toInt()}',
                      style: const TextStyle(
                          color: ErpColors.warningAmber,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const Text('PENDING',
                      style: TextStyle(
                          color: ErpColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: ErpColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
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
            child: const Icon(Icons.inventory_2_outlined,
                size: 34, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Text('No jobs ready for packing',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
              'Once production finishes a job, it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12)),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined,
              size: 40, color: ErpColors.textMuted),
          const SizedBox(height: 12),
          const Text('Failed to load',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(msg,
              style: const TextStyle(
                  color: ErpColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: retry,
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue, elevation: 0),
            icon: const Icon(Icons.refresh,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
