import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/po_models.dart';
import '../services/api.dart';

// ══════════════════════════════════════════════════════════════════════════
//  MATERIAL INWARD
//  Controller + Page + helper widgets
//
//  Usage:
//    Get.to(() => MaterialInwardPage(), arguments: poModel);
//
//  Flow:
//    1. Page receives a POModel via Get.arguments
//    2. Shows only items with pendingQuantity > 0
//    3. User enters received qty (capped at pending) + optional remarks
//    4. User picks an inward date (default = today)
//    5. Submits to POST /inward-stock
//    6. Backend increments RawMaterial.stock + creates MaterialInward record
// ══════════════════════════════════════════════════════════════════════════


// ──────────────────────────────────────────────────────────────────────────
//  COLOURS  (matches ERP theme — replicate from theme.dart if needed)
// ──────────────────────────────────────────────────────────────────────────
class _C {
  static const navyDark      = Color(0xFF0D1B2A);
  static const navyMid       = Color(0xFF1B2B45);
  static const accentBlue    = Color(0xFF1D6FEB);
  static const successGreen  = Color(0xFF16A34A);
  static const warningAmber  = Color(0xFFD97706);
  static const errorRed      = Color(0xFFDC2626);
  static const bgBase        = Color(0xFFF1F3F8);
  static const bgSurface     = Color(0xFFFFFFFF);
  static const bgMuted       = Color(0xFFF7F8FC);
  static const borderLight   = Color(0xFFE2E6F0);
  static const borderMid     = Color(0xFFCBD5E1);
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted     = Color(0xFF94A3B8);
}


// ──────────────────────────────────────────────────────────────────────────
//  MODEL — per-row editing state
// ──────────────────────────────────────────────────────────────────────────
class InwardItemRow {
  final POItem poItem;
  final TextEditingController quantityCtrl;
  final TextEditingController remarksCtrl;
  final FocusNode qtyFocus;

  InwardItemRow(this.poItem)
      : quantityCtrl = TextEditingController(),
        remarksCtrl  = TextEditingController(),
        qtyFocus     = FocusNode();

  double get receivingQty =>
      double.tryParse(quantityCtrl.text.trim()) ?? 0.0;

  /// True when the typed value is greater than what is still pending.
  bool get isOverReceiving =>
      receivingQty > 0 && receivingQty > poItem.pendingQuantity;

  /// Fill the qty field with the full pending amount.
  void fillMax() {
    quantityCtrl.text = poItem.pendingQuantity.toStringAsFixed(
      poItem.pendingQuantity % 1 == 0 ? 0 : 2,
    );
  }

  void dispose() {
    quantityCtrl.dispose();
    remarksCtrl.dispose();
    qtyFocus.dispose();
  }
}


// ──────────────────────────────────────────────────────────────────────────
//  CONTROLLER
// ──────────────────────────────────────────────────────────────────────────
class MaterialInwardController extends GetxController {
  final POModel po;
  MaterialInwardController(this.po);

  late final List<InwardItemRow> rows;
  final isSubmitting  = false.obs;
  final inwardDate    = DateTime.now().obs;
  final hasAnyQty     = false.obs;  // enables submit button

  @override
  void onInit() {
    super.onInit();
    rows = po.items
        .where((i) => i.pendingQuantity > 0)
        .map((i) => InwardItemRow(i))
        .toList();

    // Listen to every qty field so we can enable/disable submit
    for (final row in rows) {
      row.quantityCtrl.addListener(_refreshHasAny);
    }
  }

  void _refreshHasAny() {
    hasAnyQty.value = rows.any((r) => r.receivingQty > 0);
  }

