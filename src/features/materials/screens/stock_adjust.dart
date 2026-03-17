// ══════════════════════════════════════════════════════════════
//  STOCK ADJUST PAGE
//  File: lib/src/features/materials/screens/stock_adjust_page.dart
//
//  Features:
//    • Lists every raw material with current stock
//    • Per-row: +/− stepper buttons  +  direct type-in field
//    • New-stock preview updates live as you type
//    • LOW / CRITICAL badges on items at or below minStock
//    • Search bar  +  category filter chips
//    • "Changed only" toggle to focus on pending edits
//    • Sticky summary bar: items changed · total in · total out
//    • Global reason field for the whole batch
//    • Confirm bottom sheet before submit
//    • POST /materials/bulk-adjust-stock  →  success result screen
//    • Auto-refreshes RawMaterialListController on success
//    • History button → StockAdjustHistoryPage (all past STOCK_ADJUST records)
//    • Zero Obx — all reactive widgets use StatefulWidget + ever()
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/stockAdjustController.dart';
import 'adjust_screen.dart';



// ── Palette (matches app dark theme) ──────────────────────────
const _bg     = Color(0xFF060D18);
const _s1     = Color(0xFF0B1626);
const _s2     = Color(0xFF0F1F33);
const _s3     = Color(0xFF162540);
const _bdr    = Color(0xFF1A2E4A);
const _blue   = Color(0xFF2563EB);
const _blueLt = Color(0xFF60A5FA);
const _green  = Color(0xFF10B981);
const _greenLt= Color(0xFF34D399);
const _amber  = Color(0xFFF59E0B);
const _amberLt= Color(0xFFFBBF24);
const _red    = Color(0xFFEF4444);
const _redLt  = Color(0xFFFCA5A5);
const _purple = Color(0xFF8B5CF6);
const _purpLt = Color(0xFFC4B5FD);
const _tp     = Color(0xFFF0F6FF);
const _ts     = Color(0xFF8BA4C2);
const _tm     = Color(0xFF3D5470);

// Category accent colours
Color _catColor(String cat) => switch (cat.toLowerCase()) {
  'warp'      => const Color(0xFF3B82F6),
  'weft'      => const Color(0xFF8B5CF6),
  'covering'  => const Color(0xFF14B8A6),
  'rubber'    => const Color(0xFFF59E0B),
  'chemicals' => const Color(0xFFEF4444),
  _           => const Color(0xFF6B7280),
};

String _qty(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

// ══════════════════════════════════════════════════════════════
//  ENTRY POINT
// ══════════════════════════════════════════════════════════════
class StockAdjustPage extends StatefulWidget {
  const StockAdjustPage({super.key});
  @override State<StockAdjustPage> createState() => _StockAdjustPageState();
}

class _StockAdjustPageState extends State<StockAdjustPage> {
  late final StockAdjustController c;

  @override
  void initState() {
    super.initState();
    Get.delete<StockAdjustController>(force: true);
    c = Get.put(StockAdjustController());

    // Rebuild on any state change
    ever(c.isLoading,      (_) { if (mounted) setState(() {}); });
    ever(c.loadError,      (_) { if (mounted) setState(() {}); });
    ever(c.displayItems,   (_) { if (mounted) setState(() {}); });
    ever(c.isSubmitting,   (_) { if (mounted) setState(() {}); });
    ever(c.submitDone,     (_) { if (mounted) setState(() {}); });
    ever(c.results,        (_) { if (mounted) setState(() {}); });
    ever(c.filterCategory, (_) { if (mounted) setState(() {}); });
    ever(c.filterChanged,  (_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _TopBar(c: c),
        _FilterBar(c: c),
        if (c.isLoading.value)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
        else if (c.loadError.value != null)
          Expanded(child: _ErrorState(msg: c.loadError.value!, onRetry: c.fetchMaterials))
        else if (c.submitDone.value)
            Expanded(child: _ResultsScreen(c: c))
          else ...[
              Expanded(child: _MaterialList(c: c)),
              _SummaryBar(c: c),
            ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TOP BAR
// ══════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final StockAdjustController c;
  const _TopBar({required this.c});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _s1,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 12),
      child: Row(children: [
        _IBtn(Icons.arrow_back_ios_new_rounded, Get.back),
        const SizedBox(width: 12),
        const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stock Adjustment',
              style: TextStyle(color: _tp, fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Adjust all materials · bulk update',
              style: TextStyle(color: _tm, fontSize: 10)),
        ])),
        // Reset all
        _IBtn(Icons.restart_alt_rounded, () {
          showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: _s2,
              title: const Text('Reset All?',
                  style: TextStyle(color: _tp, fontSize: 14)),
              content: const Text('All adjustments will be cleared.',
                  style: TextStyle(color: _ts, fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _amber.withOpacity(0.4))),
              actions: [
                TextButton(onPressed: Get.back,
                    child: const Text('Cancel', style: TextStyle(color: _ts))),
                TextButton(onPressed: () { Get.back(); c.resetAll(); },
                    child: const Text('Reset', style: TextStyle(
                        color: _amber, fontWeight: FontWeight.w800))),
              ]));
        }),
        const SizedBox(width: 6),
        // History — view all past STOCK_ADJUST movements
        _IBtn(Icons.history_rounded, () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const StockAdjustHistoryPage(),
          ));
        }),
        const SizedBox(width: 6),
        _IBtn(Icons.refresh_rounded, c.fetchMaterials),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  FILTER BAR  (search + categories + changed-only toggle)
