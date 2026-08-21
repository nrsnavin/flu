// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL DETAIL PAGE
//  File: lib/src/features/rawMaterial/screens/material_detail_screen.dart
//
//  Sections:
//  • Hero card  (stock level, price, category, supplier)
//  • Summary chips  (total inward / total outward)
//  • Tab bar:  Inward | Outward | Ledger
//  • Each tab is a list of dated, referenced records
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/detail_controller.dart';
import '../models/detail_model.dart';
import '../models/yarn_lot.dart';


class RawMaterialDetailPage extends StatefulWidget {
  final String materialId;
  const RawMaterialDetailPage({super.key, required this.materialId});

  @override
  State<RawMaterialDetailPage> createState() => _RawMaterialDetailPageState();
}

class _RawMaterialDetailPageState extends State<RawMaterialDetailPage>
    with SingleTickerProviderStateMixin {
  late final RawMaterialDetailController _c;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    Get.delete<RawMaterialDetailController>(force: true);
    _c  = Get.put(RawMaterialDetailController(materialId: widget.materialId));
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _c.activeTab.value = _tab.index;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(context),
      body: Obx(() {
        if (_c.isLoading.value) {
          return Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (_c.errorMsg.value != null) {
          return _ErrorBody(
              msg: _c.errorMsg.value!, retry: _c.fetchDetail);
        }
        final m = _c.material.value;
        if (m == null) return const SizedBox.shrink();
        return _Body(c: _c, material: m, tab: _tab);
      }),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    ),
    titleSpacing: 4,
    title: Obx(() {
      final m = _c.material.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m?.name ?? 'Material Detail',
              style: ErpTextStyles.pageTitle,
              overflow: TextOverflow.ellipsis),
          Text('Raw Materials  ›  Detail',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      );
    }),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded,
            color: Colors.white, size: 20),
        onPressed: _c.fetchDetail,
      ),
      const SizedBox(width: 4),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  BODY
