import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/Job/controllers/job_list_controller.dart';
import 'package:production/src/features/Job/models/JobListModel.dart';

import '../../PurchaseOrder/services/theme.dart';
import 'LiveDot.dart';
import 'job_detail.dart';

class JobListPage extends StatefulWidget {
  const JobListPage({super.key});

  @override
  State<JobListPage> createState() => _JobListPageState();
}

class _JobListPageState extends State<JobListPage> {
  late final JobListController _c;

  @override
  void initState() {
    super.initState();
    // FIX: Get.delete before Get.put — prevents stale instance
    Get.delete<JobListController>(force: true);
    _c = Get.put(JobListController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _SearchBar(c: _c),
          _StatusTabs(c: _c),
          Expanded(child: _JobList(c: _c)),
          // Footer loading indicator
          Obx(() => _c.isLoading.value && _c.jobs.isNotEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ErpColors.accentBlue),
              ),
            ),
          )
              : const SizedBox()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text("Job Orders", style: ErpTextStyles.pageTitle),
      actions: [
        Obx(() => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text("${_c.jobs.length} jobs",
                style: const TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 12)),
          ),
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final JobListController c;
  const _SearchBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          border:
          Border(bottom: BorderSide(color: ErpColors.borderLight))),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: c.searchController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14),
          onChanged: c.searchJob,
          decoration: InputDecoration(
            hintText: "Search by job number…",
            hintStyle:
            const TextStyle(color: ErpColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                size: 18, color: ErpColors.textMuted),
            filled: true,
            fillColor: ErpColors.bgMuted,
            contentPadding: EdgeInsets.zero,
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
              borderSide:
              const BorderSide(color: ErpColors.accentBlue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status tabs ────────────────────────────────────────────────
class _StatusTabs extends StatelessWidget {
  final JobListController c;
  const _StatusTabs({required this.c});

  static const _statuses = [
    "all",
    "preparatory",
    "weaving",
    "finishing",
    "checking",
    "packing",
    "completed",
  ];

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          border:
          Border(bottom: BorderSide(color: ErpColors.borderLight))),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statuses.map((s) {
            final selected = c.selectedStatus.value == s;
            final color = _stageColor(s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => c.changeStatus(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? color : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? color : color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    s == "all" ? "All" : _capitalize(s),
                    style: TextStyle(
                      color: selected ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      )),
    );
  }

  Color _stageColor(String status) {
    switch (status) {
      case "preparatory": return const Color(0xFF475569);
      case "weaving":     return const Color(0xFF1D6FEB);
      case "finishing":   return const Color(0xFFD97706);
      case "checking":    return const Color(0xFF7C3AED);
      case "packing":     return const Color(0xFF0891B2);
      case "completed":   return const Color(0xFF16A34A);
      default:            return const Color(0xFF64748B);
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Job list ───────────────────────────────────────────────────
class _JobList extends StatelessWidget {
  final JobListController c;
  const _JobList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value && c.jobs.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.jobs.isEmpty) {
        return _EmptyState(onRefresh: () => c.fetchJobs(reset: true));
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchJobs(reset: true),
        child: ListView.separated(
          controller: c.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: c.jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _JobCard(job: c.jobs[i]),
        ),
      );
    });
  }
}

// ── Job card ───────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final JobListModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(job.status);
    final isLive     = _isLive(job.status);

    return GestureDetector(
      // FIX: was onDoubleTap — single tap is standard UX
      onTap: () => Get.to(
            () => JobDetailPage(),
        arguments: job.id,
      ),
      child: Container(
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.work_outline,
                        size: 20, color: stageColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Job #${job.jobNo}",
                            style: ErpTextStyles.cardTitle),
                        const SizedBox(height: 2),
                        Text(job.customerName,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // Status badge with live dot
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isLive) ...[
                      LiveDot(color: stageColor),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stageColor.withOpacity(0.1),
                        border: Border.all(
                            color: stageColor.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _capitalize(job.status),
                        style: TextStyle(
                            color: stageColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
              decoration: const BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(
                    top: BorderSide(color: ErpColors.borderLight)),
              ),
              child: Row(children: [
                if (job.machineId != null) ...[
                  const Icon(Icons.precision_manufacturing_outlined,
                      size: 12, color: ErpColors.textMuted),
                  const SizedBox(width: 4),
                  Text("Machine ${job.machineId}",
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ] else
                  const Text("No machine assigned",
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    size: 16, color: ErpColors.textMuted),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Color _stageColor(String s) {
    switch (s) {
      case "weaving":     return const Color(0xFF1D6FEB);
      case "finishing":   return const Color(0xFFD97706);
      case "checking":    return const Color(0xFF7C3AED);
      case "packing":     return const Color(0xFF0891B2);
      case "completed":   return const Color(0xFF16A34A);
      default:            return const Color(0xFF475569);
    }
  }

  bool _isLive(String s) =>
      ["weaving", "finishing", "checking", "packing"].contains(s);

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.work_outline,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text("No Job Orders",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text("Jobs appear here once created from an Order",
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.refresh,
                size: 16, color: ErpColors.textSecondary),
            label: const Text("Refresh",
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}