// ══════════════════════════════════════════════════════════════
class _FilterBar extends StatefulWidget {
  final StockAdjustController c;
  const _FilterBar({required this.c});
  @override State<_FilterBar> createState() => _FilterBarState();
}
class _FilterBarState extends State<_FilterBar> {
  StockAdjustController get c => widget.c;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    ever(c.filterCategory, (_) { if (mounted) setState(() {}); });
    ever(c.filterChanged,  (_) { if (mounted) setState(() {}); });
  }
  @override void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    color: _s1,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Column(children: [
      // Search
      Container(
        height: 38,
        decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr)),
        child: TextField(
            controller: _search,
            style: const TextStyle(color: _tp, fontSize: 12),
            decoration: const InputDecoration(
                hintText: 'Search material name…',
                hintStyle: TextStyle(color: _tm, fontSize: 11),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: _tm),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9)),
            onChanged: c.setSearch),
      ),
      const SizedBox(height: 8),
      // Category chips + changed-only toggle
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Changed-only pill
          GestureDetector(
              onTap: () => c.setChangedOnly(!c.filterChanged.value),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: c.filterChanged.value
                        ? _amber.withOpacity(0.18) : _s2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.filterChanged.value
                        ? _amber.withOpacity(0.6) : _bdr)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 11,
                      color: c.filterChanged.value ? _amberLt : _ts),
                  const SizedBox(width: 4),
                  Text('Changed only', style: TextStyle(
                      color: c.filterChanged.value ? _amberLt : _ts,
                      fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              )),
          // Category chips
          ...c.categories.map((cat) {
            final on = c.filterCategory.value == cat;
            final cc = cat == 'All' ? _blue : _catColor(cat);
            return GestureDetector(
                onTap: () => c.setCategory(cat),
                child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: on ? cc.withOpacity(0.18) : _s2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on ? cc.withOpacity(0.6) : _bdr)),
                    child: Text(cat, style: TextStyle(
                        color: on ? Color.lerp(cc, Colors.white, 0.3)! : _ts,
                        fontSize: 10, fontWeight: FontWeight.w700))));
          }),
        ]),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  MATERIAL LIST
