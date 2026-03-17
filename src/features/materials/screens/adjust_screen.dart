// lib/src/features/materials/screens/stock_adjust_history_page.dart
//
// Displays all STOCK_ADJUST movements across all raw materials,
// grouped by date with search, category, and date-range filters.
//
// Zero Obx — all reactive widgets use StatefulWidget + ever().

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/adjust_history.dart';


// ── Palette ────────────────────────────────────────────────────
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
const _tp     = Color(0xFFF0F6FF);
const _ts     = Color(0xFF8BA4C2);
const _tm     = Color(0xFF3D5470);

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
//  ROOT PAGE
// ══════════════════════════════════════════════════════════════
class StockAdjustHistoryPage extends StatefulWidget {
  const StockAdjustHistoryPage({super.key});
  @override
  State<StockAdjustHistoryPage> createState() => _StockAdjustHistoryPageState();
}

class _StockAdjustHistoryPageState extends State<StockAdjustHistoryPage> {
  late final StockAdjustHistoryController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.delete<StockAdjustHistoryController>(force: true);
    c = Get.put(StockAdjustHistoryController());
    ever(c.isLoading, (_) { if (mounted) setState(() {}); });
    ever(c.errorMsg,  (_) { if (mounted) setState(() {}); });
    ever(c.groups,    (_) { if (mounted) setState(() {}); });
    ever(c.totalCount,(_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<StockAdjustHistoryController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Column(children: [
      _AppBar(c: c, onBack: () => Navigator.of(context).pop()),
      _SearchBar(ctrl: _searchCtrl, c: c),
      _FilterRow(c: c),
      _SummaryBar(c: c),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (c.isLoading.value) {
      return const Center(
          child: CircularProgressIndicator(color: _blue, strokeWidth: 2));
    }
    if (c.errorMsg.value != null) {
      return _ErrorState(msg: c.errorMsg.value!, onRetry: c.fetch);
    }
    if (c.groups.isEmpty) {
      return const _EmptyState();
    }
    return RefreshIndicator(
      color: _blue,
      onRefresh: () => c.fetch(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
        itemCount: c.groups.length,
        itemBuilder: (_, i) => _DateGroup(group: c.groups[i]),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────
class _AppBar extends StatefulWidget {
  final StockAdjustHistoryController c;
  final VoidCallback onBack;
  const _AppBar({required this.c, required this.onBack});
  @override State<_AppBar> createState() => _AppBarState();
}
class _AppBarState extends State<_AppBar> {
  @override
  void initState() {
    super.initState();
    ever(widget.c.totalCount, (_) { if (mounted) setState(() {}); });
    ever(widget.c.isLoading,  (_) { if (mounted) setState(() {}); });
    ever(widget.c.filterDays, (_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _s1,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: _s2, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bdr)),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _ts)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjustment History',
                style: TextStyle(color: _tp, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
                widget.c.isLoading.value
                    ? 'Loading…'
                    : '${widget.c.totalCount.value} entries · last ${widget.c.filterDays.value} days',
                style: const TextStyle(color: _tm, fontSize: 10)),
          ],
        )),
        GestureDetector(
          onTap: () => widget.c.fetch(),
          child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: _s2, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _bdr)),
              child: widget.c.isLoading.value
                  ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 16, color: _ts)),
        ),
      ]),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final StockAdjustHistoryController c;
  const _SearchBar({required this.ctrl, required this.c});
  @override
  Widget build(BuildContext context) => Container(
    color: _s1,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: _tp, fontSize: 13),
      onChanged: c.setSearch,
      decoration: InputDecoration(
          hintText: 'Search by material name…',
          hintStyle: const TextStyle(color: _tm, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: _tm, size: 18),
          suffixIcon: ctrl.text.isNotEmpty
              ? GestureDetector(
              onTap: () { ctrl.clear(); c.setSearch(''); },
              child: const Icon(Icons.close_rounded, color: _tm, size: 16))
              : null,
          filled: true, fillColor: _s2, isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _bdr)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _bdr)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _blue, width: 1.5))),
    ),
  );
}

// ── Filter row (category chips + days dropdown) ────────────────
class _FilterRow extends StatefulWidget {
  final StockAdjustHistoryController c;
  const _FilterRow({required this.c});
  @override State<_FilterRow> createState() => _FilterRowState();
}
class _FilterRowState extends State<_FilterRow> {
  @override
  void initState() {
    super.initState();
    ever(widget.c.filterCategory, (_) { if (mounted) setState(() {}); });
    ever(widget.c.filterDays,     (_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _s1,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(children: [
      // Category chips
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ...StockAdjustHistoryController.kCategories.map((cat) {
            final active = widget.c.filterCategory.value == cat;
            final color  = cat == 'All' ? _blue : _catColor(cat);
            return GestureDetector(
              onTap: () => widget.c.setCategory(cat),
              child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: active ? color.withOpacity(0.15) : _s2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: active ? color.withOpacity(0.5) : _bdr)),
                  child: Text(cat, style: TextStyle(
                      color: active ? color : _ts,
                      fontSize: 11, fontWeight: FontWeight.w700))),
            );
          }),
        ]),
      )),
      const SizedBox(width: 8),
      // Days dropdown
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: _s2, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: widget.c.filterDays.value,
            dropdownColor: _s2,
            iconEnabledColor: _ts,
            isDense: true,
            style: const TextStyle(color: _ts, fontSize: 11, fontWeight: FontWeight.w700),
            items: StockAdjustHistoryController.kDayOptions.map((d) =>
                DropdownMenuItem(value: d,
                    child: Text('$d days',
                        style: TextStyle(
                            color: widget.c.filterDays.value == d ? _amberLt : _ts,
                            fontSize: 11, fontWeight: FontWeight.w700)))).toList(),
            onChanged: (v) { if (v != null) widget.c.setDays(v); },
          ),
        ),
      ),
    ]),
  );
}

