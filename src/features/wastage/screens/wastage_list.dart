import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/wastage/screens/wastage_job.dart';
import 'package:production/src/features/wastage/screens/wastage_summary.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/add_wastage_controller.dart';
import '../models/checkingJobModel.dart';
import 'Add_Wastage.dart';


// ══════════════════════════════════════════════════════════════
//  WASTAGE LIST PAGE  — all jobs with wastage totals
// ══════════════════════════════════════════════════════════════

class WastageListPage extends StatefulWidget {
  const WastageListPage({super.key});

  @override
  State<WastageListPage> createState() => _WastageListPageState();
}

class _WastageListPageState extends State<WastageListPage> {
  late final WastageListController c;

  static const _statuses = [
    'All', 'weaving', 'finishing', 'checking', 'packing', 'completed',
  ];

  @override
  void initState() {
    super.initState();
    Get.delete<WastageListController>(force: true);
    c = Get.put(WastageListController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      floatingActionButton: _fab(),
      body: Column(children: [
        _StatusFilter(c: c, statuses: _statuses),
        _SummaryStrip(c: c),
        Expanded(child: _Body(c: c)),
      ]),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Get.back(),
    ),
    titleSpacing: 4,
    title: Obx(() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Wastage', style: ErpTextStyles.pageTitle),
        Text(
          '${c.jobs.length} jobs  ·  '
              '${c.totalWastage.toStringAsFixed(1)} m total',
          style: const TextStyle(
              color: ErpColors.textOnDarkSub, fontSize: 10),
        ),
      ],
    )),
    actions: [
      // Analytics button
      IconButton(
        icon: const Icon(Icons.bar_chart_rounded,
            color: Colors.white, size: 22),
        tooltip: 'Analytics',
        onPressed: () => Get.to(() => const WastageSummaryPage()),
      ),
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

  Widget _fab() => FloatingActionButton.extended(
    heroTag: 'addWastage',
    backgroundColor: ErpColors.errorRed,
    elevation: 2,
    icon: const Icon(Icons.warning_amber_rounded,
        color: Colors.white, size: 18),
    label: const Text('Record Wastage',
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13)),
    onPressed: () async {
      final res = await Get.to(() => const AddWastagePage());
      if (res == true) c.fetch();
    },
  );
}

// ── Status filter chips ────────────────────────────────────
class _StatusFilter extends StatelessWidget {
  final WastageListController c;
  final List<String> statuses;
  const _StatusFilter({required this.c, required this.statuses});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Obx(() => Row(
        children: statuses.map((s) {
          final active = s == 'All'
              ? c.statusFilter.value == null
              : c.statusFilter.value == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => c.statusFilter.value =
              s == 'All' ? null : s,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? _statusColor(s)
                      : ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? _statusColor(s)
                        : ErpColors.borderLight,
                  ),
                ),
                child: Text(
                  s == 'All' ? 'All Jobs' : _cap(s),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : ErpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      )),
    ),
  );

  Color _statusColor(String s) {
    switch (s) {
      case 'weaving':   return const Color(0xFF7C3AED);
      case 'finishing': return const Color(0xFF0891B2);
      case 'checking':  return ErpColors.warningAmber;
      case 'packing':   return ErpColors.successGreen;
      case 'completed': return ErpColors.textSecondary;
      default:          return ErpColors.accentBlue;
    }
  }

  String _cap(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

// ── Summary strip ──────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final WastageListController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(children: [
      _Pill('${c.jobs.length}', 'Jobs',
          ErpColors.accentBlue),
      const SizedBox(width: 8),
      _Pill('${c.totalWastage.toStringAsFixed(1)} m',
          'Total Wastage', ErpColors.errorRed),
      const SizedBox(width: 8),
      _Pill('${c.totalEntries}', 'Entries',
          ErpColors.warningAmber),
    ]),
  ));
}

class _Pill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Pill(this.value, this.label, this.color);
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
              color: color, fontSize: 12, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Main body ──────────────────────────────────────────────
class _Body extends StatelessWidget {
  final WastageListController c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value && c.jobs.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue));
    }
    if (c.errorMsg.value != null) {
      return _ErrorState(msg: c.errorMsg.value!, retry: c.fetch);
    }
    if (c.jobs.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      color: ErpColors.accentBlue,
      onRefresh: c.fetch,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
        itemCount: c.jobs.length,
        itemBuilder: (_, i) => _JobCard(job: c.jobs[i]),
      ),
    );
  });
}

// ── Job card ───────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final WastageJobSummary job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(job.status);
    return GestureDetector(
      onTap: () => Get.to(() => WastageJobPage(
        jobId: job.id,
        jobNo: job.jobOrderNo,
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border:
          Border.all(color: ErpColors.errorRed.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: ErpColors.navyDark.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          // Header band
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: ErpColors.navyDark.withOpacity(0.03),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: ErpColors.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: ErpColors.errorRed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Job #${job.jobOrderNo}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: ErpColors.textPrimary)),
                      if (job.customerName?.isNotEmpty ?? false)
                        Text(job.customerName!,
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _StatusPill(job.status, statusColor),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yy').format(job.date),
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 9),
                ),
              ]),
            ]),
          ),
          // Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(children: [
              _Stat('TOTAL WASTAGE',
                  '${job.totalWastage.toStringAsFixed(1)} m',
                  ErpColors.errorRed),
              _vDiv(),
              _Stat('ENTRIES', '${job.wastageCount}',
                  ErpColors.warningAmber),
              _vDiv(),
              _Stat(
                'LAST ENTRY',
                job.lastAdded != null
                    ? DateFormat('dd MMM').format(job.lastAdded!)
                    : '—',
                ErpColors.textSecondary,
              ),
            ]),
          ),
          // Elastic breakdown
          if (job.wastageElastic.isNotEmpty) ...[
            const Divider(height: 1, color: ErpColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: job.wastageElastic
                    .where((e) => e.quantity > 0)
                    .map((e) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.bgMuted,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ErpColors.borderLight),
                  ),
                  child: Text(
                    '${e.elasticName}: ${e.quantity.toStringAsFixed(1)}m',
                    style: const TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ))
                    .toList(),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('View Details',
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 14, color: ErpColors.accentBlue),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _vDiv() => Container(
      width: 1, height: 28, color: ErpColors.borderLight);

  Color _statusColor(String s) {
    switch (s) {
      case 'weaving':   return const Color(0xFF7C3AED);
      case 'finishing': return const Color(0xFF0891B2);
      case 'checking':  return ErpColors.warningAmber;
      case 'packing':   return ErpColors.successGreen;
      case 'completed': return ErpColors.textSecondary;
      default:          return ErpColors.accentBlue;
    }
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4),
          textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusPill(this.status, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      status[0].toUpperCase() + status.substring(1),
      style: TextStyle(
          color: color, fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

// ── State widgets ──────────────────────────────────────────
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
        child: const Icon(Icons.warning_amber_outlined,
            size: 34, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      const Text('No wastage recorded',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Tap + to record wastage for a job',
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