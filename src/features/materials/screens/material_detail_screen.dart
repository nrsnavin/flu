import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/rawMaterial_controller.dart';
import '../models/RawMaterial.dart';


// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL DETAIL PAGE
//
//  FIX: was StatelessWidget with Get.put() at class field and
//       fetchMaterialDetail() called in build() → refetched
//       on every rebuild + stale controller.
//  FIX: displayed only stockMovements, not MaterialInward or
//       MaterialOutward collections.
//  FIX: no supplier display (crashed when supplier was null).
//  FIX: no Raise PO button.
//  FIX: deleted material called /delete-raw-material which
//       didn't exist in the backend.
// ══════════════════════════════════════════════════════════════

class RawMaterialDetailPage extends StatefulWidget {
  const RawMaterialDetailPage({super.key});

  @override
  State<RawMaterialDetailPage> createState() =>
      _RawMaterialDetailPageState();
}

class _RawMaterialDetailPageState extends State<RawMaterialDetailPage>
    with SingleTickerProviderStateMixin {
  late final MaterialDetailController c;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as String;
    Get.delete<MaterialDetailController>(force: true);
    c = Get.put(MaterialDetailController(id));
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchDetail);
        }
        final m = c.detail.value;
        if (m == null) {
          return _ErrorState(
              msg: 'Material not found', retry: c.fetchDetail);
        }
        return Column(children: [
          _HeroCard(m: m),
          _TabBar(tabs: _tabs),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _StockMovementsTab(movements: m.stockMovements),
                _InwardsTab(inwards: m.inwards),
                _OutwardsTab(outwards: m.outwards),
              ],
            ),
          ),
        ]);
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final m = c.detail.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m?.name ?? 'Material Detail',
              style: ErpTextStyles.pageTitle,
              overflow: TextOverflow.ellipsis,
            ),
            const Text('Raw Materials  ›  Detail',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        );
      }),
      actions: [
        // Raise PO
        Obx(() {
          final m = c.detail.value;
          if (m == null) return const SizedBox.shrink();
          return TextButton.icon(
            onPressed: () => _showRaisePOSheet(m),
            icon: const Icon(Icons.add_shopping_cart_outlined,
                size: 16, color: Colors.white),
            label: const Text('Raise PO',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          );
        }),
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetchDetail,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  void _showRaisePOSheet(RawMaterialDetail m) {
    Get.delete<RaisePOController>(force: true);
    final poc = Get.put(RaisePOController(
      materialId:        m.id,
      defaultSupplierId: m.supplier?.id,
      currentPrice:      m.price,
    ));

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              const Text('Raise Purchase Order',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ErpColors.textPrimary)),
              const SizedBox(height: 4),
              Text('${m.name}  •  ${m.category}',
                  style: const TextStyle(
                      color: ErpColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              // Supplier dropdown
              Obx(() {
                if (poc.isLoadingSup.value) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: ErpColors.accentBlue, strokeWidth: 2));
                }
                return DropdownButtonFormField<SupplierDropdownItem>(
                  value: poc.selectedSupplier.value,
                  decoration: ErpDecorations.formInput('Supplier *'),
                  style: ErpTextStyles.fieldValue,
                  items: poc.suppliers
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name),
                  ))
                      .toList(),
                  onChanged: (v) => poc.selectedSupplier.value = v,
                );
              }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: poc.qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: ErpTextStyles.fieldValue,
                    decoration: ErpDecorations.formInput('Quantity (kg) *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: poc.priceCtrl,
                    keyboardType: TextInputType.number,
                    style: ErpTextStyles.fieldValue,
                    decoration:
                    ErpDecorations.formInput('Price / kg *'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed:
                  poc.isSaving.value ? null : poc.submitPO,
                  icon: poc.isSaving.value
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                  label: Text(
                      poc.isSaving.value ? 'Creating…' : 'Create PO',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
              )),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final RawMaterialDetail m;
  const _HeroCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final isLow   = m.isLowStock;
    final stockPc = m.stockPercent;

    return Container(
      color: ErpColors.bgSurface,
      child: Column(children: [
        // Navy header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: ErpColors.navyDark,
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _catColor(m.category).withOpacity(0.22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _catColor(m.category).withOpacity(0.5)),
              ),
              child: Icon(Icons.grain_rounded,
                  size: 22, color: _catColor(m.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      _CatPill(m.category),
                      if (isLow) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: ErpColors.errorRed.withOpacity(0.25),
                            border: Border.all(
                                color: ErpColors.errorRed.withOpacity(0.6)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('⚠ LOW STOCK',
                              style: TextStyle(
                                  color: ErpColors.errorRed,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ]),
                  ]),
            ),
          ]),
        ),
        // Stats + stock bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(children: [
            Row(children: [
              _Stat('STOCK',   '${m.stock.toStringAsFixed(1)} kg',
                  isLow ? ErpColors.errorRed : ErpColors.successGreen),
              _vDiv(),
              _Stat('MIN STOCK', '${m.minStock.toStringAsFixed(1)} kg',
                  ErpColors.warningAmber),
              _vDiv(),
              _Stat('PRICE',   '₹${m.price.toStringAsFixed(0)}/kg',
                  ErpColors.accentBlue),
              _vDiv(),
              _Stat('CONSUMED', '${m.totalConsumption.toStringAsFixed(1)} kg',
                  ErpColors.textSecondary),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stockPc,
                minHeight: 6,
                backgroundColor: ErpColors.borderLight,
                valueColor: AlwaysStoppedAnimation(
                  isLow ? ErpColors.errorRed : ErpColors.successGreen,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (m.supplier != null) ...[
                  Row(children: [
                    const Icon(Icons.business_outlined,
                        size: 11, color: ErpColors.textMuted),
                    const SizedBox(width: 3),
                    Text(m.supplier!.name,
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ]),
                ] else
                  const SizedBox.shrink(),
                Text(
                  'Added ${DateFormat('dd MMM yyyy').format(m.createdAt)}',
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ]),
        ),
        const Divider(height: 1, color: ErpColors.borderLight),
      ]),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 32, color: ErpColors.borderLight);

  Color _catColor(String c) {
    switch (c) {
      case 'warp':      return const Color(0xFF1D6FEB);
      case 'weft':      return const Color(0xFF7C3AED);
      case 'covering':  return const Color(0xFF0891B2);
      case 'Rubber':    return const Color(0xFFD97706);
      case 'Chemicals': return const Color(0xFFDC2626);
      default:          return const Color(0xFF5A6A85);
    }
  }
}

