import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/packing_controller.dart';
import '../models/PackingModel.dart';

import 'AddPacking.dart';
import 'PackingListByJob.dart';


// ══════════════════════════════════════════════════════════════
//  PACKING OVERVIEW PAGE  — grouped by job
// ══════════════════════════════════════════════════════════════

class PackingOverviewPage extends StatefulWidget {
  const PackingOverviewPage({super.key});

  @override
  State<PackingOverviewPage> createState() => _PackingOverviewPageState();
}

class _PackingOverviewPageState extends State<PackingOverviewPage> {
  late final PackingOverviewController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.delete<PackingOverviewController>(force: true);
    c = Get.put(PackingOverviewController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Column(children: [
        // Search
        _SearchBar(ctrl: _searchCtrl, c: c),
        // Summary strip
        _SummaryStrip(c: c),
        // Job list
        Expanded(child: _JobList(c: c)),
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
      title: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Packing', style: ErpTextStyles.pageTitle),
          Text(
            '${c.jobs.length} jobs  •  ${c.totalBoxes} boxes',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10),
          ),
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
          onPressed: c.isLoading.value ? null : c.fetchGrouped,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'addPacking',
      backgroundColor: ErpColors.accentBlue,
      elevation: 2,
      icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
      label: const Text('Add Packing',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      onPressed: () async {
        final result = await Get.to(() => const AddPackingPage());
        if (result == true) c.fetchGrouped();
      },
    );
  }
}

// ── Search bar ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final PackingOverviewController c;
  const _SearchBar({required this.ctrl, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        onChanged: c.setSearch,
        style: ErpTextStyles.fieldValue,
        decoration: InputDecoration(
          filled: true,
          fillColor: ErpColors.bgMuted,
          hintText: 'Search by job number or customer…',
          hintStyle: const TextStyle(
              color: ErpColors.textMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded,
              color: ErpColors.textMuted, size: 17),
          suffixIcon: Obx(() => c.searchQuery.value.isNotEmpty
              ? GestureDetector(
            onTap: () {
              ctrl.clear();
              c.setSearch('');
            },
            child: const Icon(Icons.close_rounded,
                size: 16, color: ErpColors.textMuted),
          )
              : const SizedBox.shrink()),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: ErpColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: ErpColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(
                color: ErpColors.accentBlue, width: 1.5),
          ),
        ),
      ),
    ),
  );
}

// ── Summary strip ────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final PackingOverviewController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    child: Row(children: [
      _Badge(c.jobs.length, 'Jobs', ErpColors.accentBlue),
      const SizedBox(width: 8),
      _Badge(c.totalBoxes, 'Boxes', ErpColors.successGreen),
      const SizedBox(width: 8),
      _MetricBadge(
          '${c.totalMeters.toStringAsFixed(0)} m',
          'Total Meters',
          ErpColors.warningAmber),
    ]),
  ));
}

class _Badge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Badge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$value',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _MetricBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MetricBadge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Job list ─────────────────────────────────────────────────
class _JobList extends StatelessWidget {
  final PackingOverviewController c;
  const _JobList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.errorMsg.value != null) {
        return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchGrouped);
      }
      final list = c.filtered;
      if (list.isEmpty) {
        return _EmptyState(hasSearch: c.searchQuery.value.isNotEmpty);
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetchGrouped,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: list.length,
          itemBuilder: (_, i) => _JobCard(job: list[i]),
        ),
      );
    });
  }
}

// ── Job card ─────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final PackingJobSummary job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(
            () => const PackingListByJobPage(),
        arguments: {
          'jobId':  job.jobId,
          'jobNo':  job.jobNo,
          'customer': job.customerName,
        },
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            // Icon
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ErpColors.accentBlue.withOpacity(0.3)),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 22, color: ErpColors.accentBlue),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Job #${job.jobNo}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ErpColors.statusInProgressBg,
                          border: Border.all(
                              color: ErpColors.statusInProgressBorder),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PACKING',
                            style: TextStyle(
                                color: ErpColors.statusInProgressText,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    if (job.customerName != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.business_outlined,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 3),
                        Text(job.customerName!,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ],
                    const SizedBox(height: 5),
                    Row(children: [
                      _InfoChip(Icons.inventory_outlined,
                          '${job.totalBoxes} boxes'),
                      const SizedBox(width: 10),
                      _InfoChip(Icons.straighten_outlined,
                          '${job.totalMeters.toStringAsFixed(0)} m'),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: ErpColors.textMuted),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );
}

// ── Empty + Error states ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});
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
      Text(
        hasSearch ? 'No Matching Jobs' : 'No Packing Records',
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: ErpColors.textPrimary),
      ),
      const SizedBox(height: 4),
      Text(
        hasSearch
            ? 'Try a different search term'
            : 'Jobs in packing status will appear here',
        style: const TextStyle(
            color: ErpColors.textSecondary, fontSize: 12),
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
      const Icon(Icons.error_outline, size: 40, color: ErpColors.textMuted),
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
        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
        label: const Text('Retry',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}