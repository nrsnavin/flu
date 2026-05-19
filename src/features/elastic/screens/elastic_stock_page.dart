import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_stock_controller.dart';

// ═════════════════════════════════════════════════════════════
//  ElasticStockPage — single elastic stock view
//
//  P2-7: optional initialAdjustDelta + initialAdjustReason params
//  let the Reconcile sheet deep-link straight into a pre-filled
//  Manual Adjust dialog. When both are set, the dialog opens once
//  after first frame.
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

  @override
  void initState() {
    super.initState();
    final tag = 'stock-${widget.elasticId}';
    Get.delete<ElasticStockController>(tag: tag, force: true);
    c = Get.put(ElasticStockController(), tag: tag);
    c.fetchStock(widget.elasticId);

    // Auto-open adjust dialog if we were navigated here with a
    // prefilled correction (e.g. from the reconcile sheet).
    final d = widget.initialAdjustDelta;
    final r = widget.initialAdjustReason;
    if (d != null && d != 0 && r != null && r.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAdjustDialog(context, prefillDelta: d, prefillReason: r);
      });
    }
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
            const Text('Stock ledger',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
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
                  const Icon(Icons.error_outline,
                      color: ErpColors.errorRed, size: 36),
                  const SizedBox(height: 10),
                  Text(c.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                child: c.movements.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            'No stock movements yet',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12)),
                      )
                    : Column(
                        children: List.generate(c.movements.length, (i) {
                          final m = c.movements[i];
                          return _MovementRow(
                            mv: m,
                            isLast: i == c.movements.length - 1,
                          );
                        }),
                      ),
              ),
            ],
          ),
        );
      }),
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
        title: const Text('Set Min Stock',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
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

  void _openAdjustDialog(
    BuildContext ctx, {
    double? prefillDelta,
    String? prefillReason,
  }) {
    // Prefilled flows (e.g. reconcile shortcut) decide ADD vs REMOVE
    // from the sign of the delta and present the absolute value.
    final hasPrefill = prefillDelta != null && prefillDelta != 0;
    final qtyCtrl = TextEditingController(
      text: hasPrefill ? prefillDelta!.abs().toStringAsFixed(0) : '',
    );
    final reasonCtrl = TextEditingController(text: prefillReason ?? '');
    bool isAdd = hasPrefill ? (prefillDelta! > 0) : true;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (_, setSheetState) {
        return AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          title: Text(
              hasPrefill ? 'Reconcile Adjust' : 'Manual Stock Adjust',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasPrefill)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.08),
                    border: Border.all(
                        color: ErpColors.accentBlue.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(children: [
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
                              ? ErpColors.successGreen.withOpacity(0.18)
                              : ErpColors.bgMuted,
                          border: Border.all(
                              color: isAdd
                                  ? ErpColors.successGreen
                                  : ErpColors.borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
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
                              ? ErpColors.errorRed.withOpacity(0.18)
                              : ErpColors.bgMuted,
                          border: Border.all(
                              color: !isAdd
                                  ? ErpColors.errorRed
                                  : ErpColors.borderLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
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
                  hint: 'Why is the stock being adjusted?',
                ),
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
                final qty = double.tryParse(qtyCtrl.text.trim());
                final reason = reasonCtrl.text.trim();
                if (qty == null || qty <= 0) {
                  Get.snackbar('Validation', 'Enter a valid quantity',
                      backgroundColor: ErpColors.errorRed,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                if (reason.isEmpty) {
                  Get.snackbar('Validation', 'Reason is required',
                      backgroundColor: ErpColors.errorRed,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final delta = isAdd ? qty : -qty;
                final ok = await c.adjust(
                  elasticId: widget.elasticId,
                  delta: delta,
                  reason: reason,
                );
                if (ok) Navigator.of(ctx).pop();
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
}

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
      // P2-9: detect over-reserved state (reservedStock > stock).
      // Possible when reservation was created before stock dropped,
      // or when a release was missed — flagged in red so an admin
      // notices.
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
                const Text('ON HAND',
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
                const Text('m',
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
                    style: const TextStyle(
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
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
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

class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> mv;
  final bool isLast;
  const _MovementRow({required this.mv, required this.isLast});

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
    Color color;
    String label;
    switch (type) {
      case 'PACKING_INWARD':
        color = ErpColors.successGreen; label = 'Packing'; break;
      case 'PACKING_REVERSE':
        color = ErpColors.errorRed;     label = 'Packing reversed'; break;
      case 'DC_OUT':
        color = ErpColors.warningAmber; label = 'Dispatched (DC)'; break;
      case 'DC_CANCEL_RETURN':
        color = ErpColors.successGreen; label = 'DC cancelled'; break;
      case 'WASTAGE_OUT':
        color = ErpColors.errorRed;     label = 'Wastage'; break;
      case 'WASTAGE_RETURN':
        color = ErpColors.successGreen; label = 'Wastage reversed'; break;
      case 'RESERVATION_HOLD':
        color = ErpColors.accentBlue;   label = 'Reserved (hold)'; break;
      case 'RESERVATION_RELEASE':
        color = ErpColors.accentBlue;   label = 'Reserve released'; break;
      case 'MANUAL_ADJUST':
        color = isInward ? ErpColors.successGreen : ErpColors.errorRed;
        label = 'Manual adjust';
        break;
      default:
        color = ErpColors.accentBlue; label = type;
    }

    String sub = '';
    if (refType != null && refType.isNotEmpty && refId != null) {
      final short = refId.length > 6 ? refId.substring(refId.length - 6) : refId;
      sub = '$refType #$short';
    }
    if ((type == 'MANUAL_ADJUST' || isInfoOnly) &&
        reason != null && reason.isNotEmpty) {
      sub = reason;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              color: color.withOpacity(0.12),
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
                      color: color.withOpacity(0.10),
                      border: Border.all(color: color.withOpacity(0.4)),
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
                        color: ErpColors.warningAmber.withOpacity(0.15),
                        border: Border.all(
                            color: ErpColors.warningAmber.withOpacity(0.6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('CLAMPED',
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
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isInfoOnly)
                    Text('Bal: ${_fmtNum(balance)} m',
                        style: const TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                ]),
                if (clamped) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Requested ${_fmtNum(requested)} m — reduced to ${_fmtNum(applied)} m by zero-floor',
                    style: const TextStyle(
                        color: ErpColors.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                if (sub.isNotEmpty && when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when,
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
