import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/complaint_controller.dart';
import '../models/complaint.dart';
import 'complaint_detail_page.dart';

// ══════════════════════════════════════════════════════════════
//  COMPLAINTS — THE LIST
//
//  Open ones first, because an open complaint is a customer waiting
//  and a closed one is a record. The category is on every row: shade
//  and strength send you to different people, and knowing which
//  before you open it is most of the triage.
// ══════════════════════════════════════════════════════════════

class ComplaintListPage extends StatefulWidget {
  const ComplaintListPage({super.key});

  @override
  State<ComplaintListPage> createState() => _ComplaintListPageState();
}

class _ComplaintListPageState extends State<ComplaintListPage> {
  late final ComplaintListController c;

  @override
  void initState() {
    super.initState();
    Get.delete<ComplaintListController>(force: true);
    c = Get.put(ComplaintListController());
  }

  @override
  void dispose() {
    Get.delete<ComplaintListController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Complaints'),
      ),
      body: Column(
        children: [
          Container(
            color: ErpColors.bgSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Obx(() => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in const <MapEntry<String?, String>>[
                        MapEntry(null, 'All'),
                        MapEntry('Open', 'Open'),
                        MapEntry('InReview', 'In review'),
                        MapEntry('Resolved', 'Resolved'),
                        MapEntry('Closed', 'Closed'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.value),
                            selected: c.status.value == f.key,
                            onSelected: (_) => c.setStatus(f.key),
                          ),
                        ),
                    ],
                  ),
                )),
          ),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value && c.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.errorMsg.value != null) {
                return _centered(c.errorMsg.value!, onRetry: c.fetch);
              }
              if (c.items.isEmpty) {
                return _centered('No complaints here.');
              }
              return RefreshIndicator(
                onRefresh: c.fetch,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: c.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Tile(complaint: c.items[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _centered(String text, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ErpColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.complaint});

  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Get.to(() => ComplaintDetailPage(complaintId: complaint.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: complaint.isOpen
                ? ErpColors.accentBlue.withValues(alpha: 0.35)
                : ErpColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint.customerName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ErpColors.textPrimary),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: complaint.isOpen
                        ? ErpColors.statusPartialBg
                        : ErpColors.bgBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(complaint.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: complaint.isOpen
                            ? ErpColors.accentBlue
                            : ErpColors.textMuted,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                complaint.category,
                if (complaint.elasticName != '—') complaint.elasticName,
                if (complaint.jobOrderNo != null) 'Job ${complaint.jobOrderNo}',
              ].join('  ·  '),
              style: TextStyle(
                  fontSize: 12, color: ErpColors.textSecondary),
            ),
            if (complaint.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                complaint.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: ErpColors.textPrimary),
              ),
            ],
            if (complaint.date != null) ...[
              const SizedBox(height: 6),
              Text(DateFormat('dd MMM yyyy').format(complaint.date!),
                  style: TextStyle(
                      fontSize: 11, color: ErpColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
