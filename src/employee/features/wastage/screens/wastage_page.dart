import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../controllers/wastage_controller.dart';
import 'wastage_jobs.dart';

class WastagePage extends StatelessWidget {
  const WastagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmpWastageController(), tag: 'wastage');
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('Wastage Report', style: ErpTextStyles.pageTitle),
      ),
      // Always-visible CTA so any operator (or the checking dept tile,
      // which routes here) can jump into the entry flow. Mirrors the
      // admin app where Add Wastage and the report share one feature.
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.errorRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Record New Wastage',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () async {
          await Get.to(() => const WastageJobsPage());
          // Refresh in case a new entry was recorded.
          c.refresh();
        },
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _Error(msg: c.errorMsg.value!, onRetry: c.refresh);
        }
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
            children: [
              _SummaryCard(c: c),
              const SizedBox(height: 14),
              if (c.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No wastage recorded yet.',
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                ...c.items.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WastageCard(w: w),
                    )),
            ],
          ),
        );
      }),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final EmpWastageController c;
  const _SummaryCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Wastage', style: ErpTextStyles.kpiLabel),
                const SizedBox(height: 4),
                Text('${c.totalQuantity.toStringAsFixed(0)} m',
                    style: ErpTextStyles.kpiValue),
              ],
            ),
          ),
          Container(width: 1, height: 38, color: ErpColors.navyLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penalty', style: ErpTextStyles.kpiLabel),
                const SizedBox(height: 4),
                Text('₹ ${c.totalPenalty.toStringAsFixed(0)}',
                    style: ErpTextStyles.kpiValue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WastageCard extends StatelessWidget {
  final Map<String, dynamic> w;
  const _WastageCard({required this.w});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final dt  = SafeJson.asLocalDateTime(w['createdAt']);
    final when = dt == null ? '—' : fmt.format(dt);
    final elasticMap = SafeJson.asMap(w['elastic']);
    final jobMap     = SafeJson.asMap(w['job']);
    final elastic = SafeJson.asString(elasticMap['name'], '—');
    final job     = SafeJson.asString(jobMap['jobOrderNo']);
    final qty     = SafeJson.asDouble(w['quantity']);
    final penalty = SafeJson.asDouble(w['penalty']);
    final reason  = SafeJson.asString(w['reason']);

    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_sweep_outlined,
                  color: ErpColors.errorRed, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(elastic.toString(),
                      style: ErpTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Job #$job  ·  $when',
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${qty.toStringAsFixed(0)} m',
                    style: const TextStyle(
                        color: ErpColors.errorRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                if (penalty > 0)
                  Text('₹ ${penalty.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: ErpColors.warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ]),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Reason: $reason',
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _Error({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: ErpColors.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
