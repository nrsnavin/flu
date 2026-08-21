import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/add_wastage_controller.dart';
import '../models/checkingJobModel.dart';
import 'Add_Wastage.dart';

// ══════════════════════════════════════════════════════════════
//  WASTAGE JOB PAGE  — all wastage records for one job
// ══════════════════════════════════════════════════════════════

class WastageJobPage extends StatefulWidget {
  final String jobId;
  final int    jobNo;
  const WastageJobPage({
    super.key,
    required this.jobId,
    required this.jobNo,
  });

  @override
  State<WastageJobPage> createState() => _WastageJobPageState();
}

class _WastageJobPageState extends State<WastageJobPage> {
  late final WastageJobController c;

  @override
  void initState() {
    super.initState();
    Get.delete<WastageJobController>(force: true);
    c = Get.put(WastageJobController(widget.jobId, widget.jobNo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      floatingActionButton: _fab(),
      body: Column(children: [
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
        Text('Job #${widget.jobNo}  Wastage',
            style: ErpTextStyles.pageTitle),
        Text(
          '${c.wastages.length} records  ·  '
              '${c.totalQty.toStringAsFixed(1)} m',
          style: TextStyle(
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
        onPressed: c.isLoading.value ? null : c.fetch,
      )),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );

  Widget _fab() => FloatingActionButton.extended(
    heroTag: 'addWastageJob',
    backgroundColor: ErpColors.errorRed,
    elevation: 2,
    icon: const Icon(Icons.add, color: Colors.white, size: 18),
    label: const Text('Add Wastage',
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

class _SummaryStrip extends StatelessWidget {
  final WastageJobController c;
  const _SummaryStrip({required this.c});
  @override
  Widget build(BuildContext context) => Obx(() => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    child: Row(children: [
      _Pill('${c.wastages.length}', 'Records', ErpColors.accentBlue),
      const SizedBox(width: 8),
      _Pill('${c.totalQty.toStringAsFixed(1)} m', 'Wastage',
          ErpColors.errorRed),
      const SizedBox(width: 8),
      _Pill('₹${c.totalPenalty.toStringAsFixed(0)}', 'Penalty',
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
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _Body extends StatelessWidget {
  final WastageJobController c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.isLoading.value && c.wastages.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue));
    }
    if (c.errorMsg.value != null) {
      return _ErrorState(msg: c.errorMsg.value!, retry: c.fetch);
    }
    if (c.wastages.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      color: ErpColors.accentBlue,
      onRefresh: c.fetch,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
        itemCount: c.wastages.length,
        itemBuilder: (_, i) => _WastageCard(
          record: c.wastages[i],
          index:  i,
          c:      c,
        ),
      ),
    );
  });
}

class _WastageCard extends StatelessWidget {
  final WastageRecord record;
  final int index;
  final WastageJobController c;
  const _WastageCard({
    required this.record,
    required this.index,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context, record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
                color: ErpColors.navyDark.withValues(alpha: 0.04),
                blurRadius: 5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: ErpColors.errorRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(record.elasticName,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ErpColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ErpColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${record.quantity.toStringAsFixed(1)} m',
                          style: TextStyle(
                              color: ErpColors.errorRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.person_outline,
                          size: 11, color: ErpColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(record.employeeName,
                            style: TextStyle(
                                color: ErpColors.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.calendar_today_outlined,
                          size: 11, color: ErpColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(record.createdAt),
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 10),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      record.reason,
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (record.penalty > 0) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.monetization_on_outlined,
                            size: 11, color: ErpColors.warningAmber),
                        const SizedBox(width: 3),
                        Text('Penalty: ₹${record.penalty.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: ErpColors.warningAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ],
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: ErpColors.textMuted),
          ]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext ctx, WastageRecord r) {
    Get.bottomSheet(
      _WastageDetailSheet(record: r, c: c),
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WASTAGE DETAIL BOTTOM SHEET
//
//  P2-1: now carries a Delete action (admin-only undo). Confirms
//  with a small dialog before calling the controller's removeOne.
//  Closes the sheet on success.
// ══════════════════════════════════════════════════════════════

class _WastageDetailSheet extends StatelessWidget {
  final WastageRecord record;
  final WastageJobController c;
  const _WastageDetailSheet({required this.record, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: ErpColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: ErpColors.errorRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      size: 22, color: ErpColors.errorRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wastage Detail',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ErpColors.textPrimary)),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(record.createdAt),
                          style: TextStyle(
                              color: ErpColors.textMuted, fontSize: 10),
                        ),
                      ]),
                ),
                GestureDetector(
                  onTap: Get.back,
                  child: Icon(Icons.close_rounded,
                      color: ErpColors.textMuted, size: 20),
                ),
              ]),
              const SizedBox(height: 20),
              Divider(color: ErpColors.borderLight),
              const SizedBox(height: 12),

              _Row(icon: Icons.grid_on_rounded,
                  label: 'Elastic', value: record.elasticName),
              _Row(icon: Icons.person_outline_rounded,
                  label: 'Employee',
                  value: '${record.employeeName}'
                      '${record.employeeDept != null ? "  ·  ${record.employeeDept!}" : ""}'),
              _Row(icon: Icons.straighten_rounded,
                  label: 'Quantity',
                  value: '${record.quantity.toStringAsFixed(1)} m',
                  valueColor: ErpColors.errorRed),
              _Row(icon: Icons.monetization_on_outlined,
                  label: 'Penalty',
                  value: record.penalty > 0
                      ? '₹${record.penalty.toStringAsFixed(2)}'
                      : 'None',
                  valueColor: record.penalty > 0
                      ? ErpColors.warningAmber
                      : ErpColors.successGreen),
              _Row(icon: Icons.work_outline_rounded,
                  label: 'Job',
                  value: record.jobNo != null
                      ? 'Job #${record.jobNo}${record.jobStatus != null ? "  (${record.jobStatus!})" : ""}'
                      : '—'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ErpColors.borderLight),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REASON',
                          style: TextStyle(
                              color: ErpColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 4),
                      Text(record.reason,
                          style: TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              const SizedBox(height: 16),

              // ── Admin delete action ───────────────────────
              Obx(() => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: c.deleting.value
                      ? null
                      : () => _confirmDelete(context, record, c),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ErpColors.errorRed,
                    side: BorderSide(
                        color: ErpColors.errorRed.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: c.deleting.value
                      ? SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: ErpColors.errorRed,
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    c.deleting.value ? 'Deleting…' : 'Delete this entry',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'Removes the wastage record and rolls back the per-job counter. Stock is unaffected for new entries.',
                style: TextStyle(
                    color: ErpColors.textMuted, fontSize: 10),
              ),
            ]),
      ),
    );
  }

  void _confirmDelete(
    BuildContext ctx,
    WastageRecord r,
    WastageJobController c,
  ) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('Delete wastage?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Removes the ${r.quantity.toStringAsFixed(1)} m wastage entry by ${r.employeeName} and rolls back the per-job counter.',
                style: TextStyle(color: ErpColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Why is this being deleted? (recorded in the audit log)',
                  hintStyle: TextStyle(fontSize: 11, color: ErpColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ErpColors.errorRed, elevation: 0),
              onPressed: reasonCtrl.text.trim().length < 3
                  ? null
                  : () async {
                      final reason = reasonCtrl.text.trim();
                      Navigator.of(dctx).pop();
                      final ok = await c.removeOne(r.id, reason);
                      if (ok && Get.isBottomSheetOpen == true) {
                        Get.back(); // close the detail sheet
                      }
                    },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, size: 14, color: ErpColors.textMuted),
      const SizedBox(width: 8),
      SizedBox(
        width: 80,
        child: Text(label,
            style: TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(
                color: valueColor ?? ErpColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline_rounded,
          size: 44, color: ErpColors.successGreen),
      SizedBox(height: 12),
      Text('No wastage recorded for this job',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: ErpColors.textPrimary)),
      SizedBox(height: 4),
      Text('Tap + to add a wastage entry',
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
      Icon(Icons.error_outline,
          size: 40, color: ErpColors.textMuted),
      const SizedBox(height: 12),
      Text('Failed to load',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      Text(msg,
          style: TextStyle(
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
