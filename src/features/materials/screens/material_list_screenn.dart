import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/rawMaterial_controller.dart';
import '../models/RawMaterial.dart';

import 'add_materials_page.dart';
import 'material_detail_screen.dart';


// ══════════════════════════════════════════════════════════════
//  RAW MATERIAL LIST PAGE
//
//  FIX: was StatelessWidget with Get.put() at class field →
//       stale controller on re-navigation. Now StatefulWidget.
//  FIX: _categoryFilter() widget was built but never added to
//       the Column (only _searchBar and _list were included).
//  FIX: no grouping by category, no error state, no loading
//       strip, no stock alerts.
// ══════════════════════════════════════════════════════════════

class RawMaterialListPage extends StatefulWidget {
  const RawMaterialListPage({super.key});

  @override
  State<RawMaterialListPage> createState() => _RawMaterialListPageState();
}

class _RawMaterialListPageState extends State<RawMaterialListPage> {
  late final MaterialListController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.delete<MaterialListController>(force: true);
    c = Get.put(MaterialListController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Column(children: [
        _SearchBar(ctrl: _searchCtrl, c: c),
        _CategoryFilterRow(c: c),
        _SummaryStrip(c: c),
        Expanded(child: _GroupedList(c: c)),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Raw Materials', style: ErpTextStyles.pageTitle),
          Text(
            '${c.materials.length} materials  •  ${c.lowStockCount} low stock',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10),
          ),
        ],
      )),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetch,
        )),
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
          onPressed: () => _openFilterSheet(context),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'addMaterial',
      backgroundColor: ErpColors.accentBlue,
      elevation: 2,
      icon: const Icon(Icons.add, color: Colors.white, size: 20),
      label: const Text('Add Material',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      onPressed: () async {
        final result = await Get.to(() => const AddRawMaterialPage());
        if (result == true) c.fetch();
      },
    );
  }

  void _openFilterSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Filter Materials',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.back(),
                child: const Icon(Icons.close_rounded,
                    color: ErpColors.textMuted, size: 20),
              ),
            ]),
            const SizedBox(height: 16),
            const Text('Category',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const SizedBox(height: 8),
            Obx(() => DropdownButtonFormField<String>(
              value: c.tempCategory.value,
              decoration: ErpDecorations.formInput('Category'),
              style: ErpTextStyles.fieldValue,
              items: MaterialListController.kCategories
                  .map((cat) => DropdownMenuItem(
                value: cat,
                child: Text(cat),
              ))
                  .toList(),
              onChanged: (v) => c.tempCategory.value = v!,
            )),
            const SizedBox(height: 12),
            Obx(() => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Low Stock Only',
                  style: TextStyle(
                      color: ErpColors.textPrimary, fontSize: 13)),
              subtitle: const Text('Materials at or below min stock',
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 11)),
              value: c.tempLowStock.value,
              activeColor: ErpColors.errorRed,
              onChanged: (v) => c.tempLowStock.value = v ?? false,
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ErpColors.borderLight),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    c.resetFilters();
                    Get.back();
                  },
                  child: const Text('Reset',
                      style: TextStyle(color: ErpColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ErpColors.accentBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    c.applyFilters();
                    Get.back();
                  },
                  child: const Text('Apply',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final MaterialListController c;
  const _SearchBar({required this.ctrl, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        onChanged: (v) => c.search.value = v,
        style: ErpTextStyles.fieldValue,
        decoration: InputDecoration(
          filled: true,
          fillColor: ErpColors.bgMuted,
          hintText: 'Search by material name…',
          hintStyle: const TextStyle(
              color: ErpColors.textMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded,
              color: ErpColors.textMuted, size: 17),
          suffixIcon: Obx(() => c.search.value.isNotEmpty
              ? GestureDetector(
            onTap: () {
              ctrl.clear();
              c.search.value = '';
            },
            child: const Icon(Icons.close_rounded,
                size: 16, color: ErpColors.textMuted),
          )
              : const SizedBox.shrink()),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
  );
}

// ── Category filter tabs ─────────────────────────────────────
class _CategoryFilterRow extends StatelessWidget {
  final MaterialListController c;
  const _CategoryFilterRow({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MaterialListController.kCategories.map((cat) {
          final isActive = c.category.value == cat;
          final color    = _catColor(cat);
          return GestureDetector(
            onTap: () {
              c.category.value = cat;
              c.fetch();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : ErpColors.bgMuted,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : ErpColors.borderLight,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isActive ? color : ErpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isActive
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    )),
  );

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

// ── Summary strip ────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final MaterialListController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(children: [
      _Badge(c.materials.length, 'Total', ErpColors.accentBlue),
      const SizedBox(width: 8),
      _Badge(c.lowStockCount, 'Low Stock', ErpColors.errorRed),
      const SizedBox(width: 8),
      _Badge(c.grouped.keys.length, 'Categories', ErpColors.warningAmber),
    ]),
  ));
}

class _Badge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Badge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$value',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Grouped list ─────────────────────────────────────────────
class _GroupedList extends StatelessWidget {
  final MaterialListController c;
  const _GroupedList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value && c.materials.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.errorMsg.value != null) {
        return _ErrorState(msg: c.errorMsg.value!, retry: c.fetch);
      }
      if (c.materials.isEmpty) {
        return const _EmptyState();
      }

      final grouped = c.grouped;
      final categories = grouped.keys.toList();

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetch,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat   = categories[i];
            final items = grouped[cat]!;
            return _CategoryGroup(category: cat, items: items);
          },
        ),
      );
    });
  }
}

