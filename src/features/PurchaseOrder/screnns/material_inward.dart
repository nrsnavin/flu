import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/po_models.dart';
import '../services/theme.dart';
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


// ──────────────────────────────────────────────────────────────────────────
//  MODEL — per-row editing state
// ──────────────────────────────────────────────────────────────────────────
/// A supplier sending slightly more than ordered is normal — a full bag
/// instead of a part one, a roll that weighed heavy. The server takes it:
/// up to this fraction over the pending quantity no explanation is asked
/// for, and past it somebody has to say why. Mirrors
/// OVER_RECEIPT_TOLERANCE in api/supplier.js.
const double kOverReceiptTolerance = 0.10;

/// Mirrors MIN_EXCESS_REASON there.
const int kMinOverReceiptReason = 5;

class InwardItemRow {
  final POItem poItem;
  final TextEditingController quantityCtrl;
  final TextEditingController remarksCtrl;

  /// The dye lot this delivery came in as. Optional — but without it the
  /// yarn cannot be issued to a warping batch by lot later, which is the
  /// whole point of lot tracking, and the gate is exactly where the lot
  /// tag is still in somebody's hand.
  final TextEditingController lotNoCtrl;
  final TextEditingController shadeCtrl;

  final FocusNode qtyFocus;

  InwardItemRow(this.poItem)
      : quantityCtrl = TextEditingController(),
        remarksCtrl  = TextEditingController(),
        lotNoCtrl    = TextEditingController(),
        shadeCtrl    = TextEditingController(),
        qtyFocus     = FocusNode();

  double get receivingQty =>
      double.tryParse(quantityCtrl.text.trim()) ?? 0.0;

  /// How much of this is over what the line still had pending.
  double get overBy {
    final v = receivingQty - poItem.pendingQuantity;
    return v > 0 ? v : 0;
  }

  /// Within the tolerance, an over-receipt goes through unremarked.
  bool get isOverReceiving => overBy > 0;

  bool get needsOverReason =>
      overBy > poItem.pendingQuantity * kOverReceiptTolerance;

  /// Fill the qty field with the full pending amount.
  void fillMax() {
    quantityCtrl.text = poItem.pendingQuantity.toStringAsFixed(
      poItem.pendingQuantity % 1 == 0 ? 0 : 2,
    );
  }

  void dispose() {
    quantityCtrl.dispose();
    remarksCtrl.dispose();
    lotNoCtrl.dispose();
    shadeCtrl.dispose();
    qtyFocus.dispose();
  }
}


// ──────────────────────────────────────────────────────────────────────────
//  CONTROLLER
// ──────────────────────────────────────────────────────────────────────────
/// The server's own message where it sent one.
String _serverMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final m = data['message']?.toString();
    if (m != null && m.trim().isNotEmpty) return m;
  }
  if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
    return 'Your session has expired. Sign in again, then re-enter this '
        'receipt — nothing has been recorded.';
  }
  if (e.response != null) {
    return 'The server refused that (${e.response!.statusCode}). Nothing '
        'has been recorded.';
  }
  // No response: the request may or may not have arrived. The
  // idempotency key above means retrying is safe either way, and
  // saying so is the difference between a retry and a phone call.
  return 'Could not reach the server. Nothing was recorded here — it is '
      'safe to submit again.';
}

class MaterialInwardController extends GetxController {
  final POModel po;
  MaterialInwardController(this.po);

  late final List<InwardItemRow> rows;
  final isSubmitting  = false.obs;
  final inwardDate    = DateTime.now().obs;
  final hasAnyQty     = false.obs;  // enables submit button

  /// One reason for the whole receipt, which is how the server reads it
  /// when a row carries none of its own.
  final excessReasonCtrl = TextEditingController();
  final excessReason     = ''.obs;

  /// Any row over the pending quantity at all — the yarn still goes in,
  /// but the person receiving should see that it is over.
  bool get anyOverReceipt => rows.any((r) => r.isOverReceiving);

  /// Any row far enough over that the server will want a reason.
  bool get needsOverReason => rows.any((r) => r.needsOverReason);