// ── Summary bar ────────────────────────────────────────────────
class _SummaryBar extends StatefulWidget {
  final StockAdjustHistoryController c;
  const _SummaryBar({required this.c});
  @override State<_SummaryBar> createState() => _SummaryBarState();
}
class _SummaryBarState extends State<_SummaryBar> {
  @override
  void initState() {
    super.initState();
    ever(widget.c.allEntries, (_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (c.allEntries.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _s1,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(children: [
        _StatPill('${c.uniqueMaterials}', 'materials', _blue),
        const SizedBox(width: 8),
        _StatPill('+${_qty(c.totalAdded)} kg', 'added', _green),
        const SizedBox(width: 8),
        _StatPill('−${_qty(c.totalRemoved)} kg', 'removed', _red),
        const SizedBox(width: 8),
        _StatPill('${c.allEntries.length}', 'entries', _amber),
      ]),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Column(children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: _tm, fontSize: 9)),
    ]),
  ));
}

// ── Date group ─────────────────────────────────────────────────
class _DateGroup extends StatelessWidget {
  final AdjustHistoryGroup group;
  const _DateGroup({required this.group});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Date header
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _amber.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_rounded, size: 11, color: _amberLt),
              const SizedBox(width: 5),
              Text(group.dateLabel, style: const TextStyle(
                  color: _amberLt, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${group.entries.length} adjustment${group.entries.length == 1 ? '' : 's'}',
              style: const TextStyle(color: _tm, fontSize: 10)),
        ]),
      ),
      // Entry cards
      ...group.entries.map((e) => _EntryCard(entry: e)),
    ],
  );
}

// ── Entry card ─────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final AdjustHistoryEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPos   = entry.isPositive;
    final adjColor = isPos ? _green : _red;
    final catColor = _catColor(entry.category);
    final timeFmt  = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _s2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          // Category dot
          Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                  color: catColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          // Material name + category
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.materialName, style: const TextStyle(
                color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(entry.category, style: TextStyle(
                color: catColor, fontSize: 10, fontWeight: FontWeight.w600)),
          ])),
          // Time
          Text(timeFmt.format(entry.date),
              style: const TextStyle(color: _tm, fontSize: 10)),
          const SizedBox(width: 10),
          // Adjustment badge
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: adjColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: adjColor.withOpacity(0.35))),
              child: Text(
                  '${isPos ? '+' : ''}${_qty(entry.adjustment)} kg',
                  style: TextStyle(
                      color: adjColor, fontSize: 13, fontWeight: FontWeight.w900))),
        ]),

        const SizedBox(height: 10),

        // Stock flow row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: _s3, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            // Old stock
            if (entry.oldStock != null) ...[
              Column(children: [
                const Text('Before', style: TextStyle(color: _tm, fontSize: 9)),
                Text(_qty(entry.oldStock!),
                    style: const TextStyle(
                        color: _ts, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: 8),
              Icon(isPos
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
                  size: 14,
                  color: adjColor.withOpacity(0.6)),
              const SizedBox(width: 8),
            ],
            // New stock (balance)
            if (entry.balance != null)
              Column(children: [
                const Text('After', style: TextStyle(color: _tm, fontSize: 9)),
                Text(_qty(entry.balance!),
                    style: const TextStyle(
                        color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
            if (entry.oldStock == null && entry.balance == null)
              Text('Current: ${_qty(entry.currentStock)} kg',
                  style: const TextStyle(color: _ts, fontSize: 12)),
            const Spacer(),
            // Current stock (live)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Now', style: TextStyle(color: _tm, fontSize: 9)),
              Text(_qty(entry.currentStock),
                  style: const TextStyle(color: _blueLt, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),

        // Reason
        if (entry.reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.notes_rounded, size: 12, color: _tm),
            const SizedBox(width: 6),
            Expanded(child: Text(entry.reason,
                style: const TextStyle(color: _ts, fontSize: 11))),
          ]),
        ],
      ]),
    );
  }
}

// ── Empty / error states ───────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.history_rounded, size: 48, color: _tm),
      const SizedBox(height: 12),
      const Text('No adjustments found',
          style: TextStyle(color: _ts, fontSize: 13)),
      const SizedBox(height: 6),
      const Text('Try widening the date range or clearing filters',
          style: TextStyle(color: _tm, fontSize: 11)),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorState({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, size: 40, color: _red),
        const SizedBox(height: 10),
        Text(msg, style: const TextStyle(color: _redLt, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        GestureDetector(
            onTap: onRetry,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: _blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _blue.withOpacity(0.4))),
                child: const Text('Retry',
                    style: TextStyle(color: _blueLt, fontSize: 13,
                        fontWeight: FontWeight.w700)))),
      ]),
    ),
  );
}