// ── Category group header + cards ────────────────────────────
class _CategoryGroup extends StatelessWidget {
  final String category;
  final List<RawMaterialListItem> items;
  const _CategoryGroup({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                color: _catColor(category),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(category.toUpperCase(),
                style: TextStyle(
                    color: _catColor(category),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8)),
            const SizedBox(width: 6),
            Text('${items.length}',
                style: const TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        ...items.map((m) => _MaterialCard(item: m)).toList(),
        const SizedBox(height: 4),
      ],
    );
  }

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

// ── Material card ─────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  final RawMaterialListItem item;
  const _MaterialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLow   = item.isLowStock;
    final stockPc = item.stockPercent;

    return GestureDetector(
      onTap: () => Get.to(
            () => const RawMaterialDetailPage(),
        arguments: item.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLow
                ? ErpColors.errorRed.withOpacity(0.4)
                : ErpColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: ErpColors.errorRed.withOpacity(0.12),
                      border: Border.all(
                          color: ErpColors.errorRed.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LOW STOCK',
                        style: TextStyle(
                            color: ErpColors.errorRed,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ErpColors.textMuted),
              ]),
              const SizedBox(height: 6),
              // Stock bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: stockPc,
                  minHeight: 4,
                  backgroundColor: ErpColors.borderLight,
                  valueColor: AlwaysStoppedAnimation(
                    isLow ? ErpColors.errorRed : ErpColors.successGreen,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _Chip(Icons.inventory_2_outlined,
                    '${item.stock.toStringAsFixed(1)} kg', ErpColors.textSecondary),
                const SizedBox(width: 10),
                _Chip(Icons.warning_amber_outlined,
                    'Min ${item.minStock.toStringAsFixed(1)} kg',
                    isLow ? ErpColors.errorRed : ErpColors.textMuted),
                const Spacer(),
                Text('₹${item.price.toStringAsFixed(0)}/kg',
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ]),
              if (item.supplierName != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.business_outlined,
                      size: 10, color: ErpColors.textMuted),
                  const SizedBox(width: 3),
                  Text(item.supplierName!,
                      style: const TextStyle(
                          color: ErpColors.textMuted, fontSize: 10)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 48, color: ErpColors.textMuted),
      SizedBox(height: 12),
      Text('No materials found',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ErpColors.textPrimary)),
      SizedBox(height: 4),
      Text('Add materials or adjust your filters',
          style: TextStyle(
              color: ErpColors.textSecondary, fontSize: 12)),
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
      const Icon(Icons.error_outline, size: 40, color: ErpColors.textMuted),
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