class _CatPill extends StatelessWidget {
  final String cat;
  const _CatPill(this.cat);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFF1E3A5F),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(cat,
        style: const TextStyle(
            color: ErpColors.textOnDarkSub,
            fontSize: 9,
            fontWeight: FontWeight.w700)),
  );
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
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 0.4),
          textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  TAB BAR
// ══════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  final TabController tabs;
  const _TabBar({required this.tabs});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    child: TabBar(
      controller: tabs,
      labelColor: ErpColors.accentBlue,
      unselectedLabelColor: ErpColors.textSecondary,
      indicatorColor: ErpColors.accentBlue,
      indicatorWeight: 2,
      labelStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800),
      tabs: const [
        Tab(text: 'Movements'),
        Tab(text: 'Inwards'),
        Tab(text: 'Outwards'),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  STOCK MOVEMENTS TAB
// ══════════════════════════════════════════════════════════════
class _StockMovementsTab extends StatelessWidget {
  final List<StockMovement> movements;
  const _StockMovementsTab({required this.movements});

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return _TabEmpty('No stock movements recorded',
          Icons.swap_vert_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: movements.length,
      itemBuilder: (_, i) {
        final mv = movements[i];
        final isIn = mv.quantity >= 0;
        final color = isIn ? ErpColors.successGreen : ErpColors.errorRed;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIn
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 16, color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_movLabel(mv.type),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textPrimary)),
                    Text(
                      DateFormat('dd MMM yyyy').format(mv.date) +
                          (mv.orderNo != null ? '  •  Order #${mv.orderNo}' : ''),
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10),
                    ),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${isIn ? '+' : ''}${mv.quantity.toStringAsFixed(1)} kg',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
              ),
              Text('Bal: ${mv.balance.toStringAsFixed(1)}',
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 9)),
            ]),
          ]),
        );
      },
    );
  }

  String _movLabel(String type) {
    switch (type) {
      case 'ORDER_APPROVAL': return 'Order Approval';
      case 'PO_INWARD':      return 'PO Inward';
      case 'ADJUSTMENT':     return 'Adjustment';
      default:               return type;
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  INWARDS TAB
// ══════════════════════════════════════════════════════════════
class _InwardsTab extends StatelessWidget {
  final List<MaterialInward> inwards;
  const _InwardsTab({required this.inwards});

  @override
  Widget build(BuildContext context) {
    if (inwards.isEmpty) {
      return _TabEmpty('No inward records', Icons.download_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: inwards.length,
      itemBuilder: (_, i) {
        final iv = inwards[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border:
            Border.all(color: ErpColors.successGreen.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: ErpColors.successGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.download_rounded,
                  size: 16, color: ErpColors.successGreen),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '+${iv.quantity.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ErpColors.successGreen),
                      ),
                      if (iv.poNo != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: ErpColors.accentBlue.withOpacity(0.09),
                            border: Border.all(
                                color: ErpColors.accentBlue.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('PO #${iv.poNo}',
                              style: const TextStyle(
                                  color: ErpColors.accentBlue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(iv.inwardDate),
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10),
                    ),
                    if (iv.remarks != null)
                      Text(iv.remarks!,
                          style: const TextStyle(
                              color: ErpColors.textSecondary, fontSize: 10)),
                  ]),
            ),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  OUTWARDS TAB
// ══════════════════════════════════════════════════════════════
class _OutwardsTab extends StatelessWidget {
  final List<MaterialOutward> outwards;
  const _OutwardsTab({required this.outwards});

  @override
  Widget build(BuildContext context) {
    if (outwards.isEmpty) {
      return _TabEmpty('No outward records', Icons.upload_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: outwards.length,
      itemBuilder: (_, i) {
        final ov = outwards[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: ErpColors.errorRed.withOpacity(0.22)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_rounded,
                  size: 16, color: ErpColors.errorRed),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '−${ov.quantity.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ErpColors.errorRed),
                      ),
                      if (ov.cost != null) ...[
                        const SizedBox(width: 8),
                        Text('₹${ov.cost!.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(ov.outwardDate),
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10),
                    ),
                    if (ov.remarks != null)
                      Text(ov.remarks!,
                          style: const TextStyle(
                              color: ErpColors.textSecondary, fontSize: 10)),
                  ]),
            ),
          ]),
        );
      },
    );
  }
}

class _TabEmpty extends StatelessWidget {
  final String msg;
  final IconData icon;
  const _TabEmpty(this.msg, this.icon);
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: ErpColors.textMuted),
      const SizedBox(height: 10),
      Text(msg,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 13)),
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
      const Icon(Icons.error_outline,
          size: 40, color: ErpColors.textMuted),
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