// ══════════════════════════════════════════════════════════════
class _Body extends StatelessWidget {
  final RawMaterialDetailController c;
  final RawMaterialDetailModel material;
  final TabController tab;
  const _Body(
      {required this.c, required this.material, required this.tab});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: ErpColors.accentBlue,
      onRefresh: () async {
        await Future.wait([c.fetchDetail(), c.fetchLots()]);
      },
      child: Column(children: [
        // Fixed hero + summary + price history + tab bar
        _HeroCard(material: material),
        _SummaryRow(material: material),
        if (material.priceHistory.isNotEmpty)
          _PriceHistoryStrip(history: material.priceHistory),
        _TabBar(tab: tab),
        // Scrollable tab content
        Expanded(
          child: TabBarView(
            controller: tab,
            children: [
              _InwardTab(records: c.inwards),
              _OutwardTab(records: c.outwards),
              _LedgerTab(movements: c.ledger),
              _LotsTab(c: c),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final RawMaterialDetailModel material;
  const _HeroCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final isLow   = material.isLowStock;
    final stockColor = isLow ? ErpColors.errorRed : ErpColors.successGreen;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        border: Border(
            bottom: BorderSide(color: Color(0xFF1E3A5F))),
      ),
      child: Row(children: [
        // Material icon badge
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: ErpColors.accentBlue.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.category_outlined,
              size: 26, color: Colors.white),
        ),
        const SizedBox(width: 14),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(material.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                _HeroPill(material.category),
                if (material.supplierName != null) ...[
                  const SizedBox(width: 6),
                  _HeroPill(material.supplierName!,
                      icon: Icons.store_outlined),
                ],
              ]),
            ],
          ),
        ),
        // Stock level
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${material.stock.toStringAsFixed(2)} kg',
            style: TextStyle(
                color: stockColor,
                fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            isLow ? '⚠ Low Stock' : 'In Stock',
            style: TextStyle(
                color: stockColor.withValues(alpha: 0.8), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text('₹${material.price.toStringAsFixed(2)}/kg',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _HeroPill(this.label, {this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 10, color: ErpColors.textOnDarkSub),
        const SizedBox(width: 4),
      ],
      Text(label,
          style: TextStyle(
              color: ErpColors.textOnDarkSub,
              fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  SUMMARY ROW
// ══════════════════════════════════════════════════════════════
class _SummaryRow extends StatelessWidget {
  final RawMaterialDetailModel material;
  const _SummaryRow({required this.material});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SumChip(
          label: 'Total Inward',
          value: '${material.totalInward.toStringAsFixed(2)} kg',
          color: ErpColors.successGreen,
          icon: Icons.arrow_downward_rounded,
          count: material.inwards.length,
        ),
        Container(width: 1, height: 36, color: ErpColors.borderLight),
        _SumChip(
          label: 'Total Outward',
          value: '${material.totalOutward.toStringAsFixed(2)} kg',
          color: ErpColors.errorRed,
          icon: Icons.arrow_upward_rounded,
          count: material.outwards.length,
        ),
        Container(width: 1, height: 36, color: ErpColors.borderLight),
        _SumChip(
          label: 'Min Stock',
          value: '${material.minStock.toStringAsFixed(2)} kg',
          color: ErpColors.warningAmber,
          icon: Icons.warning_amber_outlined,
        ),
      ],
    ),
  );
}

class _SumChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final int? count;
  const _SumChip({
    required this.label, required this.value,
    required this.color, required this.icon,
    this.count,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13, fontWeight: FontWeight.w900)),
        if (count != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 9, fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9, fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  TAB BAR
// ══════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  final TabController tab;
  const _TabBar({required this.tab});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    child: TabBar(
      controller: tab,
      labelColor: ErpColors.accentBlue,
      unselectedLabelColor: ErpColors.textMuted,
      indicatorColor: ErpColors.accentBlue,
      indicatorWeight: 2,
      labelStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500),
      tabs: const [
        Tab(text: 'Inward'),
        Tab(text: 'Outward'),
        Tab(text: 'Ledger'),
        Tab(text: 'Lots'),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  INWARD TAB
// ══════════════════════════════════════════════════════════════
class _InwardTab extends StatelessWidget {
  final List<MaterialInwardModel> records;
  const _InwardTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyTab(
          icon: Icons.arrow_downward_rounded,
          label: 'No inward records yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _InwardCard(record: records[i]),
    );
  }
}

class _InwardCard extends StatelessWidget {
  final MaterialInwardModel record;
  const _InwardCard({required this.record});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [
        BoxShadow(
            color: ErpColors.navyDark.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        // Direction icon
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: ErpColors.successGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.arrow_downward_rounded,
              size: 18, color: ErpColors.successGreen),
        ),
        const SizedBox(width: 12),
        // Reference + date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reference pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ErpColors.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: ErpColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_outlined,
                      size: 11, color: ErpColors.successGreen),
                  const SizedBox(width: 4),
                  Text(record.referenceLabel,
                      style: TextStyle(
                          color: ErpColors.successGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: ErpColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(record.inwardDate),
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11),
                ),
              ]),
              if (record.remarks.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(record.remarks,
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        // Quantity
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+${record.quantity.toStringAsFixed(2)}',
              style: TextStyle(
                  color: ErpColors.successGreen,
                  fontSize: 16, fontWeight: FontWeight.w900)),
          Text('kg',
              style: TextStyle(
                  color: ErpColors.textMuted, fontSize: 10)),
        ]),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  OUTWARD TAB
// ══════════════════════════════════════════════════════════════
class _OutwardTab extends StatelessWidget {
  final List<MaterialOutwardModel> records;
  const _OutwardTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyTab(
          icon: Icons.arrow_upward_rounded,
          label: 'No outward records yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _OutwardCard(record: records[i]),
    );
  }
}

class _OutwardCard extends StatelessWidget {
  final MaterialOutwardModel record;
  const _OutwardCard({required this.record});

