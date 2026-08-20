import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/stock_count_controller.dart';
import '../models/stock_count.dart';

// ══════════════════════════════════════════════════════════════
//  WALKING A COUNT SHEET
//
//  One row per material, a number pad, and a search box for finding
//  the rack you are standing at. That is the whole screen, and
//  deliberately so — this is used one-handed, in a store room, by
//  somebody holding a reel in the other hand.
//
//  ── The system figure is shown, and that is a real decision ────
//  Showing it risks anchoring: somebody who sees "120" is likelier to
//  write 120. Hiding it means every discrepancy is discovered at the
//  desk afterwards, when nobody can go and look again. The count is
//  reconciled the same day either way, so the cheaper error is the
//  anchoring one — and the variance is shown live, which is what makes
//  a wrong entry obvious while the rack is still in front of you.
//
//  ── Nothing is saved until you say so ──────────────────────────
//  Entries are held locally and sent in one PATCH, which the server
//  merges. A save that fails must not look like a save that worked, so
//  the unsaved count stays on the button until the server confirms.
// ══════════════════════════════════════════════════════════════

class StockCountSheetPage extends StatefulWidget {
  const StockCountSheetPage({super.key, required this.countId});

  final String countId;

  @override
  State<StockCountSheetPage> createState() => _StockCountSheetPageState();
}

class _StockCountSheetPageState extends State<StockCountSheetPage> {
  late final StockCountSheetController c;
  final _tag = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    c = Get.put(StockCountSheetController(widget.countId), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<StockCountSheetController>(tag: _tag, force: true);
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!c.hasUnsaved) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: Text(
          '${c.unsavedCount} counted line(s) have not been saved. '
          'Walking the rack again is the expensive part.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep counting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: AppBar(
          backgroundColor: ErpColors.navyDark,
          foregroundColor: ErpColors.textOnDark,
          title: Obx(() => Text(c.sheet.value?.title ?? 'Count')),
        ),
        body: Obx(() {
          if (c.isLoading.value && c.sheet.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final msg = c.errorMsg.value;
          if (msg != null && c.sheet.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(msg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ErpColors.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: c.fetch, child: const Text('Try again')),
                  ],
                ),
              ),
            );
          }

          final s = c.sheet.value;
          if (s == null) return const SizedBox.shrink();

          return Column(
            children: [
              _summary(s),
              _search(),
              Expanded(
                child: Builder(builder: (_) {
                  final rows = c.visible;
                  if (rows.isEmpty) {
                    return const Center(
                      child: Text('Nothing matches that search.',
                          style: TextStyle(color: ErpColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _LineTile(
                      line: rows[i],
                      readOnly: !s.isOpen,
                      onCounted: (v) => c.setCounted(rows[i], v),
                      onReason: (r) => c.setReason(rows[i], r),
                    ),
                  );
                }),
              ),
            ],
          );
        }),
        bottomNavigationBar: Obx(() {
          final s = c.sheet.value;
          if (s == null || !s.isOpen) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: c.isSaving.value || !c.hasUnsaved
                    ? null
                    : () async {
                        final err = await c.save();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(err ?? 'Count saved'),
                          backgroundColor:
                              err == null ? null : ErpColors.navyMid,
                        ));
                      },
                icon: c.isSaving.value
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  c.hasUnsaved
                      ? 'Save ${c.unsavedCount} counted line(s)'
                      : 'Nothing to save',
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _summary(StockCount s) {
    final t = s.totals;
    return Container(
      width: double.infinity,
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.counted} of ${t.lines} counted',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            s.isOpen
                ? '${t.uncounted} still to walk'
                : 'Posted — this sheet is history now.',
            style:
                const TextStyle(fontSize: 12, color: ErpColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _search() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: TextField(
          onChanged: (v) => c.query.value = v,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Find a material…',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: ErpColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
          ),
        ),
      );
}

class _LineTile extends StatefulWidget {
  const _LineTile({
    required this.line,
    required this.readOnly,
    required this.onCounted,
    required this.onReason,
  });

  final StockCountLine line;
  final bool readOnly;
  final void Function(double?) onCounted;
  final void Function(String) onReason;

  @override
  State<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<_LineTile> {
  late final TextEditingController _qty;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(
      text: widget.line.countedQty?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final trimmed = raw.trim();
    // Empty clears back to UNCOUNTED, which is not zero: an uncounted
    // line is skipped at posting, a zero writes the stock off.
    widget.onCounted(trimmed.isEmpty ? null : double.tryParse(trimmed));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final counted = double.tryParse(_qty.text.trim());
    final variance = counted == null ? null : counted - l.systemQty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: variance != null && variance != 0
              ? ErpColors.accentBlue.withValues(alpha: 0.4)
              : ErpColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary)),
          if (l.category.isNotEmpty)
            Text(l.category,
                style: const TextStyle(
                    fontSize: 11, color: ErpColors.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'System ${_fmt(l.systemQty)}',
                  style: const TextStyle(
                      fontSize: 12, color: ErpColors.textSecondary),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _qty,
                  enabled: !widget.readOnly,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.right,
                  onChanged: _commit,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Counted',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (variance != null && variance != 0) ...[
            const SizedBox(height: 8),
            Text(
              '${variance > 0 ? '+' : ''}${_fmt(variance)} against the system',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: variance > 0
                    ? ErpColors.statusOpenText
                    : ErpColors.accentBlue,
              ),
            ),
            if (l.needsReason || variance.abs() > 0) ...[
              const SizedBox(height: 8),
              TextField(
                enabled: !widget.readOnly,
                onChanged: widget.onReason,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Why? (spillage, mis-issue, damage…)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
          if (l.correctedElsewhere != 0) ...[
            const SizedBox(height: 8),
            Text(
              'Another count already corrected ${_fmt(l.correctedElsewhere)} '
              'of this gap; only the rest will be applied.',
              style: const TextStyle(
                  fontSize: 11, color: ErpColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
