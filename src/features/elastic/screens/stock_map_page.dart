import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_stock_controller.dart';
import 'elastic_stock_page.dart';

// ═════════════════════════════════════════════════════════════
//  StockMapPage — "map for clear picture" of elastic stock flow.
// ═════════════════════════════════════════════════════════════
class StockMapPage extends StatefulWidget {
  const StockMapPage({super.key});

  @override
  State<StockMapPage> createState() => _StockMapPageState();
}

class _StockMapPageState extends State<StockMapPage> {
  late final ElasticStockController c;
  bool _lowOnly = false;

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
            Text('Elastic Stock',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text('Flow & on-hand by elastic',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reconcile',
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
            onPressed: () => _openReconcileSheet(context),
          ),
        ],
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
                  Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 10),
                  Text(c.summaryErrorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
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

        double totalStock    = 0;
        double totalProduced = 0;
        int    lowStockCount = 0;
        for (final r in c.summary) {
          totalStock    += (r['stock']            as num?)?.toDouble() ?? 0;
          totalProduced += (r['quantityProduced'] as num?)?.toDouble() ?? 0;
          if ((r['isLowStock'] as bool?) ?? false) lowStockCount++;
        }
        final totalElastics = c.summary.length;

        final visible = _lowOnly
            ? c.summary.where((r) => (r['isLowStock'] as bool?) ?? false).toList()
            : c.summary;

        return RefreshIndicator(
          onRefresh: c.fetchSummary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _KpiRow(
                totalStock: totalStock,
                totalProduced: totalProduced,
                totalElastics: totalElastics,
                lowStockCount: lowStockCount,
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
                trailing: lowStockCount > 0
                    ? GestureDetector(
                        onTap: () => setState(() => _lowOnly = !_lowOnly),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _lowOnly
                                ? ErpColors.warningAmber
                                : ErpColors.warningAmber.withValues(alpha: 0.15),
                            border: Border.all(
                                color: ErpColors.warningAmber.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _lowOnly ? 'ALL' : 'LOW ONLY ($lowStockCount)',
                            style: TextStyle(
                                color: _lowOnly
                                    ? Colors.white
                                    : ErpColors.warningAmber,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5),
                          ),
                        ),
                      )
                    : null,
                child: visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            _lowOnly
                                ? 'No low-stock elastics'
                                : 'No elastics yet',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 12)),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            _SummaryRow(
                              row: visible[i],
                              isLast: i == visible.length - 1,
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

  void _openReconcileSheet(BuildContext ctx) {
    c.fetchReconcile();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: ErpColors.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, scroll) => Obx(() => Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fact_check_outlined,
                          color: ErpColors.accentBlue),
                      const SizedBox(width: 8),
                      Text('Reconcile',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: c.fetchReconcile,
                      ),
                    ],
                  ),
                  Text(
                    'Compares Elastic.stock with the sum of ledger movements. Tap "Write correction" on a drift row to open a pre-filled manual adjust.',
                    style: TextStyle(
                        color: ErpColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  if (c.reconcileLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.reconcileError.value != null)
                    Text(c.reconcileError.value!,
                        style: TextStyle(
                            color: ErpColors.errorRed, fontSize: 12))
                  else if (c.drifts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ErpColors.successGreen.withValues(alpha: 0.08),
                        border: Border.all(
                            color: ErpColors.successGreen.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_circle,
                            color: ErpColors.successGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No drift detected. Stock and ledger sums agree across all elastics.',
                            style: TextStyle(
                                color: ErpColors.successGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: c.drifts.length,
                        itemBuilder: (_, i) {
                          final d = c.drifts[i];
                          final id    = d['elasticId']?.toString() ?? '';
                          final name  = d['name']?.toString() ?? '—';
                          final drift =
                              (d['drift']     as num?)?.toDouble() ?? 0;
                          final stock =
                              (d['stock']     as num?)?.toDouble() ?? 0;
                          final sum =
                              (d['ledgerSum'] as num?)?.toDouble() ?? 0;
                          final moves =
                              (d['moveCount'] as num?)?.toInt()    ?? 0;
                          final positive = drift > 0;
                          // Correction delta brings stock back in
                          // line with the ledger: delta = -drift.
                          final correctionDelta = -drift;
                          final reasonText =
                              'Reconciliation ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ErpColors.bgMuted,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: ErpColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                          color: ErpColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (positive
                                              ? ErpColors.warningAmber
                                              : ErpColors.errorRed)
                                          .withValues(alpha: 0.15),
                                      border: Border.all(
                                        color: (positive
                                                ? ErpColors.warningAmber
                                                : ErpColors.errorRed)
                                            .withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${drift > 0 ? '+' : ''}${_fmtNum(drift)}',
                                      style: TextStyle(
                                        color: positive
                                            ? ErpColors.warningAmber
                                            : ErpColors.errorRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  'stock ${_fmtNum(stock)}  ·  ledger ${_fmtNum(sum)}  ·  $moves moves',
                                  style: TextStyle(
                                      color: ErpColors.textSecondary,
                                      fontSize: 11),
                                ),
                                const SizedBox(height: 8),
                                // P2-7: Write correction shortcut →
                                // closes the sheet, navigates to the
                                // per-elastic page with the manual
                                // adjust dialog pre-opened.
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () {
                                            Navigator.of(sheetCtx).pop();
                                            Get.to(() => ElasticStockPage(
                                                  elasticId:           id,
                                                  elasticName:         name,
                                                  initialAdjustDelta:  correctionDelta,
                                                  initialAdjustReason: reasonText,
                                                ));
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: ErpColors.accentBlue,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                        Icons.tune_rounded, size: 14),
                                    label: Text(
                                      'Write correction (${correctionDelta > 0 ? '+' : ''}${_fmtNum(correctionDelta)} m)',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            )),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final double totalStock;
  final double totalProduced;
  final int totalElastics;
  final int lowStockCount;
  const _KpiRow({
    required this.totalStock,
    required this.totalProduced,
    required this.totalElastics,
    required this.lowStockCount,
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
              label: lowStockCount > 0 ? 'LOW STOCK' : 'ELASTICS',
              value: lowStockCount > 0
                  ? '$lowStockCount / $totalElastics'
                  : '$totalElastics',
              color: lowStockCount > 0
                  ? ErpColors.warningAmber
                  : ErpColors.textSecondary,
              icon: lowStockCount > 0
                  ? Icons.warning_amber_rounded
                  : Icons.layers_outlined,
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
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6)),
          ],
        ),
      );
}

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
          Text(
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
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4)),
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
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            Text(unit,
                style: TextStyle(
                    color: ErpColors.textMuted, fontSize: 9)),
          ],
        ),
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => Padding(
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
    final stock     = (row['stock']         as num?)?.toDouble() ?? 0;
    final reserved  = (row['reservedStock'] as num?)?.toDouble() ?? 0;
    final available = (row['available']     as num?)?.toDouble() ?? stock;
    final minStock  = (row['minStock']      as num?)?.toDouble() ?? 0;
    final low       = (row['isLowStock']    as bool?) ?? false;
    final overReserved = reserved > stock; // P2-9
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
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          style: TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (low) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: ErpColors.warningAmber,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('LOW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4)),
                      ),
                    ],
                    if (overReserved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: ErpColors.errorRed,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('OVER-RESERVED',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    reserved > 0
                        ? 'Avail ${_fmtNum(available)} / Reserved ${_fmtNum(reserved)}'
                        : (minStock > 0
                            ? 'Min ${_fmtNum(minStock)}  ·  Last $lastLbl'
                            : 'Last $lastLbl'),
                    style: TextStyle(
                        color: ErpColors.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text('${_fmtNum(stock)} m',
                style: TextStyle(
                    color: overReserved
                        ? ErpColors.errorRed
                        : (low
                            ? ErpColors.warningAmber
                            : ErpColors.accentBlue),
                    fontSize: 14,
                    fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
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
