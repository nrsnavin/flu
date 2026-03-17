import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/packing_controller.dart';
import '../models/PackingModel.dart';
import 'PackingDetail.dart';


// ══════════════════════════════════════════════════════════════
//  PACKING LIST BY JOB PAGE
// ══════════════════════════════════════════════════════════════

class PackingListByJobPage extends StatefulWidget {
  const PackingListByJobPage({super.key});

  @override
  State<PackingListByJobPage> createState() => _PackingListByJobPageState();
}

class _PackingListByJobPageState extends State<PackingListByJobPage> {
  late final PackingListByJobController c;
  late final String jobId;
  late final int jobNo;
  String? customerName;

  @override
  void initState() {
    super.initState();
    // FIX: original passed jobId as Get.arguments (String) but was named
    // jobNo — confusing. Now we pass a Map with both fields.
    final args = Get.arguments as Map<String, dynamic>;
    jobId        = args['jobId'] as String;
    jobNo        = (args['jobNo'] as num).toInt();
    customerName = args['customer'] as String?;

    Get.delete<PackingListByJobController>(force: true);
    c = Get.put(PackingListByJobController(jobId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Column(children: [
        // Job summary header
        _JobHeader(jobNo: jobNo, customerName: customerName, c: c),
        // Packing list
        Expanded(child: _PackingList(c: c, jobNo: jobNo)),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Job #$jobNo', style: ErpTextStyles.pageTitle),
          const Text('Packing  ›  Job Detail',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      ),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetch,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Job header card ───────────────────────────────────────────
class _JobHeader extends StatelessWidget {
  final int jobNo;
  final String? customerName;
  final PackingListByJobController c;
  const _JobHeader(
      {required this.jobNo,
        required this.customerName,
        required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        // Icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: ErpColors.accentBlue.withOpacity(0.3)),
          ),
          child: const Icon(Icons.inventory_2_outlined,
              size: 20, color: ErpColors.accentBlue),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Job #$jobNo',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.textPrimary)),
                if (customerName != null)
                  Text(customerName!,
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11)),
              ]),
        ),
        // Stats
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${c.packings.length} boxes',
            style: const TextStyle(
                color: ErpColors.accentBlue,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
          Text(
            '${c.totalMeters.toStringAsFixed(0)} m total',
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 10),
          ),
        ]),
      ]),
    ));
  }
}

// ── Packing list ──────────────────────────────────────────────
class _PackingList extends StatelessWidget {
  final PackingListByJobController c;
  final int jobNo;
  const _PackingList({required this.c, required this.jobNo});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.errorMsg.value != null) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 34, color: ErpColors.textMuted),
            const SizedBox(height: 12),
            const Text('Failed to load',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
            const SizedBox(height: 4),
            Text(c.errorMsg.value!,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: c.fetch,
              style: ElevatedButton.styleFrom(
                  backgroundColor: ErpColors.accentBlue, elevation: 0),
              icon:
              const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      }
      if (c.packings.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 34, color: ErpColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text('No boxes for Job #$jobNo',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: ErpColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Add a packing record to get started',
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          ]),
        );
      }

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetch,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: c.packings.length,
          itemBuilder: (_, i) {
            final pack = c.packings[i];
            return _PackingCard(pack: pack, boxNo: i + 1);
          },
        ),
      );
    });
  }
}

// ── Packing card ──────────────────────────────────────────────
class _PackingCard extends StatelessWidget {
  final PackingListItem pack;
  final int boxNo;
  const _PackingCard({required this.pack, required this.boxNo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(
            () => const PackingDetailPage(),
        arguments: pack.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(children: [
            // Box number badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: ErpColors.statusApprovedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ErpColors.statusApprovedBorder),
              ),
              child: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('BOX',
                          style: TextStyle(
                              color: ErpColors.accentBlue,
                              fontSize: 7,
                              fontWeight: FontWeight.w800)),
                      Text('$boxNo',
                          style: const TextStyle(
                              color: ErpColors.accentBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                    ]),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.elasticName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(DateTime.parse(pack.date)),
                      style: const TextStyle(
                          color: ErpColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Micro(Icons.straighten_outlined,
                          '${pack.meters.toStringAsFixed(1)} m',
                          ErpColors.accentBlue),
                      const SizedBox(width: 10),
                      _Micro(Icons.link_outlined,
                          '${pack.joints} joints', ErpColors.textMuted),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ErpColors.textMuted, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _Micro extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Micro(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );
}