  void pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context:      context,
      initialDate:  inwardDate.value,
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _C.accentBlue,
            onPrimary: Colors.white,
            surface: _C.bgSurface,
            onSurface: _C.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) inwardDate.value = picked;
  }

  bool _validate() {
    // At least one positive qty
    if (!hasAnyQty.value) {
      _snack('Validation', 'Enter received quantity for at least one item.');
      return false;
    }
    // Over-receiving check
    for (final row in rows) {
      if (row.isOverReceiving) {
        _snack(
          'Over-Receipt',
          '${row.poItem.rawMaterial?.name ?? "Item"}: '
              'cannot receive ${row.receivingQty.toStringAsFixed(2)} — '
              'only ${row.poItem.pendingQuantity.toStringAsFixed(2)} pending.',
          isError: true,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> submit() async {
    if (!_validate()) return;
    try {
      isSubmitting.value = true;

      final itemPayload = rows
          .where((r) => r.receivingQty > 0)
          .map((r) => {
        'rawMaterial': r.poItem.rawMaterial!.id,
        'quantity':    r.receivingQty,
        'inwardDate':  inwardDate.value.toIso8601String(),
        'remarks':     r.remarksCtrl.text.trim(),
      })
          .toList();

      final res = await POApiService.dio.post(
        '/inward-stock',
        data: {'poId': po.id, 'items': itemPayload},
      );

      _snack(
        'Stock Updated ✓',
        res.data['message'] ?? 'Inward recorded successfully.',
      );
      Get.back(result: true); // pop and signal parent to refresh
    } catch (e) {
      final msg = (e is Exception) ? e.toString() : 'Failed to record inward.';
      _snack('Error', msg, isError: true);
    } finally {
      isSubmitting.value = false;
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(
      title, msg,
      backgroundColor: isError ? _C.errorRed : _C.successGreen,
      colorText:       Colors.white,
      snackPosition:   SnackPosition.BOTTOM,
      duration:        Duration(seconds: isError ? 4 : 3),
      margin:          const EdgeInsets.all(12),
      borderRadius:    8,
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
        color: Colors.white,
      ),
    );
  }

  @override
  void onClose() {
    for (final r in rows) r.dispose();
    super.onClose();
  }
}


// ══════════════════════════════════════════════════════════════════════════
//  PAGE
// ══════════════════════════════════════════════════════════════════════════
class MaterialInwardPage extends StatefulWidget {
  const MaterialInwardPage({super.key});
  @override
  State<MaterialInwardPage> createState() => _MaterialInwardPageState();
}

class _MaterialInwardPageState extends State<MaterialInwardPage> {
  late final MaterialInwardController _ctrl;

  @override
  void initState() {
    super.initState();
    final po = Get.arguments as POModel;
    _ctrl = Get.put(MaterialInwardController(po));
  }

  @override
  void dispose() {
    Get.delete<MaterialInwardController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_appBar()],
        body: _ctrl.rows.isEmpty ? _emptyState() : _body(),
      ),
      bottomNavigationBar: _ctrl.rows.isEmpty ? null : _footer(),
    );
  }

  // ── App bar ────────────────────────────────────────────────────
  Widget _appBar() => SliverAppBar(
    pinned:           true,
    expandedHeight:   140,
    backgroundColor:  _C.navyDark,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Get.back(),
    ),
    flexibleSpace: FlexibleSpaceBar(
      background: _POSummaryHeader(po: _ctrl.po),
    ),
  );

  // ── Scrollable body ────────────────────────────────────────────
  Widget _body() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _DatePickerRow(),
      const SizedBox(height: 20),
      _SectionLabel(label: 'ITEMS TO RECEIVE', count: _ctrl.rows.length),
      const SizedBox(height: 10),
      // One card per pending item
      ...List.generate(_ctrl.rows.length, (i) {
        final row = _ctrl.rows[i];
        return _ItemCard(row: row, onChanged: () => setState(() {}));
      }),
    ],
  );

  // ── Empty state ────────────────────────────────────────────────
  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _C.successGreen.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.inventory_2_outlined,
            size: 34, color: _C.successGreen),
      ),
      const SizedBox(height: 16),
      const Text('All items fully received',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: _C.textPrimary)),
      const SizedBox(height: 6),
      const Text('No pending quantity left on this PO.',
          style: TextStyle(fontSize: 13, color: _C.textSecondary)),
    ]),
  );

  // ── Footer submit bar ──────────────────────────────────────────
  Widget _footer() => Obx(() => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
    decoration: BoxDecoration(
      color: _C.bgSurface,
      border: const Border(top: BorderSide(color: _C.borderLight)),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 8, offset: const Offset(0, -2),
      )],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Summary pill — how many items will be received
      if (_ctrl.hasAnyQty.value)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _receivingSummary(),
        ),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: (_ctrl.hasAnyQty.value && !_ctrl.isSubmitting.value)
              ? _ctrl.submit
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.accentBlue,
            disabledBackgroundColor: _C.accentBlue.withOpacity(0.35),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: _ctrl.isSubmitting.value
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.move_to_inbox_rounded,
              size: 18, color: Colors.white),
          label: Text(
            _ctrl.isSubmitting.value
                ? 'Recording Inward…'
                : 'Confirm Stock Inward',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
      ),
    ]),
  ));

  Widget _receivingSummary() {
    final activeRows = _ctrl.rows.where((r) => r.receivingQty > 0).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.accentBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.accentBlue.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            size: 16, color: _C.accentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${activeRows.length} item${activeRows.length == 1 ? '' : 's'} '
                'will be received into stock',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _C.accentBlue),
          ),
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════════════

