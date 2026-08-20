import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/forecast_controller.dart';

// ══════════════════════════════════════════════════════════════
//  MATERIALS FORECAST PAGE
//  Read-only replenishment forecast: which raw materials will run
//  short within the horizon and the suggested reorder quantity.
// ══════════════════════════════════════════════════════════════
class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  static final _money = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _qty = NumberFormat('#,##0.##', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ForecastController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Replenishment Forecast',
        subtitle: 'Projected raw-material shortfalls',
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.data.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.data.value == null) {
          return _ErrorView(message: ctrl.errorMsg.value!, onRetry: ctrl.fetch);
        }
        final materials = ctrl.materials;
        return RefreshIndicator(
          onRefresh: ctrl.fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _horizonChips(ctrl),
              const SizedBox(height: 12),
              _totalsBar(ctrl.totals),
              const SizedBox(height: 14),
              if (materials.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 44, color: ErpColors.successGreen),
                        SizedBox(height: 8),
                        Text('No shortfalls in this horizon',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                ...materials.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ForecastCard(data: m),
                    )),
            ],
          ),
        );
      }),
    );
  }

  Widget _horizonChips(ForecastController ctrl) {
    return Obx(() => Row(
          children: [7, 14, 30].map((d) {
            final selected = ctrl.horizonDays.value == d;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$d days'),
                selected: selected,
                labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : ErpColors.textSecondary),
                selectedColor: ErpColors.accentBlue,
                backgroundColor: ErpColors.bgSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: ErpColors.borderLight),
                ),
                onSelected: (_) => ctrl.setHorizon(d),
              ),
            );
          }).toList(),
        ));
  }

  Widget _totalsBar(Map<String, dynamic> t) {
    final flagged = (t['flagged'] as num?)?.toInt() ?? 0;
    final critical = (t['critical'] as num?)?.toInt() ?? 0;
    final suppliers = (t['suppliers'] as num?)?.toInt() ?? 0;
    final cost = (t['estimatedCost'] as num?)?.toDouble() ?? 0;
    return Row(
      children: [
        _stat('Flagged', '$flagged', ErpColors.accentBlue),
        const SizedBox(width: 8),
        _stat('Critical', '$critical', ErpColors.errorRed),
        const SizedBox(width: 8),
        _stat('Suppliers', '$suppliers', ErpColors.textPrimary),
        const SizedBox(width: 8),
        _stat('Est. cost', _money.format(cost), ErpColors.warningAmber),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: ErpColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ForecastCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final qty = ForecastPage._qty;
    final critical = (data['severity'] as String?) == 'critical';
    final onHand = (data['onHand'] as num?)?.toDouble() ?? 0;
    final suggested = (data['suggestedQty'] as num?)?.toDouble() ?? 0;
    final unit = (data['unit'] as String?) ?? '';
    final days = data['daysToStockout'];
    final supplier =
        (data['supplier'] as Map?)?['name'] as String? ?? 'No supplier';

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(
            color: critical ? ErpColors.statusCancelledBorder : ErpColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((data['name'] as String?) ?? '—',
                    style: TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: critical
                      ? ErpColors.statusCancelledBg
                      : ErpColors.statusPartialBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(critical ? 'CRITICAL' : 'WARN',
                    style: TextStyle(
                        color: critical
                            ? ErpColors.statusCancelledText
                            : ErpColors.statusPartialText,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text((data['category'] as String?) ?? '',
              style: TextStyle(
                  color: ErpColors.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              _kv('On hand', '${qty.format(onHand)} $unit'),
              _kv('Reorder', '${qty.format(suggested)} $unit'),
              _kv('Stockout',
                  days == null ? '—' : 'in ${(days as num).toStringAsFixed(0)}d'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 14, color: ErpColors.textMuted),
              const SizedBox(width: 6),
              Text(supplier,
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: TextStyle(
                  color: ErpColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: ErpColors.errorRed),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ErpPrimaryButton(label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