  // Type → colour
  Color get _typeColor {
    switch (record.type) {
      case 'ORDER_APPROVAL':  return const Color(0xFF7C3AED);
      case 'JOB_CONSUMPTION': return ErpColors.warningAmber;
      default:                return ErpColors.errorRed;
    }
  }
  IconData get _typeIcon {
    switch (record.type) {
      case 'ORDER_APPROVAL':  return Icons.assignment_turned_in_outlined;
      case 'JOB_CONSUMPTION': return Icons.precision_manufacturing_outlined;
      default:                return Icons.tune_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [
        BoxShadow(
            color: ErpColors.navyDark.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(_typeIcon, size: 18, color: _typeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _typeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(record.typeLabel,
                      style: TextStyle(
                          color: _typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                // Reference
                Expanded(
                  child: Text(record.referenceLabel,
                      style: TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: ErpColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(record.outwardDate),
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11),
                ),
              ]),
              if (record.remarks.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(record.remarks,
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('-${record.quantity.toStringAsFixed(2)}',
              style: TextStyle(
                  color: _typeColor,
                  fontSize: 16, fontWeight: FontWeight.w900)),
          Text('kg',
              style: TextStyle(
                  color: ErpColors.textMuted, fontSize: 10)),
        ]),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  LEDGER TAB  (running balance)
// ══════════════════════════════════════════════════════════════
class _LedgerTab extends StatelessWidget {
  final List<StockMovementModel> movements;
  const _LedgerTab({required this.movements});

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const _EmptyTab(
          icon: Icons.receipt_long_outlined,
          label: 'No ledger entries yet');
    }
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          border: Border(
              bottom: BorderSide(color: ErpColors.borderLight)),
        ),
        child: Row(children: [
          Expanded(flex: 2,
              child: Text('Date',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textMuted,
                      letterSpacing: 0.3))),
          Expanded(flex: 2,
              child: Text('Type',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textMuted))),
          SizedBox(width: 56,
              child: Text('Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textMuted))),
          SizedBox(width: 8),
          SizedBox(width: 60,
              child: Text('Balance',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textMuted))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 40),
          itemCount: movements.length,
          itemBuilder: (_, i) => _LedgerRow(
              movement: movements[i],
              isEven: i.isEven),
        ),
      ),
    ]);
  }
}

/// The dye lot behind one ledger row.
///
/// Three kinds of answer reach here and they are not equal:
///
///   • a lot RECORDED on the receipt or adjustment that caused it;
///   • a lot a warping batch drew, which is exact;
///   • a lot INFERRED for an order approval that named none, taken as
///     the earliest lot that had arrived by then.
///
/// The third says so. The point of the whole column is that a reading
/// never reads as a record — somebody on the floor acts on this.
class _LedgerLotLine extends StatelessWidget {
  final StockMovementModel movement;
  const _LedgerLotLine({required this.movement});

  @override
  Widget build(BuildContext context) {
    if (!movement.hasLot) {
      // A batch row that lost its lot. Says so rather than showing
      // nothing, because a blank here looks like an ordinary row.
      return Text('Lot not recorded',
          style: TextStyle(
              color: ErpColors.textMuted,
              fontSize: 10,
              fontStyle: FontStyle.italic));
    }

    return Row(children: [
      Icon(Icons.label_outline_rounded,
          size: 11, color: ErpColors.textMuted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          movement.lotNo,
          style: TextStyle(
              color: movement.lotDerived
                  ? ErpColors.textMuted
                  : ErpColors.textSecondary,
              fontSize: 10,
              fontStyle:
                  movement.lotDerived ? FontStyle.italic : FontStyle.normal,
              fontWeight:
                  movement.lotDerived ? FontWeight.w500 : FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (movement.lotDerived) ...[
        const SizedBox(width: 4),
        Text('inferred',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 9)),
      ],
      if (movement.lotOnly) ...[
        const SizedBox(width: 6),
        Text('off the rack',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 9)),
      ],
    ]);
  }
}

