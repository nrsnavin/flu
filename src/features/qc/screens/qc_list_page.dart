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
        onRefresh: c.fetchRecent,
        child: Obx(() {
          if (c.isLoading.value && c.recent.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: ErpColors.accentBlue));
          }
          if (c.recent.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              Icon(Icons.verified_outlined, size: 48, color: ErpColors.textMuted),
              SizedBox(height: 12),
              Center(child: Text('No QC checks yet', style: TextStyle(color: ErpColors.textSecondary))),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: c.recent.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = c.recent[i];
              final pass = r.overallResult == 'pass';
              return Container(
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
                              style: const TextStyle(fontWeight: FontWeight.w600, color: ErpColors.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (r.aiAssisted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: ErpColors.statusOpenBg, borderRadius: BorderRadius.circular(4)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
                        style: const TextStyle(fontSize: 12, color: ErpColors.textMuted),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          );
        }),
      ),
    );
  }
}