// ══════════════════════════════════════════════════════════════
class _MaterialList extends StatelessWidget {
  final StockAdjustController c;
  const _MaterialList({required this.c});
  @override
  Widget build(BuildContext context) {
    if (c.displayItems.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('📦', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(c.filterChanged.value
            ? 'No adjustments yet — start editing rows below'
            : 'No materials match your filter',
            style: const TextStyle(color: _ts, fontSize: 12)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      itemCount: c.displayItems.length,
      itemBuilder: (_, i) => _MaterialRow(item: c.displayItems[i], c: c),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MATERIAL ROW  — the core editing widget
// ══════════════════════════════════════════════════════════════
class _MaterialRow extends StatefulWidget {
  final StockAdjustItem item;
  final StockAdjustController c;
  const _MaterialRow({required this.item, required this.c, Key? key})
      : super(key: key);
  @override State<_MaterialRow> createState() => _MaterialRowState();
}
class _MaterialRowState extends State<_MaterialRow> {
  StockAdjustItem get item => widget.item;
  StockAdjustController get c => widget.c;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cc       = _catColor(item.category);
    final hasChange = item.hasChange;
    final newStock  = item.newStock;
    final isLow     = item.isLowStock;
    final willBeLow = item.willBeLowAfter && !isLow && hasChange;
    final willFix   = isLow && hasChange && newStock > item.minStock;

    final borderColor = hasChange
        ? (item.adjustment > 0 ? _green.withOpacity(0.5) : _red.withOpacity(0.5))
        : _bdr;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: _s2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: Column(children: [
        // ── Header row ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            // Category dot
            Container(width: 6, height: 36,
                decoration: BoxDecoration(
                    color: cc, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 10),
            // Name + meta
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item.name, style: const TextStyle(
                    color: _tp, fontSize: 13, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isLow && !willFix)
                  _Badge('LOW', _red),
                if (willFix)
                  _Badge('FIXED ✓', _green),
                if (willBeLow)
                  _Badge('LOW AFTER', _amber),
              ]),
              const SizedBox(height: 2),
              Text('${item.category}  ·  Min: ${_qty(item.minStock)} kg',
                  style: const TextStyle(color: _ts, fontSize: 10)),
            ])),
            const SizedBox(width: 8),
            // Current → new
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_qty(item.currentStock),
                  style: const TextStyle(color: _ts, fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _ts)),
              Text(_qty(newStock), style: TextStyle(
                  color: hasChange
                      ? (item.adjustment > 0 ? _greenLt : _redLt) : _tp,
                  fontSize: 15, fontWeight: FontWeight.w900)),
              Text('kg', style: const TextStyle(color: _tm, fontSize: 9)),
            ]),
          ]),
        ),

        // ── Adjust controls ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            // Decrement −10
            _StepBtn(Icons.remove_rounded, _red, () {
              c.decrement(item.id, 10);
              setState(() {});
            }),
            const SizedBox(width: 6),
            // Decrement −1
            _StepBtn(Icons.exposure_minus_1_rounded, _redLt, () {
              c.decrement(item.id, 1);
              setState(() {});
            }),
            const SizedBox(width: 8),
            // Text input
            Expanded(child: _AdjTextField(item: item, c: c,
                onChanged: () => setState(() {}))),
            const SizedBox(width: 8),
            // Increment +1
            _StepBtn(Icons.exposure_plus_1_rounded, _greenLt, () {
              c.increment(item.id, 1);
              setState(() {});
            }),
            const SizedBox(width: 6),
            // Increment +10
            _StepBtn(Icons.add_rounded, _green, () {
              c.increment(item.id, 10);
              setState(() {});
            }),
            if (hasChange) ...[
              const SizedBox(width: 6),
              // Reset this item
              GestureDetector(
                  onTap: () { c.resetItem(item.id); setState(() {}); },
                  child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: _s3,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _bdr)),
                      child: const Icon(Icons.close_rounded, size: 14, color: _ts))),
            ],
          ]),
        ),

        // ── Reason field (expanded when item has a change) ────
        if (hasChange) ...[
          const Divider(height: 1, color: _bdr),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _ReasonTextField(item: item, c: c)),
        ],
      ]),
    );
  }
}

// ── Adjustment text field ──────────────────────────────────────
class _AdjTextField extends StatefulWidget {
  final StockAdjustItem item;
  final StockAdjustController c;
  final VoidCallback onChanged;
  const _AdjTextField({required this.item, required this.c, required this.onChanged});
  @override State<_AdjTextField> createState() => _AdjTextFieldState();
}
class _AdjTextFieldState extends State<_AdjTextField> {
  @override
  Widget build(BuildContext context) {
    final ctrl = widget.c.adjCtrl(widget.item.id);
    final adj  = widget.item.adjustment;
    final Color textColor = adj > 0 ? _greenLt : adj < 0 ? _redLt : _ts;
    return Container(
      height: 38,
      decoration: BoxDecoration(
          color: _s3, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: adj != 0 ? textColor.withOpacity(0.4) : _bdr)),
      child: Center(child: TextField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
        ],
        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
            hintText: '±0',
            hintStyle: TextStyle(color: _tm, fontSize: 13),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero),
        onChanged: (v) {
          widget.c.setAdjustment(widget.item.id, v);
          widget.onChanged();
        },
      )),
    );
  }
}

