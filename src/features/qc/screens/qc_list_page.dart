import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/qc_controller.dart';
import 'new_qc_page.dart';

class QcListPage extends StatelessWidget {
  const QcListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(QcController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Quality Control'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        foregroundColor: ErpColors.textOnDark,
        onPressed: () => Get.to(() => const NewQcPage()),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('New QC check'),
      ),
      body: RefreshIndicator(
        onRefresh: c.refreshAll,
        child: Obx(() {
          if (c.isLoading.value && c.recent.isEmpty && c.readiness.value == null) {
            return Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }
          final readiness = c.readiness.value;
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (readiness != null) ...[
                _DefectModelCard(r: readiness),
                const SizedBox(height: 14),
              ],
              Padding(
                padding: EdgeInsets.only(bottom: 8, left: 2),
                child: Text('Recent checks',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ErpColors.textSecondary)),
              ),
              if (c.recent.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No QC checks yet', style: TextStyle(color: ErpColors.textMuted)),
                  ),
                ),
              ...c.recent.map((r) {
                final pass = r.overallResult == 'pass';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ErpColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Row(children: [
                  Icon(pass ? Icons.check_circle : Icons.cancel,
                      color: pass ? ErpColors.successGreen : ErpColors.errorRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(r.elasticName.isEmpty ? '—' : r.elasticName,
                              style: TextStyle(fontWeight: FontWeight.w600, color: ErpColors.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (r.aiAssisted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: ErpColors.statusOpenBg, borderRadius: BorderRadius.circular(4)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.auto_awesome, size: 10, color: ErpColors.accentBlue),
                              SizedBox(width: 2),
                              Text('AI', style: TextStyle(fontSize: 10, color: ErpColors.accentBlue)),
                            ]),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        'J-${r.jobOrderNo}'
                        '${r.customerName.isNotEmpty ? ' · ${r.customerName}' : ''}'
                        '${r.defectCode.isNotEmpty ? ' · ${r.defectCode}' : ''}'
                        '${r.rejectedMeters > 0 ? ' · ${r.rejectedMeters} m rejected' : ''}',
                        style: TextStyle(fontSize: 12, color: ErpColors.textMuted),
                      ),
                    ]),
                  ),
                ]),
                );
              }),
            ],
          );
        }),
      ),
    );
  }
}

class _DefectModelCard extends StatelessWidget {
  final TrainingReadiness r;
  const _DefectModelCard({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.psychology_outlined, size: 18, color: ErpColors.accentBlue),
          const SizedBox(width: 8),
          Text('Defect model',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ErpColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: r.ready ? ErpColors.statusCompletedBg : ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.ready ? Icons.check_circle_outline : Icons.lock_outline,
                  size: 11, color: r.ready ? ErpColors.successGreen : ErpColors.textMuted),
              const SizedBox(width: 4),
              Text(r.ready ? 'Ready to train' : 'Collecting data',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: r.ready ? ErpColors.successGreen : ErpColors.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text(r.recommendation,
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary, height: 1.4)),
        const SizedBox(height: 12),
        // Progress toward the fine-tune threshold.
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${r.labelledImages} labelled photos',
              style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
          Text('${r.progressPct}% of ${r.minSamples} target',
              style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (r.progressPct / 100).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: ErpColors.bgMuted,
            valueColor: AlwaysStoppedAnimation<Color>(
                r.ready ? ErpColors.successGreen : ErpColors.accentBlue),
          ),
        ),
        if (r.classes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Label classes (${r.classesReady}/${r.minClasses} ready · ≥${r.minPerClass} each)',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 8),
          ...r.classes.take(6).map((cl) {
            final ok = cl.count >= r.minPerClass;
            final pct = (cl.count / (r.minPerClass == 0 ? 1 : r.minPerClass)).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 120,
                  child: Text(cl.defectCode,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: ErpColors.textPrimary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: ErpColors.bgMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          ok ? ErpColors.successGreen : ErpColors.warningAmber),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${cl.count}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ErpColors.textSecondary)),
              ]),
            );
          }),
        ],
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome, size: 12, color: ErpColors.accentBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${r.aiAssistedShare}% of these were AI-assisted then verified by an inspector — the corrections are the training signal.',
              style: TextStyle(fontSize: 11, color: ErpColors.textMuted, height: 1.4),
            ),
          ),
        ]),
      ]),
    );
  }
}