class _LedgerRow extends StatelessWidget {
  final StockMovementModel movement;
  final bool isEven;
  const _LedgerRow({required this.movement, required this.isEven});

  bool get _isIn => movement.quantity > 0 ||
      movement.type == 'PO_INWARD';

  @override
  Widget build(BuildContext context) {
    // A batch row reports the RACK, so it is neither an inward nor an
    // outward on this material's balance and is coloured neutrally.
    // Painting it green or red would be a second thing on the row
    // claiming the balance moved.
    final qty = movement.displayQuantity;
    final color = movement.lotOnly
        ? ErpColors.textSecondary
        : (_isIn ? ErpColors.successGreen : ErpColors.errorRed);
    final sign = movement.lotOnly
        ? (qty > 0 ? '+' : '')
        : (_isIn ? '+' : '');
    final typeShort = switch (movement.type) {
      'PO_INWARD'      => 'PO Inward',
      'ORDER_APPROVAL' => movement.orderNo != null
          ? 'Order #${movement.orderNo}'
          : 'Order Approval',
      'STOCK_ADJUST'   => 'Adjustment',
      'BATCH_ISSUE'    => 'Warped',
      'BATCH_RETURN'   => 'Returned',
      _                => movement.type,
    };

    return Container(
      color: isEven
          ? ErpColors.bgSurface
          : ErpColors.bgMuted.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(flex: 2,
              child: Text(
                DateFormat('dd MMM yy').format(movement.date),
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 11),
              ),
            ),
            Expanded(flex: 2,
              child: Text(typeShort,
                  style: TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 56,
              child: Text(
                '$sign${qty.abs().toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 60,
              // Blank on a rack movement. The balance did not change,
              // and repeating it would read as though this row had
              // held it there.
              child: Text(
                movement.lotOnly ? '—' : movement.balance.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: movement.lotOnly
                        ? ErpColors.textMuted
                        : ErpColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          // ── The dye lot, on its own line ──────────────────────
          // A fifth column on a phone would crush the four that are
          // already there, and the lot is a caption on the movement
          // rather than a figure to scan down.
          if (movement.hasLot || movement.lotOnly) ...[
            const SizedBox(height: 3),
            _LedgerLotLine(movement: movement),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PRICE HISTORY STRIP
//  Shows last 5 price changes as a collapsible section between
//  the summary row and the tab bar.
// ══════════════════════════════════════════════════════════════
class _PriceHistoryStrip extends StatefulWidget {
  final List<PriceHistoryModel> history;
  const _PriceHistoryStrip({required this.history});

  @override
  State<_PriceHistoryStrip> createState() => _PriceHistoryStripState();
}

class _PriceHistoryStripState extends State<_PriceHistoryStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Most recent entry
    final latest  = widget.history.first;
    final isUp    = latest.change > 0;
    final color   = isUp ? ErpColors.errorRed : ErpColors.successGreen;
    final sign    = isUp ? '+' : '';

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(
            bottom: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary row (always visible) ─────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                        isUp ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Current Price',
                              style: TextStyle(
                                  color: ErpColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3)),
                          const SizedBox(width: 6),
                          Text('₹${latest.price.toStringAsFixed(2)}/kg',
                              style: TextStyle(
                                  color: ErpColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$sign₹${latest.change.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: color, fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                        Text(
                          'Last changed ${DateFormat('dd MMM yyyy').format(latest.changedAt)}'
                              '${latest.reason.isNotEmpty ? ' · ${latest.reason}' : ''}',
                          style: TextStyle(
                              color: ErpColors.textMuted, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18, color: ErpColors.textMuted),
                ]),
              ),
            ),

            // ── Expanded history list ─────────────────────────────
            if (_expanded) ...[
              Divider(height: 1, color: ErpColors.borderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(children: [
                  // Header
                  Row(children: [
                    Expanded(child: Text('Date',
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textMuted,
                            letterSpacing: 0.3))),
                    SizedBox(width: 70, child: Text('Old Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textMuted))),
                    SizedBox(width: 8),
                    SizedBox(width: 70, child: Text('New Price',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textMuted))),
                    SizedBox(width: 8),
                    SizedBox(width: 52, child: Text('Change',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textMuted))),
                  ]),
                  const SizedBox(height: 6),
                  // Rows — show last 10
                  ...widget.history.take(10).map((h) {
                    final up   = h.change > 0;
                    final col  = up ? ErpColors.errorRed : ErpColors.successGreen;
                    final sign = up ? '+' : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yy').format(h.changedAt),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: ErpColors.textPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (h.reason.isNotEmpty)
                                Text(h.reason,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: ErpColors.textMuted,
                                        fontStyle: FontStyle.italic),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        SizedBox(width: 70,
                          child: Text(
                            '₹${h.oldPrice.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                color: ErpColors.textSecondary,
                                decoration: TextDecoration.lineThrough),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 70,
                          child: Text(
                            '₹${h.price.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                color: ErpColors.textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 52,
                          child: Text(
                            '$sign₹${h.change.abs().toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: col),
                          ),
                        ),
                      ]),
                    );
                  }),
                ]),
              ),
            ],
          ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════
//  LOTS TAB
//
//  Which dyed lots this material is holding, and how much is left on
//  each. A beam wants to come off ONE lot, so the largest single
//  balance matters as much as the total — 300 kg spread over six lots
//  of 50 will not carry a section that 300 kg on one lot would.
//
//  The lot total is deliberately not reconciled against stock. Yarn
//  that came in before lot tracking has no lot, so the sum of lot
//  balances is a floor on what is present, never the whole of it.
// ══════════════════════════════════════════════════════════════
class _LotsTab extends StatelessWidget {
  final RawMaterialDetailController c;
  const _LotsTab({required this.c});

  static String fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.lotsLoading.value && c.lots.isEmpty) {
        return Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.lotsError.value != null && c.lots.isEmpty) {
        return _EmptyTab(
            icon: Icons.error_outline_rounded, label: c.lotsError.value!);
      }

      final issuable = c.issuableLots;
      final largest = issuable.isEmpty
          ? 0.0
          : issuable
              .map((l) => l.balance)
              .reduce((a, b) => a > b ? a : b);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          _LotSummary(
            total: c.lotBalanceTotal,
            largest: largest,
            openCount: issuable.length,
          ),
          const SizedBox(height: 12),
          _OpenLotButton(c: c),
          const SizedBox(height: 12),
          if (c.lots.isEmpty)
            const _EmptyTab(
                icon: Icons.inventory_2_outlined,
                label: 'No lots recorded for this material')
          else
            ...c.lots.map((l) => _LotCard(lot: l)),
        ],
      );
    });
  }
}

