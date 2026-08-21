import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_stock_controller.dart';

// ═════════════════════════════════════════════════════════════
//  ElasticStockPage — single elastic stock view
//
//  P2-3 manual adjust upgrade (reason min length, preview,
//       magnitude warning + force-retry confirm),
//  P2-4 tappable movement rows → detail bottom sheet,
//  P2-5 timeline filters (date range / type / ref search),
//  P2-6 CSV export to clipboard.
// ═════════════════════════════════════════════════════════════
class ElasticStockPage extends StatefulWidget {
  final String elasticId;
  final String? elasticName;
  final double? initialAdjustDelta;
  final String? initialAdjustReason;
  const ElasticStockPage({
    super.key,
    required this.elasticId,
    this.elasticName,
    this.initialAdjustDelta,
    this.initialAdjustReason,
  });

  @override
  State<ElasticStockPage> createState() => _ElasticStockPageState();
}

class _ElasticStockPageState extends State<ElasticStockPage> {
  late final ElasticStockController c;

  // ── P2-5 timeline filter state ────────────────────────────
  String _typeFilter = 'all';
  int    _dayRange   = 0; // 0 = all, otherwise rolling N days
  final  _refSearchCtrl = TextEditingController();

  static const _typeGroups = {
    'packing':     ['PACKING_INWARD', 'PACKING_REVERSE'],
    'dc':          ['DC_OUT', 'DC_CANCEL_RETURN'],
    'wastage':     ['WASTAGE_OUT', 'WASTAGE_RETURN'],
    'manual':      ['MANUAL_ADJUST'],
    'reservation': ['RESERVATION_HOLD', 'RESERVATION_RELEASE'],
  };

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> src) {
    DateTime? cutoff;
    if (_dayRange > 0) {
      cutoff = DateTime.now().subtract(Duration(days: _dayRange));
    }
    final search = _refSearchCtrl.text.trim().toLowerCase();
    return src.where((m) {
      if (cutoff != null) {
        final d = DateTime.tryParse(m['date']?.toString() ?? '');
        if (d == null || d.isBefore(cutoff)) return false;
      }
      if (_typeFilter != 'all') {
        final t = m['type']?.toString() ?? '';
        if (!(_typeGroups[_typeFilter] ?? const []).contains(t)) return false;
      }
      if (search.isNotEmpty) {
        final refId   = (m['refId']   ?? '').toString().toLowerCase();
        final refType = (m['refType'] ?? '').toString().toLowerCase();
        final reason  = (m['reason']  ?? '').toString().toLowerCase();
        if (!refId.contains(search) &&
            !refType.contains(search) &&
            !reason.contains(search)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final tag = 'stock-${widget.elasticId}';
    Get.delete<ElasticStockController>(tag: tag, force: true);
    c = Get.put(ElasticStockController(), tag: tag);
    c.fetchStock(widget.elasticId);
    _refSearchCtrl.addListener(() => setState(() {}));

    final d = widget.initialAdjustDelta;
    final r = widget.initialAdjustReason;
    if (d != null && d != 0 && r != null && r.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAdjustDialog(context, prefillDelta: d, prefillReason: r);
      });
    }
  }

  @override
  void dispose() {
    _refSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.elasticName ?? 'Elastic Stock',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text('Stock ledger',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined,
                color: Colors.white),
            onPressed: () => _exportCsv(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (v) {
              if (v == 'min_stock') _openMinStockDialog(context);
              if (v == 'refresh')   c.fetchStock(widget.elasticId);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'min_stock', child: Text('Set min stock')),
              PopupMenuItem(value: 'refresh',   child: Text('Refresh')),
            ],
          ),
        ],
      ),
      floatingActionButton: Obx(() => FloatingActionButton.extended(
            backgroundColor: ErpColors.accentBlue,
            icon: c.adjusting.value
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.tune_rounded, color: Colors.white),
            label: const Text('Adjust',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
            onPressed: c.adjusting.value
                ? null
                : () => _openAdjustDialog(context),
          )),
      body: Obx(() {
        if (c.loading.value && c.movements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.errorMsg.value != null && c.movements.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: ErpColors.errorRed, size: 36),
                  const SizedBox(height: 10),
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  ErpPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: () => c.fetchStock(widget.elasticId),
                  ),
                ],
              ),
            ),
          );
        }
        final filtered = _applyFilters(c.movements);
        return RefreshIndicator(
          onRefresh: () => c.fetchStock(widget.elasticId),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              _OnHandHero(c: c),
              const SizedBox(height: 14),
              ErpSectionCard(
                title: 'MOVEMENT TIMELINE',
                icon: Icons.history_rounded,
                trailing: Text(
                  '${filtered.length}/${c.movements.length}',
                  style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
                child: Column(
                  children: [
                    _TimelineFilters(
                      typeFilter:  _typeFilter,
                      dayRange:    _dayRange,
                      searchCtrl:  _refSearchCtrl,
                      onTypeChanged: (v) => setState(() => _typeFilter = v),
                      onRangeChanged: (v) => setState(() => _dayRange = v),
                      onClear: () => setState(() {
                        _typeFilter = 'all';
                        _dayRange = 0;
                        _refSearchCtrl.clear();
                      }),
                    ),
                    Divider(
                      height: 1, color: ErpColors.borderLight),
                    if (filtered.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                            'No movements match the current filters',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12)),
                      )
                    else
                      Column(
                        children: List.generate(filtered.length, (i) {
                          final m = filtered[i];
                          return _MovementRow(
                            mv: m,
                            isLast: i == filtered.length - 1,
                            onTap: () => _openMovementSheet(context, m),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── P2-6 CSV export ───────────────────────────────────────
  String _escape(String s) =>
      s.contains(',') || s.contains('"') || s.contains('\n')
          ? '"${s.replaceAll('"', '""')}"'
          : s;

  String _buildCsv(List<Map<String, dynamic>> rows) {
    final out = StringBuffer();
    out.writeln('Date,Type,Requested,Applied,Balance,RefType,RefId,Reason,By');
    for (final m in rows) {
      final date = m['date']?.toString() ?? '';
      final type = m['type']?.toString() ?? '';
      final req  = (m['requested'] as num?)?.toString()
          ?? (m['quantity'] as num?)?.toString() ?? '';
      final app  = (m['applied'] as num?)?.toString()
          ?? (m['quantity'] as num?)?.toString() ?? '';
      final bal  = (m['balance'] as num?)?.toString() ?? '';
      final rt   = m['refType']?.toString() ?? '';
      final ri   = m['refId']?.toString()   ?? '';
      final rsn  = (m['reason']?.toString() ?? '').replaceAll('\n', ' ');
      final by   = m['by']?.toString()      ?? '';
      out.writeln([date, type, req, app, bal, rt, ri, rsn, by]
          .map(_escape).join(','));
    }
    return out.toString();
  }

  Future<void> _exportCsv(BuildContext ctx) async {
    final filtered = _applyFilters(c.movements);
    final csv = _buildCsv(filtered);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    Get.snackbar(
      'CSV Copied',
      '${filtered.length} row(s) copied to clipboard — paste into a spreadsheet',
      backgroundColor: const Color(0xFF16A34A),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  // ── P2-4 movement detail sheet ────────────────────────────
  void _openMovementSheet(BuildContext ctx, Map<String, dynamic> mv) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _MovementDetailSheet(mv: mv),
    );
  }

  void _openMinStockDialog(BuildContext ctx) {
    final ctrl = TextEditingController(
      text: c.minStock.value > 0 ? c.minStock.value.toStringAsFixed(0) : '',
    );
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        title: Text('Set Min Stock',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When on-hand stock falls at or below this value the elastic is flagged as LOW. Set to 0 to disable.',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              decoration: ErpDecorations.formInput('Threshold (m)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              elevation: 0,
            ),
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v < 0) {
                Get.snackbar('Validation', 'Enter a non-negative number',
                    backgroundColor: ErpColors.errorRed,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              final ok = await c.setMinStock(widget.elasticId, v);
              if (ok) Navigator.of(ctx).pop();
            },
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── P2-3 manual adjust upgrade ────────────────────────────
  void _openAdjustDialog(
    BuildContext ctx, {
    double? prefillDelta,
    String? prefillReason,
  }) {
    final hasPrefill = prefillDelta != null && prefillDelta != 0;
    final qtyCtrl = TextEditingController(
      text: hasPrefill ? prefillDelta!.abs().toStringAsFixed(0) : '',
    );
    final reasonCtrl = TextEditingController(text: prefillReason ?? '');
    bool isAdd = hasPrefill ? (prefillDelta! > 0) : true;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (_, setSheetState) {
        // Listen to controllers so the preview + counters refresh live.
        void rebuild() => setSheetState(() {});
        qtyCtrl.removeListener(rebuild);
        qtyCtrl.addListener(rebuild);
        reasonCtrl.removeListener(rebuild);
        reasonCtrl.addListener(rebuild);

        final qtyNum   = double.tryParse(qtyCtrl.text.trim()) ?? 0;
        final delta    = isAdd ? qtyNum : -qtyNum;
        final currentStock = c.stock.value;
        final newBalance   = (currentStock + delta).clamp(0.0, double.infinity);
        final reasonLen    = reasonCtrl.text.trim().length;
        final reasonValid  = reasonLen >= 8;
        final magnitudeRisky = qtyNum > 0 &&
            (qtyNum > 100 || qtyNum > currentStock * 0.2);

        return AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          title: Text(
              hasPrefill ? 'Reconcile Adjust' : 'Manual Stock Adjust',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPrefill)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withValues(alpha: 0.08),
                      border: Border.all(
                          color: ErpColors.accentBlue.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Icon(Icons.fact_check_outlined,
                          color: ErpColors.accentBlue, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pre-filled from reconcile drift. Confirm and apply.',
                          style: TextStyle(
                              color: ErpColors.accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => isAdd = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isAdd
                                ? ErpColors.successGreen.withValues(alpha: 0.18)
                                : ErpColors.bgMuted,
                            border: Border.all(
                                color: isAdd
                                    ? ErpColors.successGreen
                                    : ErpColors.borderLight),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('+ ADD',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: ErpColors.successGreen)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => isAdd = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isAdd
                                ? ErpColors.errorRed.withValues(alpha: 0.18)
                                : ErpColors.bgMuted,
                            border: Border.all(
                                color: !isAdd
                                    ? ErpColors.errorRed
                                    : ErpColors.borderLight),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('− REMOVE',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: ErpColors.errorRed)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: ErpDecorations.formInput('Quantity *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: ErpDecorations.formInput(
                    'Reason *',
                    hint: 'Min 8 characters',
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    reasonValid
                        ? '$reasonLen chars'
                        : '$reasonLen / 8 chars',
                    style: TextStyle(
                      color: reasonValid
                          ? ErpColors.successGreen
                          : ErpColors.errorRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (qtyNum > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ErpColors.borderLight),
                    ),
                    child: Row(children: [
                      Icon(Icons.preview_outlined,
                          size: 14, color: ErpColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Stock will go from ${_fmtNum(currentStock)} → ${_fmtNum(newBalance)} m',
                          style: TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (magnitudeRisky) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ErpColors.warningAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: ErpColors.warningAmber.withValues(alpha: 0.6)),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: ErpColors.warningAmber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Large adjust — ${_fmtNum(qtyNum)} m is over 20% of on-hand or > 100 m. A second confirm will be required.',
                          style: TextStyle(
                              color: ErpColors.warningAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                elevation: 0,
              ),
              onPressed: () async {
                if (qtyNum <= 0) {
                  Get.snackbar('Validation', 'Enter a valid quantity',
                      backgroundColor: ErpColors.errorRed,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                if (!reasonValid) {
                  Get.snackbar('Validation',
                      'Reason must be at least 8 characters',
                      backgroundColor: ErpColors.errorRed,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }

                // First confirm for big adjusts (P2-3): show the
                // before → after balance prominently before posting.
                if (magnitudeRisky) {
                  final ok = await _confirmBigAdjust(
                    ctx,
                    qty: qtyNum,
                    isAdd: isAdd,
                    before: currentStock,
                    after: newBalance,
                  );
                  if (ok != true) return;
                }

                await _submitAdjust(
                  qty: qtyNum,
                  isAdd: isAdd,
                  reason: reasonCtrl.text.trim(),
                  dialogContext: ctx,
                );
              },
              child: const Text('Apply',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
  }

  Future<bool?> _confirmBigAdjust(
    BuildContext ctx, {
    required double qty,
    required bool isAdd,
    required double before,
    required double after,
  }) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        title: Text('Confirm large adjust',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are ${isAdd ? 'adding' : 'removing'} '
              '${_fmtNum(qty)} m (${(qty / (before == 0 ? qty : before) * 100).toStringAsFixed(0)}% of on-hand).',
              style: TextStyle(
                  color: ErpColors.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Balance: ${_fmtNum(before)} → ${_fmtNum(after)} m',
              style: TextStyle(
                  color: ErpColors.warningAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.errorRed,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apply anyway',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAdjust({
    required double qty,
    required bool isAdd,
    required String reason,
    required BuildContext dialogContext,
  }) async {
    final delta = isAdd ? qty : -qty;
    var res = await c.adjust(
      elasticId: widget.elasticId,
      delta:     delta,
      reason:    reason,
    );

    // Backend percentage cap rejected — offer one more confirm with
    // force:true. We already required the magnitudeRisky local
    // confirm, so this is a second-tier safety net for cases where
    // our threshold heuristic is more permissive than the backend.
    if (!res.ok && res.magnitudeCap) {
      final retry = await showDialog<bool>(
        context: dialogContext,
        builder: (_) => AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          title: Text('Override magnitude cap?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          content: Text(
            res.message ?? 'Backend cap triggered.',
            style: TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.errorRed,
                elevation: 0,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Force apply',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (retry == true) {
        res = await c.adjust(
          elasticId: widget.elasticId,
          delta:     delta,
          reason:    reason,
          force:     true,
        );
      } else {
        Get.snackbar('Cancelled', 'Adjustment not applied',
            backgroundColor: ErpColors.textMuted,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    }

    if (res.ok && Navigator.canPop(dialogContext)) {
      Navigator.of(dialogContext).pop();
    }
  }
}

// ═════════════════════════════════════════════════════════════
//  P2-5 — TIMELINE FILTERS STRIP
// ═════════════════════════════════════════════════════════════
class _TimelineFilters extends StatelessWidget {
  final String typeFilter;
  final int    dayRange;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int>    onRangeChanged;
  final VoidCallback         onClear;
  const _TimelineFilters({
    required this.typeFilter,
    required this.dayRange,
    required this.searchCtrl,
    required this.onTypeChanged,
    required this.onRangeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bool anyActive = typeFilter != 'all' ||
        dayRange != 0 ||
        searchCtrl.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _RangeChip(label: 'All',  active: dayRange == 0,  onTap: () => onRangeChanged(0)),
              const SizedBox(width: 4),
              _RangeChip(label: '7d',   active: dayRange == 7,  onTap: () => onRangeChanged(7)),
              const SizedBox(width: 4),
              _RangeChip(label: '30d',  active: dayRange == 30, onTap: () => onRangeChanged(30)),
              const SizedBox(width: 4),
              _RangeChip(label: '90d',  active: dayRange == 90, onTap: () => onRangeChanged(90)),
              const SizedBox(width: 12),
              _TypeChip(label: 'All',         value: 'all',         current: typeFilter, onTap: onTypeChanged),
              const SizedBox(width: 4),
              _TypeChip(label: 'Packing',     value: 'packing',     current: typeFilter, onTap: onTypeChanged),
              const SizedBox(width: 4),
              _TypeChip(label: 'DC',          value: 'dc',          current: typeFilter, onTap: onTypeChanged),
              const SizedBox(width: 4),
              _TypeChip(label: 'Wastage',     value: 'wastage',     current: typeFilter, onTap: onTypeChanged),
              const SizedBox(width: 4),
              _TypeChip(label: 'Manual',      value: 'manual',      current: typeFilter, onTap: onTypeChanged),
              const SizedBox(width: 4),
              _TypeChip(label: 'Reservation', value: 'reservation', current: typeFilter, onTap: onTypeChanged),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    hintText: 'Search ref id / type / reason',
                    hintStyle: TextStyle(
                        color: ErpColors.textMuted, fontSize: 11),
                    prefixIcon: Icon(Icons.search,
                        size: 14, color: ErpColors.textMuted),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: ErpColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          BorderSide(color: ErpColors.borderLight),
                    ),
                  ),
                ),
              ),
            ),
            if (anyActive)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 14),
                label: const Text('Clear',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: ErpColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? ErpColors.accentBlue
                : ErpColors.bgMuted,
            border: Border.all(
                color: active
                    ? ErpColors.accentBlue
                    : ErpColors.borderLight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : ErpColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  const _TypeChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? ErpColors.successGreen
              : ErpColors.bgMuted,
          border: Border.all(
              color: active
                  ? ErpColors.successGreen
                  : ErpColors.borderLight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : ErpColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  ON-HAND HERO
// ═════════════════════════════════════════════════════════════
class _OnHandHero extends StatelessWidget {
  final ElasticStockController c;
  const _OnHandHero({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final last = c.movements.isNotEmpty ? c.movements.first : null;
      String lastLabel = '';
      if (last != null && last['date'] != null) {
        try {
          final dt = DateTime.parse(last['date'].toString()).toLocal();
          lastLabel = 'Last movement: ${DateFormat('dd MMM, hh:mm a').format(dt)}';
        } catch (_) {}
      }
      final low = c.isLowStock.value;
      final overReserved = c.reservedStock.value > c.stock.value;
      final heroColor = low ? const Color(0xFF7C2D12) : ErpColors.navyDark;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: heroColor,
          borderRadius: BorderRadius.circular(10),
          border: low
              ? Border.all(color: ErpColors.warningAmber, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ON HAND',
                    style: TextStyle(
                        color: ErpColors.textOnDarkSub,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700)),
                if (low) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ErpColors.warningAmber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('LOW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6)),
                  ),
                ],
                if (overReserved) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ErpColors.errorRed,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('OVER-RESERVED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmtNum(c.stock.value),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                Text('m',
                    style: TextStyle(
                        color: ErpColors.textOnDarkSub,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            if (lastLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(lastLabel,
                    style: TextStyle(
                        color: ErpColors.textOnDarkSub, fontSize: 11)),
              ),
            if (overReserved)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Reservations (${_fmtNum(c.reservedStock.value)} m) exceed on-hand stock — investigate or run reconcile.',
                  style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _MiniStat(
                  label: 'Produced',
                  value: _fmtNum(c.quantityProduced.value),
                ),
                _MiniStat(
                  label: 'Available',
                  value: _fmtNum(c.available.value),
                ),
                if (c.reservedStock.value > 0)
                  _MiniStat(
                    label: 'Reserved',
                    value: _fmtNum(c.reservedStock.value),
                  ),
                _MiniStat(
                  label: 'Min',
                  value: c.minStock.value > 0
                      ? _fmtNum(c.minStock.value)
                      : 'off',
                ),
                _MiniStat(
                  label: 'Movements',
                  value: '${c.movements.length}',
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  MOVEMENT ROW (tappable — P2-4)
// ═════════════════════════════════════════════════════════════
class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> mv;
  final bool isLast;
  final VoidCallback? onTap;
  const _MovementRow({
    required this.mv,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = mv['type']?.toString() ?? '';
    final applied = (mv['applied'] as num?)?.toDouble()
        ?? (mv['quantity'] as num?)?.toDouble() ?? 0;
    final requested = (mv['requested'] as num?)?.toDouble() ?? applied;
    final balance = (mv['balance']  as num?)?.toDouble() ?? 0;
    final dateRaw = mv['date'] as String?;
    final refType = mv['refType']?.toString();
    final refId   = mv['refId']?.toString();
    final reason  = mv['reason']?.toString();

    final isInfoOnly =
        type == 'RESERVATION_HOLD' || type == 'RESERVATION_RELEASE';
    final clamped =
        !isInfoOnly && (requested - applied).abs() > 0.0001;

    String when = '';
    if (dateRaw != null) {
      try {
        when = DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(dateRaw).toLocal());
      } catch (_) {}
    }

    final isInward = applied >= 0;
    final (color, label) = _movementColorLabel(type, isInward);

    String sub = '';
    if (refType != null && refType.isNotEmpty && refId != null) {
      final short = refId.length > 6 ? refId.substring(refId.length - 6) : refId;
      sub = '$refType #$short';
    }
    if ((type == 'MANUAL_ADJUST' || isInfoOnly) &&
        reason != null && reason.isNotEmpty) {
      sub = reason;
    }

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : ErpColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isInfoOnly
                  ? Icons.bookmark_outline_rounded
                  : (isInward
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded),
              color: color, size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(label.toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                  if (clamped) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: ErpColors.warningAmber.withValues(alpha: 0.15),
                        border: Border.all(
                            color: ErpColors.warningAmber.withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('CLAMPED',
                          style: TextStyle(
                              color: ErpColors.warningAmber,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    isInfoOnly
                        ? '${requested > 0 ? '+' : ''}${_fmtNum(requested)} m'
                        : '${applied > 0 ? '+' : ''}${_fmtNum(applied)} m',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text(
                      sub.isNotEmpty ? sub : when,
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isInfoOnly)
                    Text('Bal: ${_fmtNum(balance)} m',
                        style: TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                ]),
                if (clamped) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Requested ${_fmtNum(requested)} m — reduced to ${_fmtNum(applied)} m by zero-floor',
                    style: TextStyle(
                        color: ErpColors.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (sub.isNotEmpty && when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when,
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 10)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? row
        : InkWell(onTap: onTap, child: row);
  }
}

(Color, String) _movementColorLabel(String type, bool isInward) {
  switch (type) {
    case 'PACKING_INWARD':       return (ErpColors.successGreen, 'Packing');
    case 'PACKING_REVERSE':      return (ErpColors.errorRed,     'Packing reversed');
    case 'DC_OUT':               return (ErpColors.warningAmber, 'Dispatched (DC)');
    case 'DC_CANCEL_RETURN':     return (ErpColors.successGreen, 'DC cancelled');
    case 'WASTAGE_OUT':          return (ErpColors.errorRed,     'Wastage');
    case 'WASTAGE_RETURN':       return (ErpColors.successGreen, 'Wastage reversed');
    case 'RESERVATION_HOLD':     return (ErpColors.accentBlue,   'Reserved (hold)');
    case 'RESERVATION_RELEASE': return (ErpColors.accentBlue,   'Reserve released');
    case 'MANUAL_ADJUST':
      return (isInward ? ErpColors.successGreen : ErpColors.errorRed,
          'Manual adjust');
    default: return (ErpColors.accentBlue, type);
  }
}

// ═════════════════════════════════════════════════════════════
//  P2-4 — MOVEMENT DETAIL BOTTOM SHEET
// ═════════════════════════════════════════════════════════════
class _MovementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> mv;
  const _MovementDetailSheet({required this.mv});

  @override
  Widget build(BuildContext context) {
    final type      = mv['type']?.toString() ?? '';
    final applied   = (mv['applied']   as num?)?.toDouble()
        ?? (mv['quantity'] as num?)?.toDouble() ?? 0;
    final requested = (mv['requested'] as num?)?.toDouble() ?? applied;
    final balance   = (mv['balance']   as num?)?.toDouble() ?? 0;
    final dateRaw   = mv['date'] as String?;
    final refType   = mv['refType']?.toString();
    final refId     = mv['refId']?.toString();
    final reason    = mv['reason']?.toString();
    final byRaw     = mv['by'];

    final clamped = (requested - applied).abs() > 0.0001 &&
        type != 'RESERVATION_HOLD' &&
        type != 'RESERVATION_RELEASE';

    String when = '—';
    if (dateRaw != null) {
      try {
        when = DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(dateRaw).toLocal());
      } catch (_) {}
    }

    final (color, label) = _movementColorLabel(type, applied >= 0);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.swap_vert, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded,
                    color: ErpColors.textMuted, size: 20),
              ),
            ]),
            const SizedBox(height: 14),
            // Requested vs Applied side by side
            Row(children: [
              Expanded(
                child: _ValueBox(
                  label: 'REQUESTED',
                  value:
                      '${requested > 0 ? '+' : ''}${_fmtNum(requested)} m',
                  highlight: clamped ? ErpColors.warningAmber : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'APPLIED',
                  value:
                      '${applied > 0 ? '+' : ''}${_fmtNum(applied)} m',
                  highlight: clamped ? ErpColors.warningAmber : null,
                ),
              ),
            ]),
            if (clamped) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ErpColors.warningAmber.withValues(alpha: 0.10),
                  border: Border.all(
                      color: ErpColors.warningAmber.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: ErpColors.warningAmber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Clamped at zero floor — requested magnitude exceeded available stock.',
                      style: TextStyle(
                          color: ErpColors.warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            _Row(icon: Icons.event_outlined, label: 'When',
                value: when),
            _Row(icon: Icons.straighten_rounded, label: 'Balance after',
                value: '${_fmtNum(balance)} m'),
            if (refType != null && refType.isNotEmpty)
              _Row(icon: Icons.link, label: 'Source',
                  value: '$refType ${refId ?? ''}'),
            if (reason != null && reason.isNotEmpty)
              _Row(icon: Icons.notes_rounded, label: 'Reason',
                  value: reason),
            if (byRaw != null && byRaw.toString().isNotEmpty)
              _Row(icon: Icons.person_outline_rounded, label: 'By',
                  value: byRaw.toString()),
          ],
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  const _ValueBox({required this.label, required this.value, this.highlight});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: highlight ?? ErpColors.borderLight,
              width: highlight != null ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: highlight ?? ErpColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 14, color: ErpColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