  bool get reasonOk =>
      excessReason.value.trim().length >= kMinOverReceiptReason;

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
    excessReasonCtrl.addListener(() {
      excessReason.value = excessReasonCtrl.text;
    });
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
      builder: erpPickerBuilder,
    );
    if (picked != null) inwardDate.value = picked;
  }

  bool _validate() {
    // At least one positive qty
    if (!hasAnyQty.value) {
      _snack('Validation', 'Enter received quantity for at least one item.');
      return false;
    }
    // An over-receipt is NOT refused here. The server takes a delivery
    // that runs over — refusing it locally only pushed the difference
    // into a stock adjustment, which credits the same yarn while losing
    // the link to the PO that brought it in. Past the tolerance it wants
    // a reason, and that is what is checked.
    if (needsOverReason && !reasonOk) {
      _snack(
        'Reason needed',
        'Receiving more than ${(kOverReceiptTolerance * 100).round()}% over the '
            'pending quantity needs a reason of at least '
            '$kMinOverReceiptReason characters.',
        isError: true,
      );
      return false;
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
        // A row carrying a lot number also opens a YarnLot bucket, so
        // this yarn can be issued to a warping batch by lot later on.
        if (r.lotNoCtrl.text.trim().isNotEmpty)
          'lotNo': r.lotNoCtrl.text.trim(),
        if (r.shadeCtrl.text.trim().isNotEmpty)
          'shade': r.shadeCtrl.text.trim(),
      })
          .toList();

      final res = await POApiService.dio.post(
        '/inward-stock',
        data: {
          'poId': po.id,
          'items': itemPayload,
          if (needsOverReason) 'excessReason': excessReasonCtrl.text.trim(),
        },
      );

      _snack(
        'Stock Updated ✓',
        res.data['message'] ?? 'Inward recorded successfully.',
      );
      Get.back(result: true); // pop and signal parent to refresh
    } on DioException catch (e) {
      // The server's words, not Dio's. A receipt is refused for real
      // business reasons — over the tolerance, PO already closed, a
      // material not on this PO — and each names what to do next.
      // `e.toString()` on a DioException prints the request dump,
      // which told the operator nothing and hid all of them.
      _snack('Could not record inward', _serverMessage(e), isError: true);
    } catch (e) {
      _snack('Could not record inward',
          'Something went wrong recording that: $e', isError: true);
    } finally {
      isSubmitting.value = false;
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(
      title, msg,
      backgroundColor: isError ? ErpColors.errorRed : ErpColors.successGreen,
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
    for (final r in rows) {
      r.dispose();
    }
    excessReasonCtrl.dispose();
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
  MaterialInwardController? _ctrl;

  @override
  void initState() {
    super.initState();
    // Guard the route argument — navigating here without a POModel
    // (hot reload, bad deep link) used to crash on the cast. Bail
    // back to the previous screen instead.
    final arg = Get.arguments;
    if (arg is POModel) {
      _ctrl = Get.put(MaterialInwardController(arg));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar('Error', 'No purchase order supplied');
      });
    }
  }

  @override
  void dispose() {
    if (_ctrl != null) Get.delete<MaterialInwardController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Argument guard failed in initState — render a blank scaffold
    // for the single frame before the scheduled Get.back() fires.
    if (_ctrl == null) {
      return Scaffold(backgroundColor: ErpColors.bgBase);
    }
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_appBar()],
        body: _ctrl!.rows.isEmpty ? _emptyState() : _body(),
      ),
      bottomNavigationBar: _ctrl!.rows.isEmpty ? null : _footer(),
    );
  }

  // ── App bar ────────────────────────────────────────────────────
  Widget _appBar() => SliverAppBar(
    pinned:           true,
    expandedHeight:   140,
    backgroundColor:  ErpColors.navyDark,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: () => Get.back(),
    ),
    flexibleSpace: FlexibleSpaceBar(
      background: _POSummaryHeader(po: _ctrl!.po),
    ),
  );

  // ── Scrollable body ────────────────────────────────────────────
  Widget _body() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _DatePickerRow(),
      const SizedBox(height: 20),
      _SectionLabel(label: 'ITEMS TO RECEIVE', count: _ctrl!.rows.length),
      const SizedBox(height: 10),
      // One card per pending item
      ...List.generate(_ctrl!.rows.length, (i) {
        final row = _ctrl!.rows[i];
        return _ItemCard(row: row, onChanged: () => setState(() {}));
      }),
      if (_ctrl!.needsOverReason) _overReasonCard(),
    ],
  );

  /// One reason covers the whole receipt, which is how the server reads
  /// it when a row carries none of its own.
  Widget _overReasonCard() => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.warningAmber.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ErpColors.warningAmber.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: ErpColors.warningAmber),
              const SizedBox(width: 6),
              Text(
                'Why more than ${(kOverReceiptTolerance * 100).round()}% over?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ErpColors.warningAmber),
              ),
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ctrl!.excessReasonCtrl,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13, color: ErpColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    'e.g. supplier sent full bags; the extra is against the next order',
                hintStyle:
                    TextStyle(fontSize: 12.5, color: ErpColors.textMuted),
                filled: true,
                fillColor: ErpColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ErpColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ErpColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: ErpColors.warningAmber, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kept on the inward row, against the PO it came in on. '
              'At least $kMinOverReceiptReason characters.',
              style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
            ),
          ],
        ),
      );

  // ── Empty state ────────────────────────────────────────────────
  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: ErpColors.successGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.inventory_2_outlined,
            size: 34, color: ErpColors.successGreen),
      ),
      const SizedBox(height: 16),
      Text('All items fully received',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
      const SizedBox(height: 6),
      Text('No pending quantity left on this PO.',
          style: TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
    ]),
  );

  // ── Footer submit bar ──────────────────────────────────────────
  Widget _footer() => Obx(() => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: Border(top: BorderSide(color: ErpColors.borderLight)),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8, offset: const Offset(0, -2),
      )],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Summary pill — how many items will be received
      if (_ctrl!.hasAnyQty.value)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _receivingSummary(),
        ),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          // Disabled until the reason is real when one is required, so
          // the floor finds out before filling the whole sheet in.
          onPressed: (_ctrl!.hasAnyQty.value &&
                  !_ctrl!.isSubmitting.value &&
                  (!_ctrl!.needsOverReason || _ctrl!.reasonOk))
              ? _ctrl!.submit
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            disabledBackgroundColor: ErpColors.accentBlue.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: _ctrl!.isSubmitting.value
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.move_to_inbox_rounded,
              size: 18, color: Colors.white),
          label: Text(
            _ctrl!.isSubmitting.value
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
    final activeRows = _ctrl!.rows.where((r) => r.receivingQty > 0).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ErpColors.accentBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.accentBlue.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 16, color: ErpColors.accentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${activeRows.length} item${activeRows.length == 1 ? '' : 's'} '
                'will be received into stock',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: ErpColors.accentBlue),
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
        ? ErpColors.successGreen
        : po.status == 'Partial'
        ? ErpColors.warningAmber
        : ErpColors.accentBlue;

    return Container(
      color: ErpColors.navyDark,
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
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
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
                color: ErpColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: ErpColors.accentBlue),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary),
                ),
                const Spacer(),
                Text('Change',
                    style: TextStyle(
                        fontSize: 12,
                        color: ErpColors.accentBlue,
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
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: ErpColors.textSecondary),
    ),
    if (count != null) ...[
      const SizedBox(width: 8),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: ErpColors.accentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$count',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ErpColors.accentBlue),
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
    final needsReason = row.needsOverReason;
    final hasQty = row.receivingQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          // Amber, not red: an over-receipt is accepted, not rejected.
          color: isOver
              ? ErpColors.warningAmber
              : hasQty
              ? ErpColors.accentBlue.withValues(alpha: 0.4)
              : ErpColors.borderLight,
          width: (isOver || hasQty) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary),
                ),
              ),
              if (hasQty && !isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${row.receivingQty.toStringAsFixed(row.receivingQty % 1 == 0 ? 0 : 2)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.successGreen),
                  ),
                ),
              if (isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'OVER LIMIT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: ErpColors.errorRed),
                  ),
                ),
            ]),

            const SizedBox(height: 8),

            // ── Qty stats row ────────────────────────────────────
            Row(children: [
              _StatChip(
                  label: 'Ordered',
                  value: _fmt(row.poItem.quantity),
                  color: ErpColors.textSecondary),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Received',
                  value: _fmt(row.poItem.receivedQuantity),
                  color: ErpColors.warningAmber),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Pending',
                  value: _fmt(row.poItem.pendingQuantity),
                  color: ErpColors.accentBlue),
            ]),

            const SizedBox(height: 12),
            Divider(height: 1, color: ErpColors.borderLight),
            const SizedBox(height: 12),

            // ── Quantity input ────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receiving Now',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ErpColors.textSecondary)),
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
                          color: isOver ? ErpColors.errorRed : ErpColors.textPrimary),
                      decoration: InputDecoration(
                        filled:      true,
                        fillColor:   isOver
                            ? ErpColors.errorRed.withValues(alpha: 0.05)
                            : ErpColors.bgMuted,
                        hintText:    '0',
                        hintStyle:   TextStyle(
                            color: ErpColors.textMuted, fontSize: 18),
                        suffixText:  row.poItem.rawMaterial?.unit ?? '',
                        suffixStyle: TextStyle(
                            color: ErpColors.textSecondary, fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          BorderSide(color: ErpColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isOver ? ErpColors.errorRed : ErpColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isOver ? ErpColors.errorRed : ErpColors.accentBlue,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        errorText: isOver
                            ? 'Max: ${_fmt(row.poItem.pendingQuantity)}'
                            : null,
                        errorStyle: TextStyle(
                            fontSize: 11, color: ErpColors.errorRed),
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
                          foregroundColor: ErpColors.accentBlue,
                          side: BorderSide(color: ErpColors.accentBlue),
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

            // ── Over-receipt note ────────────────────────────────
            if (isOver)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(
                    needsReason
                        ? Icons.warning_amber_rounded
                        : Icons.trending_up_rounded,
                    size: 14,
                    color: ErpColors.warningAmber,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      needsReason
                          ? '${_fmt(row.overBy)} over the pending quantity — needs a reason below'
                          : '${_fmt(row.overBy)} over the pending quantity, within the '
                              '${(kOverReceiptTolerance * 100).round()}% tolerance',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ErpColors.warningAmber,
                        fontWeight:
                            needsReason ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ),

            // ── Dye lot (collapsible, shows when qty > 0) ────────
            //
            // Asked for at the gate because that is where the lot tag is
            // still in somebody's hand. Skipping it does not block the
            // receipt — it means this yarn cannot be issued to a warping
            // batch by lot later, which is the whole point of tracking.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: hasQty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: row.lotNoCtrl,
                            textCapitalization:
                                TextCapitalization.characters,
                            style: TextStyle(
                                fontSize: 13, color: ErpColors.textPrimary),
                            onChanged: (_) => onChanged(),
                            decoration: _lotDecoration(
                              hint: 'Lot no.',
                              icon: Icons.qr_code_2_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: row.shadeCtrl,
                            style: TextStyle(
                                fontSize: 13, color: ErpColors.textPrimary),
                            decoration: _lotDecoration(
                              hint: 'Shade',
                              icon: Icons.palette_outlined,
                            ),
                          ),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Remarks input (collapsible, shows when qty > 0) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: hasQty
                  ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextFormField(
                  controller: row.remarksCtrl,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 13, color: ErpColors.textPrimary),
                  decoration: InputDecoration(
                    hintText:  'Remarks (optional)',
                    hintStyle: TextStyle(
                        fontSize: 13, color: ErpColors.textMuted),
                    filled:    true,
                    fillColor: ErpColors.bgMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      BorderSide(color: ErpColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      BorderSide(color: ErpColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: ErpColors.accentBlue, width: 1.5),
                    ),
                    prefixIcon: Icon(
                        Icons.notes_rounded,
                        size: 16, color: ErpColors.textMuted),
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

  InputDecoration _lotDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: ErpColors.textMuted),
      filled: true,
      fillColor: ErpColors.bgMuted,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ErpColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ErpColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ErpColors.accentBlue, width: 1.5),
      ),
      prefixIcon: Icon(icon, size: 16, color: ErpColors.textMuted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
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
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.w600, color: ErpColors.textSecondary)),
    ]),
  );
}