// ── Reason text field ──────────────────────────────────────────
class _ReasonTextField extends StatelessWidget {
  final StockAdjustItem item;
  final StockAdjustController c;
  const _ReasonTextField({required this.item, required this.c});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.notes_rounded, size: 13, color: _tm),
      const SizedBox(width: 6),
      Expanded(child: TextField(
        controller: c.reasCtrl(item.id),
        style: const TextStyle(color: _ts, fontSize: 11),
        decoration: const InputDecoration(
            hintText: 'Reason (optional — overrides global reason)',
            hintStyle: TextStyle(color: _tm, fontSize: 10),
            border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.zero),
        onChanged: (v) => c.setReason(item.id, v),
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  STICKY SUMMARY BAR + SUBMIT
// ══════════════════════════════════════════════════════════════
class _SummaryBar extends StatefulWidget {
  final StockAdjustController c;
  const _SummaryBar({required this.c});
  @override State<_SummaryBar> createState() => _SummaryBarState();
}
class _SummaryBarState extends State<_SummaryBar> {
  StockAdjustController get c => widget.c;
  @override void initState() {
    super.initState();
    ever(c.displayItems,   (_) { if (mounted) setState(() {}); });
    ever(c.isSubmitting,   (_) { if (mounted) setState(() {}); });
    ever(c.submitError,    (_) { if (mounted) setState(() {}); });
  }
  @override
  Widget build(BuildContext context) {
    final changed = c.changedCount;
    final increase = c.totalIncrease;
    final decrease = c.totalDecrease;
    final canSubmit = changed > 0 && !c.isSubmitting.value;

    return Container(
      decoration: BoxDecoration(
          color: _s1,
          border: const Border(top: BorderSide(color: _bdr)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Stats row
          if (changed > 0) ...[
            Row(children: [
              _SumStat('$changed', 'items changed', _amber),
              const SizedBox(width: 8),
              if (increase > 0) _SumStat('+${_qty(increase)} kg', 'total in', _green),
              if (increase > 0) const SizedBox(width: 8),
              if (decrease > 0) _SumStat('−${_qty(decrease)} kg', 'total out', _red),
            ]),
            const SizedBox(height: 8),
            // Global reason
            Container(
              decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bdr)),
              child: Row(children: [
                const Padding(padding: EdgeInsets.all(10),
                    child: Icon(Icons.edit_note_rounded, size: 16, color: _tm)),
                Expanded(child: TextField(
                  controller: c.globalReasonCtrl,
                  style: const TextStyle(color: _tp, fontSize: 12),
                  decoration: const InputDecoration(
                      hintText: 'Global reason for batch',
                      hintStyle: TextStyle(color: _tm, fontSize: 11),
                      border: InputBorder.none, isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10)),
                )),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          // Error
          if (c.submitError.value != null)
            Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Text('⚠️ ${c.submitError.value}',
                    style: const TextStyle(color: _redLt, fontSize: 11))),
          // Submit button
          GestureDetector(
            onTap: canSubmit ? () => _confirmSheet(context) : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                  color: canSubmit ? _green.withOpacity(0.18) : _s3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: canSubmit ? _green.withOpacity(0.5) : _bdr)),
              child: Center(child: c.isSubmitting.value
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _green, strokeWidth: 2))
                  : Text(
                  changed == 0
                      ? 'No changes to apply'
                      : '✅ Update $changed Material${changed == 1 ? "" : "s"}',
                  style: TextStyle(
                      color: canSubmit ? _greenLt : _tm,
                      fontSize: 14, fontWeight: FontWeight.w900))),
            ),
          ),
        ]),
      )),
    );
  }

  void _confirmSheet(BuildContext context) {
    final changed = c.changedItems;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                  color: _s1,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                // Handle
                Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: _bdr, borderRadius: BorderRadius.circular(2))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(children: [
                      const Expanded(child: Text('Confirm Stock Update',
                          style: TextStyle(color: _tp, fontSize: 16, fontWeight: FontWeight.w800))),
                      Text('${changed.length} items',
                          style: const TextStyle(color: _ts, fontSize: 12)),
                    ])),
                const SizedBox(height: 4),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Reason: "${c.globalReasonCtrl.text.isEmpty ? "Stock adjustment" : c.globalReasonCtrl.text}"',
                        style: const TextStyle(color: _tm, fontSize: 11))),
                const SizedBox(height: 8),
                const Divider(color: _bdr, height: 1),
                Expanded(child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    itemCount: changed.length,
                    itemBuilder: (_, i) {
                      final item = changed[i];
                      final inc = item.adjustment > 0;
                      return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(color: _s2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _bdr)),
                          child: Row(children: [
                            Container(width: 4, height: 28,
                                decoration: BoxDecoration(
                                    color: inc ? _green : _red,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.name, style: const TextStyle(
                                  color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('${_qty(item.currentStock)} → ${_qty(item.newStock)} kg',
                                  style: const TextStyle(color: _ts, fontSize: 10)),
                            ])),
                            Text(inc ? '+${_qty(item.adjustment)}' : _qty(item.adjustment),
                                style: TextStyle(
                                    color: inc ? _greenLt : _redLt,
                                    fontSize: 14, fontWeight: FontWeight.w900)),
                            Text(' kg', style: const TextStyle(color: _tm, fontSize: 10)),
                          ]));
                    })),
                Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 14),
                    child: Row(children: [
                      Expanded(child: _OutBtn('Cancel', _ts, () => Navigator.pop(context))),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: GestureDetector(
                          onTap: () { Navigator.pop(context); c.submitAdjustments(); },
                          child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                  color: _green.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _green.withOpacity(0.5))),
                              child: const Center(child: Text('Confirm & Update',
                                  style: TextStyle(color: _greenLt, fontSize: 13,
                                      fontWeight: FontWeight.w900)))))),
                    ])),
              ]),
            )));
  }
}

