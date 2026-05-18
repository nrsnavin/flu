import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_stock_controller.dart';
import 'elastic_stock_page.dart';

// ══════════════════════════════════════════════════════════════
//  StockMapPage — "map for clear picture" of elastic stock flow.
// ══════════════════════════════════════════════════════════════
class StockMapPage extends StatefulWidget {
  const StockMapPage({super.key});

  @override
  State<StockMapPage> createState() => _StockMapPageState();
}

class _StockMapPageState extends State<StockMapPage> {
  late final ElasticStockController c;

  @override
  void initState() {
    super.initState();
    Get.delete<ElasticStockController>(tag: 'stock-map', force: true);
    c = Get.put(ElasticStockController(), tag: 'stock-map');
    c.fetchSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Elastic Stock',
        subtitle: 'Flow & on-hand by elastic',
      ),
      body: Obx(() {
        if (c.summaryLoading.value && c.summary.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.summaryErrorMsg.value != null && c.summary.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 10),
                  Text(c.summaryErrorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: c.fetchSummary,
                  ),
                ],
              ),
            ),
          );
        }

        // Totals derived client-side from the summary endpoint.
        double totalStock    = 0;
        double totalProduced = 0;
        for (final r in c.summary) {
          totalStock    += (r['stock']            as num?)?.toDouble() ?? 0;
          totalProduced += (r['quantityProduced'] as num?)?.toDouble() ?? 0;
        }
        final totalElastics = c.summary.length;

        return RefreshIndicator(
          onRefresh: c.fetchSummary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _KpiRow(
                totalStock: totalStock,
                totalProduced: totalProduced,
                totalElastics: totalElastics,
              ),
              const SizedBox(height: 16),
              _FlowMap(
                produced: totalProduced,
                onHand: totalStock,
              ),
              const SizedBox(height: 16),
              ErpSectionCard(
                title: 'PER ELASTIC',
                icon: Icons.list_alt_rounded,
                child: c.summary.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No elastics yet',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12)),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < c.summary.length; i++)
                            _SummaryRow(
                              row: c.summary[i],
                              isLast: i == c.summary.length - 1,
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
}

class _KpiRow extends StatelessWidget {
  final double totalStock;
  final double totalProduced;
  final int totalElastics;
  const _KpiRow({
    required this.totalStock,
    required this.totalProduced,
    required this.totalElastics,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _Kpi(
              label: 'TOTAL ON HAND',
              value: '${_fmtNum(totalStock)} m',
              color: ErpColors.accentBlue,
              icon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Kpi(
              label: 'PRODUCED YTD',
              value: '${_fmtNum(totalProduced)} m',
              color: ErpColors.successGreen,
              icon: Icons.factory_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Kpi(
              label: 'ELASTICS',
              value: '$totalElastics',
              color: ErpColors.warningAmber,
              icon: Icons.layers_outlined,
            ),
          ),
        ],
      );
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
          ],
        ),
      );
}

// Simple flow boxes: PACKING → STOCK → DC, with arrows + totals.
class _FlowMap extends StatelessWidget {
  final double produced;
  final double onHand;
  const _FlowMap({required this.produced, required this.onHand});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'STOCK FLOW',
      icon: Icons.alt_route_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FlowBox(
                  title: 'PACKING',
                  value: _fmtNum(produced),
                  unit: 'm produced',
                  color: ErpColors.successGreen,
                  icon: Icons.factory_outlined,
                ),
              ),
              const _Arrow(),
              Expanded(
                child: _FlowBox(
                  title: 'STOCK',
                  value: _fmtNum(onHand),
                  unit: 'm on hand',
                  color: ErpColors.accentBlue,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const _Arrow(),
              Expanded(
                child: _FlowBox(
                  title: 'DC',
                  value: _fmtNum(produced - onHand < 0
                      ? 0
                      : produced - onHand),
                  unit: 'm out',
                  color: ErpColors.warningAmber,
                  icon: Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Packing inwards → finished stock → Delivery Challan outwards. “Out” is a rough difference; cancelled DCs restore stock.',
            style: TextStyle(
                color: ErpColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FlowBox extends StatelessWidget {
  final String title, value, unit;
  final Color color;
  final IconData icon;
  const _FlowBox({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            Text(unit,
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 9)),
          ],
        ),
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.east_rounded,
            color: ErpColors.textMuted, size: 16),
      );
}

class _SummaryRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isLast;
  const _SummaryRow({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final id        = row['elasticId']?.toString() ??
        row['_id']?.toString() ?? '';
    final name      = row['name']?.toString() ?? 'Elastic';
    final stock     = (row['stock'] as num?)?.toDouble() ?? 0;
    final lastRaw   = row['lastMovementAt'] as String?;
    String lastLbl  = '—';
    if (lastRaw != null) {
      try {
        final dt = DateTime.parse(lastRaw).toLocal();
        lastLbl = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {}
    }

    return InkWell(
      onTap: id.isEmpty
          ? null
          : () => Get.to(() => ElasticStockPage(
                elasticId: id,
                elasticName: name,
              )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : ErpColors.borderLight,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Last: $lastLbl',
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
            Text('${_fmtNum(stock)} m',
                style: const TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 18, color: ErpColors.textMuted),
          ],
        ),
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