// ── PO summary in the expanded app bar ────────────────────────
class _POSummaryHeader extends StatelessWidget {
  final POModel po;
  const _POSummaryHeader({required this.po});

  @override
  Widget build(BuildContext context) {
    final statusColor = po.status == 'Completed'
        ? _C.successGreen
        : po.status == 'Partial'
        ? _C.warningAmber
        : _C.accentBlue;

    return Container(
      color: _C.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.move_to_inbox_rounded,
                size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            const Text('Stock Inward',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900, color: Colors.white)),
            const Spacer(),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                po.status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'PO #${po.poNo}  ·  ${po.supplier?.name ?? '-'}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}


// ── Date picker row ────────────────────────────────────────────
class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MaterialInwardController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'INWARD DATE'),
        const SizedBox(height: 8),
        Obx(() {
          final date = ctrl.inwardDate.value;
          return InkWell(
            onTap: () => ctrl.pickDate(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _C.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.borderLight),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: _C.accentBlue),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary),
                ),
                const Spacer(),
                const Text('Change',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.accentBlue,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }),
      ],
    );
  }
}


// ── Section label ──────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionLabel({required this.label, this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(
      label,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: _C.textSecondary),
    ),
    if (count != null) ...[
      const SizedBox(width: 8),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _C.accentBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _C.accentBlue),
        ),
      ),
    ],
  ]);
}


// ── Item card ──────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final InwardItemRow row;
  final VoidCallback onChanged;
  const _ItemCard({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isOver = row.isOverReceiving;
    final hasQty = row.receivingQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOver
              ? _C.errorRed
              : hasQty
              ? _C.accentBlue.withOpacity(0.4)
              : _C.borderLight,
          width: (isOver || hasQty) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: name + status badge ─────────────────
            Row(children: [
              Expanded(
                child: Text(
                  row.poItem.rawMaterial?.name ?? '-',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _C.textPrimary),
                ),
              ),
              if (hasQty && !isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${row.receivingQty.toStringAsFixed(row.receivingQty % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _C.successGreen),
                  ),
                ),
              if (isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OVER LIMIT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _C.errorRed),
                  ),
                ),
            ]),

            const SizedBox(height: 8),

            // ── Qty stats row ────────────────────────────────────
            Row(children: [
              _StatChip(
                  label: 'Ordered',
                  value: _fmt(row.poItem.quantity),
                  color: _C.textSecondary),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Received',
                  value: _fmt(row.poItem.receivedQuantity),
                  color: _C.warningAmber),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Pending',
                  value: _fmt(row.poItem.pendingQuantity),
                  color: _C.accentBlue),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1, color: _C.borderLight),
            const SizedBox(height: 12),

            // ── Quantity input ────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receiving Now',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _C.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller:  row.quantityCtrl,
                      focusNode:   row.qtyFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,3}')),
                      ],
                      onChanged: (_) => onChanged(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isOver ? _C.errorRed : _C.textPrimary),
                      decoration: InputDecoration(
                        filled:      true,
                        fillColor:   isOver
                            ? _C.errorRed.withOpacity(0.05)
                            : _C.bgMuted,
                        hintText:    '0',
                        hintStyle:   const TextStyle(
                            color: _C.textMuted, fontSize: 18),
                        suffixText:  row.poItem.rawMaterial?.unit ?? '',
                        suffixStyle: const TextStyle(
                            color: _C.textSecondary, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          const BorderSide(color: _C.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isOver ? _C.errorRed : _C.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isOver ? _C.errorRed : _C.accentBlue,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        errorText: isOver
                            ? 'Max: ${_fmt(row.poItem.pendingQuantity)}'
                            : null,
                        errorStyle: const TextStyle(
                            fontSize: 11, color: _C.errorRed),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Fill-max button
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(' ', // height spacer to align with label
                        style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          row.fillMax();
                          onChanged();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _C.accentBlue,
                          side: const BorderSide(color: _C.accentBlue),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.download_done_rounded,
                            size: 14),
                        label: const Text('Fill Max',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            // ── Remarks input (collapsible, shows when qty > 0) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: hasQty
                  ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextFormField(
                  controller: row.remarksCtrl,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 13, color: _C.textPrimary),
                  decoration: InputDecoration(
                    hintText:  'Remarks (optional)',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: _C.textMuted),
                    filled:    true,
                    fillColor: _C.bgMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: _C.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: _C.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _C.accentBlue, width: 1.5),
                    ),
                    prefixIcon: const Icon(
                        Icons.notes_rounded,
                        size: 16, color: _C.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
}


// ── Stat chip ──────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(fontSize: 9,
              fontWeight: FontWeight.w600, color: _C.textSecondary)),
    ]),
  );
}