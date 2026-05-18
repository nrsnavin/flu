import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_stock_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ElasticStockPage — single elastic stock view
//
//  Routed from the Stock Map (and any future link from the elastic
//  detail page). Shows current on-hand stock, the movement ledger,
//  and a Manual Adjust action.
// ══════════════════════════════════════════════════════════════
class ElasticStockPage extends StatefulWidget {
  final String elasticId;
  final String? elasticName;
  const ElasticStockPage({
    super.key,
    required this.elasticId,
    this.elasticName,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: widget.elasticName ?? 'Elastic Stock',
        subtitle: 'Stock ledger',
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

  void _openAdjustDialog(BuildContext ctx) {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isAdd = true;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(builder: (_, setSheetState) {
        return AlertDialog(
          backgroundColor: ErpColors.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          title: const Text('Manual Stock Adjust',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          color: ErpColors.navyDark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ON HAND',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  label: 'Produced',
                  value: _fmtNum(c.quantityProduced.value),
                ),
                const SizedBox(width: 14),
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
    final type    = mv['type']?.toString() ?? '';
    final qty     = (mv['quantity'] as num?)?.toDouble() ?? 0;
    final balance = (mv['balance']  as num?)?.toDouble() ?? 0;
    final dateRaw = mv['date'] as String?;
    final refType = mv['refType']?.toString();
    final refId   = mv['refId']?.toString();
    final reason  = mv['reason']?.toString();

    String when = '';
    if (dateRaw != null) {
      try {
        when = DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(dateRaw).toLocal());
      } catch (_) {}
    }

    final isInward = qty >= 0;
    Color color;
    String label;
    switch (type) {
      case 'PACKING_INWARD':     color = ErpColors.successGreen; label = 'Packing'; break;
      case 'PACKING_REVERSE':    color = ErpColors.errorRed;     label = 'Packing reversed'; break;
      case 'DC_OUT':             color = ErpColors.warningAmber; label = 'Dispatched (DC)'; break;
      case 'DC_CANCEL_RETURN':   color = ErpColors.successGreen; label = 'DC cancelled'; break;
      case 'WASTAGE_OUT':        color = ErpColors.errorRed;     label = 'Wastage'; break;
      case 'MANUAL_ADJUST':
        color = isInward ? ErpColors.successGreen : ErpColors.errorRed;
        label = 'Manual adjust';
        break;
      default: color = ErpColors.accentBlue; label = type;
    }

    String sub = '';
    if (refType != null && refType.isNotEmpty && refId != null) {
      final short = refId.length > 6 ? refId.substring(refId.length - 6) : refId;
      sub = '$refType #$short';
    }
    if (type == 'MANUAL_ADJUST' && reason != null && reason.isNotEmpty) {
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
              isInward ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
                  const Spacer(),
                  Text('${qty > 0 ? '+' : ''}${_fmtNum(qty)} m',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
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
                  Text('Bal: ${_fmtNum(balance)} m',
                      style: const TextStyle(
                          color: ErpColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
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
