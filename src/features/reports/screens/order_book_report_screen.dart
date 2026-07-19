import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../report_pdf.dart';
import '../controllers/order_book_report_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ORDER BOOK & FULFILLMENT — mobile summary
//
//  Order intake, pending quantity, overdue count and on-time delivery
//  over a preset period, grouped by customer / status / supply month.
// ══════════════════════════════════════════════════════════════
class OrderBookReportScreen extends StatelessWidget {
  const OrderBookReportScreen({super.key});

  static final _nf = NumberFormat.decimalPattern('en_IN');

  static const _presetLabels = {
    'today': 'Today', 'week': 'Week', 'month': 'Month', 'fy': 'FY',
  };
  static const _groupLabels = {
    'customer': 'Customer', 'status': 'Status', 'supplyMonth': 'Supply month',
  };

  @override
  Widget build(BuildContext context) {
    final c = Get.put(OrderBookReportController());
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: 'Order Book',
        subtitle: 'Intake, pending & on-time delivery',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => downloadReportPdf(
              path: '/reports/order-book',
              query: {'preset': c.preset.value, 'groupBy': c.groupBy.value, 'compare': true},
              filename: 'order-book-report',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _PresetBar(c: c),
          Expanded(
            child: RefreshIndicator(
              onRefresh: c.fetch,
              child: Obx(() {
                if (c.loading.value && c.summary.value == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: ErpColors.accentBlue),
                  );
                }
                if (c.errorMsg.value != null && c.summary.value == null) {
                  return ListView(children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.cloud_off_outlined, size: 44, color: ErpColors.textMuted),
                    const SizedBox(height: 10),
                    Center(child: Text(c.errorMsg.value ?? 'Error',
                        style: const TextStyle(color: ErpColors.textSecondary))),
                    const SizedBox(height: 12),
                    Center(child: OutlinedButton(onPressed: c.fetch, child: const Text('Retry'))),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _tiles(c),
                    const SizedBox(height: 16),
                    _groupBar(c),
                    const SizedBox(height: 10),
                    ..._rows(c),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles(OrderBookReportController c) {
    final d = c.ordersDelta;
    final otd = c.onTimePct;
    return Column(children: [
      Row(children: [
        Expanded(child: _Tile(
          label: 'Orders',
          value: _nf.format(c.orders),
          trailing: d == null || d == 0 ? null : _DeltaChip(value: d),
        )),
        const SizedBox(width: 10),
        Expanded(child: _Tile(label: 'Pending', value: '${_nf.format(c.pendingQty)} m')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Tile(
          label: 'Overdue',
          value: _nf.format(c.overdueOrders),
          danger: c.overdueOrders > 0,
          sub: '${_nf.format(c.openOrders)} open',
        )),
        const SizedBox(width: 10),
        Expanded(child: _Tile(
          label: 'On-time delivery',
          value: otd == null ? '—' : '$otd%',
        )),
      ]),
    ]);
  }

  Widget _groupBar(OrderBookReportController c) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => Row(
              children: OrderBookReportController.groupBys.map((g) {
                final selected = c.groupBy.value == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_groupLabels[g] ?? g),
                    selected: selected,
                    selectedColor: ErpColors.accentBlue,
                    backgroundColor: ErpColors.bgSurface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : ErpColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) => c.groupBy.value = g,
                  ),
                );
              }).toList(),
            )),
      ),
    );
  }

  List<Widget> _rows(OrderBookReportController c) {
    if (c.rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Center(
            child: Text('No orders in this period',
                style: TextStyle(color: ErpColors.textMuted)),
          ),
        ),
      ];
    }
    return c.rows.map((r) {
      final label = r['label']?.toString() ?? '—';
      final orders = (r['orders'] as num?) ?? 0;
      final pending = (r['pendingQty'] as num?) ?? 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ErpDecorations.card,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Text('${_nf.format(orders)} ord',
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(width: 10),
          Text('${_nf.format(pending)} m pend',
              style: const TextStyle(color: ErpColors.textMuted, fontSize: 11)),
        ]),
      );
    }).toList();
  }
}

class _PresetBar extends StatelessWidget {
  final OrderBookReportController c;
  const _PresetBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Obx(() => Row(
            children: OrderBookReportController.presets.map((p) {
              final selected = c.preset.value == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(OrderBookReportScreen._presetLabels[p] ?? p),
                  selected: selected,
                  selectedColor: ErpColors.accentBlue,
                  backgroundColor: ErpColors.bgMuted,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ErpColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  onSelected: (_) => c.preset.value = p,
                ),
              );
            }).toList(),
          )),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Widget? trailing;
  final bool danger;
  const _Tile({required this.label, required this.value, this.sub, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ErpDecorations.card,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label,
                style: const TextStyle(color: ErpColors.textMuted, fontSize: 11))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: danger ? ErpColors.errorRed : ErpColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(color: ErpColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final num value;
  const _DeltaChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = up ? ErpColors.successGreen : ErpColors.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: color),
        const SizedBox(width: 2),
        Text('${up ? '+' : ''}$value',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
