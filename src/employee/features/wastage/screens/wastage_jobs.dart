import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/wastage_entry_controller.dart';
import 'wastage_entry_form.dart';

// ═════════════════════════════════════════════════════════════
//  WASTAGE JOBS PAGE — jobs in weaving/finishing/checking. Tap a job
//  to open the entry form. Mirrors the packing-jobs flow so the
//  checking operator's UX matches what packing operators already see.
// ═════════════════════════════════════════════════════════════
class WastageJobsPage extends StatefulWidget {
  const WastageJobsPage({super.key});
  @override
  State<WastageJobsPage> createState() => _WastageJobsPageState();
}

class _WastageJobsPageState extends State<WastageJobsPage> {
  late final EmpWastageEntryController c;

  @override
  void initState() {
    super.initState();
    Get.delete<EmpWastageEntryController>(force: true);
    c = Get.put(EmpWastageEntryController());
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
                const Text('Wastage Entry', style: ErpTextStyles.pageTitle),
                Text('${c.jobs.length} jobs eligible',
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
            itemBuilder: (ctx, i) => _WastageJobCard(
              job: c.jobs[i],
              onTap: () => Get.to(
                () => WastageEntryFormPage(
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

class _WastageJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  const _WastageJobCard({required this.job, required this.onTap});

  Color _statusColor(String status) {
    switch (status) {
      case 'weaving':   return const Color(0xFF7C3AED);
      case 'finishing': return const Color(0xFF0891B2);
      case 'checking':  return ErpColors.warningAmber;
      default:          return ErpColors.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobOrderNo = SafeJson.asInt(job['jobOrderNo']);
    final cust       = SafeJson.asMap(job['customer']);
    final custName   = SafeJson.asStringOrNull(cust['name']) ??
        SafeJson.asStringOrNull(job['customer']);
    final status     = SafeJson.asString(job['status'], '—');
    final elastics   = SafeJson.asMapList(job['elastics']);
    final color      = _statusColor(status);

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
              color: ErpColors.errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ErpColors.errorRed.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.delete_sweep_outlined,
                color: ErpColors.errorRed, size: 22),
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
                    _Pill(label: status.toUpperCase(), color: color),
                    const SizedBox(width: 6),
                    Text('${elastics.length} elastic${elastics.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ]),
          ),
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
            child: const Icon(Icons.delete_sweep_outlined,
                size: 34, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 14),
          const Text('No jobs eligible for wastage entry',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
                'Wastage can be recorded while a job is in weaving, finishing or checking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ),
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