class _LotSummary extends StatelessWidget {
  final double total;
  final double largest;
  final int openCount;
  const _LotSummary({
    required this.total,
    required this.largest,
    required this.openCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: _LotStat(
                  label: 'ON LOTS',
                  value: '${_LotsTab.fmt(total)} kg'),
            ),
            Expanded(
              child: _LotStat(
                  label: 'LARGEST SINGLE LOT',
                  value: '${_LotsTab.fmt(largest)} kg'),
            ),
            Expanded(
              child: _LotStat(label: 'OPEN LOTS', value: '$openCount'),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'A beam wants to come off one lot, so the largest single balance '
            'matters as much as the total. Yarn received before lot tracking '
            'has no lot, so this is a floor on what is present, not the whole '
            'of the stock.',
            style: TextStyle(
                fontSize: 10.5, color: ErpColors.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LotStat extends StatelessWidget {
  final String label;
  final String value;
  const _LotStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: ErpColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ErpColors.textPrimary)),
        ],
      );
}

class _LotCard extends StatelessWidget {
  final YarnLot lot;
  const _LotCard({required this.lot});

  @override
  Widget build(BuildContext context) {
    late final Color tone;
    switch (lot.status) {
      case 'quarantined':
        tone = ErpColors.warningAmber;
        break;
      case 'exhausted':
      case 'closed':
        tone = ErpColors.textMuted;
        break;
      default:
        tone = ErpColors.successGreen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(lot.lotNo,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(lot.status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: tone)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _LotStat(
                  label: 'BALANCE',
                  value: '${_LotsTab.fmt(lot.balance)} kg'),
            ),
            Expanded(
              child: _LotStat(
                  label: 'RECEIVED',
                  value: '${_LotsTab.fmt(lot.receivedQty)} kg'),
            ),
            Expanded(
              child: _LotStat(
                  label: 'DRAWN',
                  value: '${_LotsTab.fmt(lot.consumedQty)} kg'),
            ),
          ]),
          if (lot.shade.isNotEmpty ||
              lot.dyer.isNotEmpty ||
              lot.supplierName.isNotEmpty ||
              lot.receivedDate != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (lot.shade.isNotEmpty) 'Shade ${lot.shade}',
                if (lot.dyer.isNotEmpty) lot.dyer,
                if (lot.supplierName.isNotEmpty) lot.supplierName,
                if (lot.receivedDate != null)
                  DateFormat('dd MMM yyyy').format(lot.receivedDate!),
              ].join('  ·  '),
              style: TextStyle(
                  fontSize: 11, color: ErpColors.textSecondary),
            ),
          ],
          if (lot.remarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(lot.remarks,
                style: TextStyle(
                    fontSize: 11, color: ErpColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Opening a lot by hand covers yarn that was already on the rack when
/// lot tracking started — it has no inward row to hang off, and the
/// floor still needs it in the picker.
class _OpenLotButton extends StatelessWidget {
  final RawMaterialDetailController c;
  const _OpenLotButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openDialog(context),
        icon: Icon(Icons.add, size: 16, color: ErpColors.accentBlue),
        label: Text('Open a lot',
            style: TextStyle(
                color: ErpColors.accentBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: ErpColors.accentBlue),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final lotNo = TextEditingController();
    final qty = TextEditingController();
    final shade = TextEditingController();
    final dyer = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final ready = lotNo.text.trim().isNotEmpty &&
              (double.tryParse(qty.text.trim()) ?? 0) > 0;
          return AlertDialog(
            backgroundColor: ErpColors.bgSurface,
            title: const Text('Open a lot', style: TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Assigns stock this material already holds. The quantity '
                    'cannot exceed what is not yet on some other lot.',
                    style: TextStyle(
                        fontSize: 12, color: ErpColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lotNo,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Lot no. *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Quantity (kg) *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: shade,
                    decoration: const InputDecoration(
                        labelText: 'Shade', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dyer,
                    decoration: const InputDecoration(
                        labelText: 'Dyer', isDense: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (ready && !saving)
                    ? () async {
                        setLocal(() => saving = true);
                        final err = await c.createLot(
                          lotNo: lotNo.text,
                          quantity: double.parse(qty.text.trim()),
                          shade: shade.text,
                          dyer: dyer.text,
                        );
                        setLocal(() => saving = false);
                        if (err == null) {
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          Get.snackbar('Lot opened', lotNo.text.trim(),
                              backgroundColor: ErpColors.solidSuccess,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM);
                        } else {
                          Get.snackbar('Could not open the lot', err,
                              backgroundColor: ErpColors.solidError,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 6),
                              snackPosition: SnackPosition.BOTTOM);
                        }
                      }
                    : null,
                child: Text(saving ? 'Opening…' : 'Open lot'),
              ),
            ],
          );
        },
      ),
    );

    lotNo.dispose();
    qty.dispose();
    shade.dispose();
    dyer.dispose();
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Icon(icon, size: 30, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      Text(label,
          style: TextStyle(
              color: ErpColors.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _ErrorBody extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorBody({required this.msg, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_outlined,
            size: 48, color: ErpColors.textMuted),
        const SizedBox(height: 14),
        Text('Failed to load material',
            style: TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(msg,
            style: TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: retry,
          style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
          label: const Text('Retry',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}