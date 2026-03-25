// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL LIST PAGE
//  File: lib/src/features/materials/screens/material_list_screenn.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/materials/models/RawMaterial.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/list.dart';
import 'add_materials_page.dart';
import 'material_detail_screen.dart';

class RawMaterialListPage extends StatefulWidget {
  const RawMaterialListPage({super.key});

  @override
  State<RawMaterialListPage> createState() => _RawMaterialListPageState();
}

class _RawMaterialListPageState extends State<RawMaterialListPage> {
  late final RawMaterialListController _c;

  @override
  void initState() {
    super.initState();
    Get.delete<RawMaterialListController>(force: true);
    _c = Get.put(RawMaterialListController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ErpColors.accentBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Get.to(() => const AddRawMaterialPage());
          _c.fetchMaterials();
        },
      ),
      body: Column(children: [
        _SearchAndActions(c: _c),
        Expanded(child: _MaterialList(c: _c)),
      ]),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    automaticallyImplyLeading: false,
    titleSpacing: 16,
    title: const Text('Raw Materials',
        style: TextStyle(
            color: Colors.white,
            fontSize: 17, fontWeight: FontWeight.w700)),
    actions: [
      // Bulk Price Update button
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          onPressed: () => _openBulkPriceSheet(context),
          style: TextButton.styleFrom(
            backgroundColor: ErpColors.warningAmber.withOpacity(0.18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
          ),
          icon: const Icon(Icons.price_change_outlined,
              size: 15, color: ErpColors.warningAmber),
          label: const Text('Bulk Price',
              style: TextStyle(
                  color: ErpColors.warningAmber,
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
      // Filter button
      IconButton(
        icon: const Icon(Icons.filter_list,
            color: Colors.white, size: 20),
        onPressed: () => _openFilterSheet(context),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FilterSheet(c: _c),
    );
  }

  void _openBulkPriceSheet(BuildContext context) {
    if (_c.materials.isEmpty) {
      Get.snackbar('No Materials',
          'Load materials first before bulk updating prices.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkPriceSheet(c: _c),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SEARCH BAR + ACTIVE FILTER CHIPS
// ══════════════════════════════════════════════════════════════
class _SearchAndActions extends StatelessWidget {
  final RawMaterialListController c;
  const _SearchAndActions({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
    ),
    child: Column(children: [
      // Search field
      SizedBox(
        height: 40,
        child: TextField(
          onChanged: (v) => c.search.value = v,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name…',
            hintStyle: const TextStyle(
                color: ErpColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                size: 19, color: ErpColors.textMuted),
            filled: true,
            fillColor: ErpColors.bgMuted,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                  color: ErpColors.accentBlue, width: 1.5),
            ),
          ),
        ),
      ),
      // Active filter chips
      Obx(() {
        final hasCat  = c.category.value != 'All';
        final hasLow  = c.lowStockOnly.value;
        if (!hasCat && !hasLow) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            if (hasCat)
              _FilterChip(
                label: c.category.value,
                onRemove: () {
                  c.category.value     = 'All';
                  c.tempCategory.value = 'All';
                  c.fetchMaterials();
                },
              ),
            if (hasCat && hasLow) const SizedBox(width: 6),
            if (hasLow)
              _FilterChip(
                label: 'Low Stock',
                color: ErpColors.errorRed,
                onRemove: () {
                  c.lowStockOnly.value = false;
                  c.tempLowStock.value = false;
                  c.fetchMaterials();
                },
              ),
          ]),
        );
      }),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;
  const _FilterChip({
    required this.label,
    required this.onRemove,
    this.color = ErpColors.accentBlue,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close, size: 13, color: color),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  MATERIAL LIST
// ══════════════════════════════════════════════════════════════
class _MaterialList extends StatelessWidget {
  final RawMaterialListController c;
  const _MaterialList({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (c.loading.value && c.materials.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue));
    }
    if (c.materials.isEmpty) {
      return _EmptyState(onRefresh: c.fetchMaterials);
    }
    return RefreshIndicator(
      color: ErpColors.accentBlue,
      onRefresh: c.fetchMaterials,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        itemCount: c.materials.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _MaterialCard(material: c.materials[i]),
      ),
    );
  });
}

class _MaterialCard extends StatelessWidget {
  final RawMaterialListItem material;
  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final isLow = material.isLowStock;
    return GestureDetector(
      onTap: () => Get.to(() =>
          RawMaterialDetailPage(materialId: material.id)),
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLow
                ? ErpColors.errorRed.withOpacity(0.35)
                : ErpColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
                color: ErpColors.navyDark.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          // Main row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              // Category avatar
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  material.name.isNotEmpty
                      ? material.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              // Name + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: ErpColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(material.category,
                        style: const TextStyle(
                            fontSize: 11,
                            color: ErpColors.textSecondary)),
                  ],
                ),
              ),
              // Price
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${material.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const Text('per kg',
                    style: TextStyle(
                        color: ErpColors.textMuted, fontSize: 9)),
              ]),
            ]),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
            decoration: BoxDecoration(
              color: isLow
                  ? ErpColors.errorRed.withOpacity(0.04)
                  : ErpColors.bgMuted,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8)),
              border: const Border(
                  top: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(children: [
              _Meta(Icons.inventory_2_outlined,
                  '${material.stock.toStringAsFixed(1)} kg in stock'),
              const SizedBox(width: 12),
              _Meta(Icons.warning_amber_outlined,
                  'Min: ${material.minStock.toStringAsFixed(1)} kg'),
              const Spacer(),
              if (isLow)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ErpColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: ErpColors.errorRed.withOpacity(0.35)),
                  ),
                  child: const Text('LOW STOCK',
                      style: TextStyle(
                          color: ErpColors.errorRed,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 16, color: ErpColors.textMuted),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: ErpColors.textMuted),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 11)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  FILTER BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _FilterSheet extends StatelessWidget {
  final RawMaterialListController c;
  const _FilterSheet({required this.c});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle
      Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: ErpColors.borderMid,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      const Text('Filter Materials',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 16),
      // Category dropdown
      Obx(() => DropdownButtonFormField<String>(
        value: c.tempCategory.value,
        dropdownColor: ErpColors.bgSurface,
        style: ErpTextStyles.fieldValue,
        decoration: ErpDecorations.formInput('Category',
            prefix: const Icon(Icons.category_outlined,
                size: 16, color: ErpColors.textMuted)),
        items: c.categories
            .map((cat) =>
            DropdownMenuItem(value: cat, child: Text(cat)))
            .toList(),
        onChanged: (v) => c.tempCategory.value = v!,
      )),
      const SizedBox(height: 12),
      // Low stock toggle
      Obx(() => Container(
        decoration: BoxDecoration(
          color: c.tempLowStock.value
              ? ErpColors.errorRed.withOpacity(0.05)
              : ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: c.tempLowStock.value
                ? ErpColors.errorRed.withOpacity(0.3)
                : ErpColors.borderLight,
          ),
        ),
        child: CheckboxListTile(
          title: const Text('Show Low Stock Only',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: ErpColors.textPrimary)),
          value: c.tempLowStock.value,
          activeColor: ErpColors.errorRed,
          onChanged: (v) => c.tempLowStock.value = v ?? false,
          dense: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
      )),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              c.resetFilters();
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('Reset',
                style: TextStyle(color: ErpColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              c.applyFilters();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('Apply Filters',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  BULK PRICE UPDATE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _BulkPriceSheet extends StatefulWidget {
  final RawMaterialListController c;
  const _BulkPriceSheet({required this.c});

  @override
  State<_BulkPriceSheet> createState() => _BulkPriceSheetState();
}

class _BulkPriceSheetState extends State<_BulkPriceSheet> {
  // One TextEditingController per material — pre-filled with existing price
  late final List<TextEditingController> _ctrls;
  late final TextEditingController       _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _ctrls = widget.c.materials
        .map((m) => TextEditingController(
        text: m.price.toStringAsFixed(2)))
        .toList();
    _reasonCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // Build the updates list — only include changed prices
  List<Map<String, dynamic>> _buildUpdates() {
    final updates = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.c.materials.length; i++) {
      final m        = widget.c.materials[i];
      final newPrice = double.tryParse(_ctrls[i].text.trim());
      if (newPrice != null) {
        updates.add({'_id': m.id, 'price': newPrice});
      }
    }
    return updates;
  }

  // Count how many prices actually changed
  int get _changedCount {
    int count = 0;
    for (int i = 0; i < widget.c.materials.length; i++) {
      final m        = widget.c.materials[i];
      final newPrice = double.tryParse(_ctrls[i].text.trim());
      if (newPrice != null && newPrice != m.price) count++;
    }
    return count;
  }

  Future<void> _onSave() async {
    final changed = _changedCount;
    if (changed == 0) {
      Get.snackbar('No Changes',
          'All prices are the same — nothing to update.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // ── Confirm dialog ────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmBulkDialog(
        changedCount: changed,
        totalCount:   widget.c.materials.length,
        reason:       _reasonCtrl.text.trim(),
      ),
    );
    if (confirmed != true) return;

    final ok = await widget.c.bulkUpdatePrices(
      updates: _buildUpdates(),
      reason:  _reasonCtrl.text.trim(),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final materials = widget.c.materials;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Column(children: [
              Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: ErpColors.borderMid,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: ErpColors.warningAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.price_change_outlined,
                      size: 18, color: ErpColors.warningAmber),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bulk Price Update',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      Text(
                        'Edit prices below. Only changed prices will be saved.',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close,
                      color: ErpColors.textMuted, size: 20),
                ),
              ]),
            ]),
          ),

          // ── Scrollable body ────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                // Reason field
                TextFormField(
                  controller: _reasonCtrl,
                  style: ErpTextStyles.fieldValue,
                  decoration: ErpDecorations.formInput(
                    'Reason for update (optional)',
                    hint: 'e.g. Monthly price revision',
                    prefix: const Icon(Icons.edit_note_outlined,
                        size: 18, color: ErpColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  child: Row(children: [
                    const Expanded(
                      child: Text('Material',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ErpColors.textMuted,
                              letterSpacing: 0.3)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: Text('Current Price',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ErpColors.textMuted,
                              letterSpacing: 0.3)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: const Text('New Price (₹/kg)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ErpColors.textMuted,
                              letterSpacing: 0.3)),
                    ),
                  ]),
                ),

                // Material price rows
                ...List.generate(materials.length, (i) =>
                    _PriceRow(
                      material: materials[i],
                      ctrl:     _ctrls[i],
                      onChanged: () => setState(() {}),
                    )),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: const Border(
                  top: BorderSide(color: ErpColors.borderLight)),
              boxShadow: [
                BoxShadow(
                    color: ErpColors.navyDark.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -3)),
              ],
            ),
            child: Row(children: [
              // Changed count badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => widget.c.isBulkSaving.value
                        ? const SizedBox.shrink()
                        : Text(
                      '$_changedCount of ${materials.length} price${_changedCount == 1 ? '' : 's'} changed',
                      style: TextStyle(
                          color: _changedCount > 0
                              ? ErpColors.warningAmber
                              : ErpColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Save button
              SizedBox(
                height: 46,
                child: Obx(() => ElevatedButton.icon(
                  onPressed: widget.c.isBulkSaving.value
                      ? null
                      : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.warningAmber,
                    disabledBackgroundColor:
                    ErpColors.warningAmber.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                  ),
                  icon: widget.c.isBulkSaving.value
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined,
                      size: 16, color: Colors.white),
                  label: Text(
                    widget.c.isBulkSaving.value
                        ? 'Saving…'
                        : 'Save Prices',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                )),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Individual price edit row ─────────────────────────────────
class _PriceRow extends StatelessWidget {
  final RawMaterialListItem material;
  final TextEditingController ctrl;
  final VoidCallback onChanged;
  const _PriceRow({
    required this.material,
    required this.ctrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final newVal = double.tryParse(ctrl.text.trim());
    final isChanged = newVal != null && newVal != material.price;
    final isUp      = isChanged && newVal > material.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isChanged
            ? ErpColors.bgSurface
            : ErpColors.bgMuted.withOpacity(0.6),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isChanged
              ? ErpColors.warningAmber.withOpacity(0.4)
              : ErpColors.borderLight,
        ),
      ),
      child: Row(children: [
        // Material name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(material.name,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Text(material.category,
                  style: const TextStyle(
                      fontSize: 10, color: ErpColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Current price (read-only)
        SizedBox(
          width: 90,
          child: Column(children: [
            Text('₹${material.price.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isChanged
                        ? ErpColors.textMuted
                        : ErpColors.textPrimary,
                    decoration: isChanged
                        ? TextDecoration.lineThrough
                        : null)),
            if (isChanged)
              Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 10,
                      color: isUp
                          ? ErpColors.errorRed
                          : ErpColors.successGreen,
                    ),
                    Text(
                      isUp
                          ? '+${(newVal - material.price).toStringAsFixed(2)}'
                          : '${(newVal - material.price).toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isUp
                              ? ErpColors.errorRed
                              : ErpColors.successGreen),
                    ),
                  ]),
          ]),
        ),
        const SizedBox(width: 8),
        // New price input
        SizedBox(
          width: 110,
          height: 42,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isChanged
                    ? ErpColors.warningAmber
                    : ErpColors.textPrimary),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 0),
              prefixText: '₹',
              prefixStyle: TextStyle(
                  color: isChanged
                      ? ErpColors.warningAmber
                      : ErpColors.textMuted,
                  fontSize: 13, fontWeight: FontWeight.w700),
              filled: true,
              fillColor: isChanged
                  ? ErpColors.warningAmber.withOpacity(0.06)
                  : ErpColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: isChanged
                        ? ErpColors.warningAmber.withOpacity(0.5)
                        : ErpColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: isChanged
                        ? ErpColors.warningAmber.withOpacity(0.5)
                        : ErpColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                    color: ErpColors.warningAmber, width: 1.5),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ]),
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────
class _ConfirmBulkDialog extends StatelessWidget {
  final int changedCount, totalCount;
  final String reason;
  const _ConfirmBulkDialog({
    required this.changedCount,
    required this.totalCount,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: ErpColors.bgSurface,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: ErpColors.warningAmber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.price_change_outlined,
            color: ErpColors.warningAmber, size: 20),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Confirm Price Update',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
      ),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Column(children: [
          _DialogRow(
            Icons.edit_outlined,
            '$changedCount of $totalCount material prices will be updated',
            ErpColors.warningAmber,
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DialogRow(
              Icons.notes_outlined,
              'Reason: $reason',
              ErpColors.textSecondary,
            ),
          ],
          const SizedBox(height: 8),
          _DialogRow(
            Icons.history_outlined,
            'Each change will be recorded in price history',
            ErpColors.accentBlue,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const Text(
        'This action will update prices in the database and '
            'affect all future costing calculations.',
        style: TextStyle(
            color: ErpColors.textSecondary,
            fontSize: 12, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ]),
    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    actions: [
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text('Cancel',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.warningAmber,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.save_outlined,
                size: 15, color: Colors.white),
            label: const Text('Yes, Update Prices',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ],
  );
}

class _DialogRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DialogRow(this.icon, this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Expanded(
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12,
              fontWeight: FontWeight.w600)),
    ),
  ]);
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Icon(Icons.category_outlined,
            size: 32, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 16),
      const Text('No Materials Found',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15, color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Tap + to add a material',
          style: TextStyle(
              color: ErpColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onRefresh,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.borderMid)),
        icon: const Icon(Icons.refresh,
            size: 16, color: ErpColors.textSecondary),
        label: const Text('Refresh',
            style: TextStyle(color: ErpColors.textSecondary)),
      ),
    ]),
  );
}