class _SumStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SumStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: _tm, fontSize: 9)),
      ]));
}

// ══════════════════════════════════════════════════════════════
//  RESULTS SCREEN  (shown after successful submit)
// ══════════════════════════════════════════════════════════════
class _ResultsScreen extends StatelessWidget {
  final StockAdjustController c;
  const _ResultsScreen({required this.c});
  @override
  Widget build(BuildContext context) => Column(children: [
    // Header
    Container(color: _s1, padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _green.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _green.withOpacity(0.4))),
              child: const Icon(Icons.check_rounded, color: _green, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Stock Updated', style: TextStyle(
                color: _tp, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${c.results.length} material(s) updated',
                style: const TextStyle(color: _greenLt, fontSize: 11)),
          ])),
          _OutBtn('Adjust More', _blue, () {
            c.submitDone.value = false;
            c.results.clear();
          }),
        ])),
    // Result list
    Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: c.results.length,
        itemBuilder: (_, i) {
          final r = c.results[i];
          final inc = r.adjustment > 0;
          return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _s2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: inc ? _green.withOpacity(0.3) : _red.withOpacity(0.3))),
              child: Row(children: [
                Container(width: 5, height: 40,
                    decoration: BoxDecoration(
                        color: inc ? _green : _red,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(
                      color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(_qty(r.oldStock), style: const TextStyle(
                        color: _ts, fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _ts)),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 12, color: _tm)),
                    Text(_qty(r.newStock), style: TextStyle(
                        color: inc ? _greenLt : _redLt,
                        fontSize: 13, fontWeight: FontWeight.w800)),
                    const Text(' kg', style: TextStyle(color: _tm, fontSize: 10)),
                  ]),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(inc ? '+${_qty(r.adjustment)}' : _qty(r.adjustment),
                      style: TextStyle(
                          color: inc ? _greenLt : _redLt,
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(r.category, style: const TextStyle(color: _tm, fontSize: 9)),
                ]),
              ]));
        })),
    // Done button
    Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, MediaQuery.of(context).padding.bottom + 14),
        child: GestureDetector(
            onTap: Get.back,
            child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue.withOpacity(0.4))),
                child: const Center(child: Text('← Back to Materials',
                    style: TextStyle(color: _blueLt, fontSize: 14, fontWeight: FontWeight.w800)))))),
  ]);
}

// ══════════════════════════════════════════════════════════════
//  ERROR STATE
// ══════════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorState({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(msg, style: const TextStyle(color: _redLt, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _OutBtn('Retry', _blue, onRetry),
      ])));
}

// ══════════════════════════════════════════════════════════════
//  ATOMS
// ══════════════════════════════════════════════════════════════
class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 34, height: 34,
          decoration: BoxDecoration(color: _s2, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr)),
          child: Icon(icon, size: 16, color: _ts)));
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepBtn(this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Icon(icon, size: 16, color: color)));
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(
          color: color, fontSize: 8, fontWeight: FontWeight.w800)));
}

class _OutBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.35))),
          child: Text(label, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center)));
}