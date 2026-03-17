import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/PurchaseOrder/screnns/po_detail.dart';
import '../controllers/add_po.dart';
import '../controllers/po_list.dart';

import '../models/po_models.dart';
import '../services/theme.dart';
import 'add_po.dart';

class POListPage extends StatelessWidget {
  POListPage({super.key});

  late final POListController c = () {
    Get.delete<POListController>(force: true);
    return Get.put(POListController());
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _StatsRow(c: c),
          _SearchFilterBar(c: c),
          Expanded(child: _POListBody(c: c)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ErpColors.accentBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final res = await Get.to(() => AddPOPage(mode: POFormMode.create));
          if (res == true) c.fetchPOs(reset: true);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text(
        "Purchase Orders",
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          onPressed: () => c.fetchPOs(reset: true),
          tooltip: "Refresh",
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Stats row — horizontal scroll, compact pills ───────────────
class _StatsRow extends StatelessWidget {
  final POListController c;
  const _StatsRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.navyDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Obx(() {
        final open = c.pos.where((p) => p.status == 'Open').length;
        final partial = c.pos.where((p) => p.status == 'Partial').length;
        final completed = c.pos.where((p) => p.status == 'Completed').length;
        final totalVal =
        c.pos.fold<double>(0, (s, p) => s + p.totalOrderValue);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatPill(
                label: "TOTAL",
                value: "${c.total.value}",
                color: ErpColors.accentLight,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: "OPEN",
                value: "$open",
                color: ErpColors.statusOpenText,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: "PARTIAL",
                value: "$partial",
                color: ErpColors.warningAmber,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: "DONE",
                value: "$completed",
                color: ErpColors.successGreen,
              ),
              const SizedBox(width: 8),
              _StatPill(
                label: "VALUE",
                value: _abbr(totalVal),
                color: const Color(0xFFF59E0B),
                prefix: "₹",
              ),
            ],
          ),
        );
      }),
    );
  }

  static String _abbr(double v) {
    if (v >= 10000000) return "${(v / 10000000).toStringAsFixed(1)}Cr";
    if (v >= 100000) return "${(v / 100000).toStringAsFixed(1)}L";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(1)}K";
    return v.toStringAsFixed(0);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = "",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "$prefix$value",
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search + filter bar ────────────────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  final POListController c;
  const _SearchFilterBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
        color: ErpColors.bgSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          SizedBox(
            height: 38,
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Search by PO number...",
                hintStyle:
                const TextStyle(color: ErpColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: ErpColors.textMuted),
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
                  borderSide:
                  const BorderSide(color: ErpColors.accentBlue, width: 1.5),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => c.searchQuery.value = v,
            ),
          ),
          const SizedBox(height: 10),
          // Status filter chips
          Obx(() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Obx(() => Text(
                  "${c.total.value} records",
                  style: const TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                )),
                const SizedBox(width: 12),
                ...["", "Open", "Partial", "Completed"].map((opt) {
                  final label = opt.isEmpty ? "All" : opt;
                  final active = c.statusFilter.value == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => c.statusFilter.value = opt,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: active
                              ? ErpColors.accentBlue
                              : ErpColors.bgMuted,
                          border: Border.all(
                            color: active
                                ? ErpColors.accentBlue
                                : ErpColors.borderMid,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : ErpColors.textSecondary,
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── List body ──────────────────────────────────────────────────
class _POListBody extends StatelessWidget {
  final POListController c;
  const _POListBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value) {
        return const Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue),
        );
      }
      if (c.pos.isEmpty) {
        return _EmptyState();
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchPOs(reset: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: c.pos.length + (c.hasMore.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == c.pos.length) {
              WidgetsBinding.instance.addPostFrameCallback(
                      (_) => c.fetchPOs());
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child:
                  CircularProgressIndicator(color: ErpColors.accentBlue),
                ),
              );
            }
            return _POCard(po: c.pos[i], c: c);
          },
        ),
      );
    });
  }
}

// ── PO Card ────────────────────────────────────────────────────
class _POCard extends StatelessWidget {
  final POModel po;
  final POListController c;

  const _POCard({required this.po, required this.c});

  static const _statusColors = {
    'Open': ErpColors.statusOpenText,
    'Partial': ErpColors.warningAmber,
    'Completed': ErpColors.successGreen,
  };

  static const _statusBg = {
    'Open': ErpColors.statusOpenBg,
    'Partial': ErpColors.statusPartialBg,
    'Completed': ErpColors.statusCompletedBg,
  };

  static const _statusBorder = {
    'Open': ErpColors.statusOpenBorder,
    'Partial': ErpColors.statusPartialBorder,
    'Completed': ErpColors.statusCompletedBorder,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[po.status] ?? ErpColors.textMuted;
    final bgColor = _statusBg[po.status] ?? ErpColors.bgMuted;
    final borderColor = _statusBorder[po.status] ?? ErpColors.borderLight;
    final dateFmt = DateFormat("dd MMM yyyy");

    final received = po.totalOrderValue > 0
        ? (po.totalOrderValue - po.totalPendingValue) / po.totalOrderValue
        : (po.status == 'Completed' ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () async {
        final res = await Get.to(() => PODetailPage(poId: po.id));
        if (res == true) c.fetchPOs(reset: true);
      },
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: PO number + status + menu ─────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  // PO number
                  Text(
                    "PO #${po.poNo}",
                    style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status badge
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      po.status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Action menu
                  _CardMenu(po: po, c: c),
                ],
              ),
            ),

            // ── Supplier row ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.business_outlined,
                      size: 13, color: ErpColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      po.supplier?.name ?? "—",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ErpColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Meta row: date + items + value ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  // Date
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    dateFmt.format(po.date),
                    style: const TextStyle(
                        color: ErpColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 14),
                  // Items count
                  Icon(Icons.inventory_2_outlined,
                      size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    "${po.items.length} item${po.items.length != 1 ? 's' : ''}",
                    style: const TextStyle(
                        color: ErpColors.textSecondary, fontSize: 11),
                  ),
                  const Spacer(),
                  // Order value
                  Text(
                    "₹${NumberFormat('#,##,###').format(po.totalOrderValue)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress bar ────────────────────────────────
            if (po.status != 'Open') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${(received * 100).clamp(0, 100).toStringAsFixed(0)}% received",
                      style: TextStyle(
                        color: received >= 1
                            ? ErpColors.successGreen
                            : ErpColors.warningAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (po.totalPendingValue > 0)
                      Text(
                        "Pending: ₹${NumberFormat('#,##,###').format(po.totalPendingValue)}",
                        style: const TextStyle(
                            color: ErpColors.textMuted, fontSize: 10),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: received.clamp(0, 1),
                    backgroundColor: ErpColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      received >= 1
                          ? ErpColors.successGreen
                          : ErpColors.warningAmber,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 12),

            // ── Bottom accent line ──────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card action menu ───────────────────────────────────────────
class _CardMenu extends StatelessWidget {
  final POModel po;
  final POListController c;
  const _CardMenu({required this.po, required this.c});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          size: 18, color: ErpColors.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: ErpColors.borderLight),
      ),
      elevation: 4,
      onSelected: (v) async {
        if (v == 'view') {
          final res = await Get.to(() => PODetailPage(poId: po.id));
          if (res == true) c.fetchPOs(reset: true);
        } else if (v == 'edit' && po.status != 'Completed') {
          final res = await Get.to(
                  () => AddPOPage(mode: POFormMode.edit, seedData: po.toEditData()));
          if (res == true) c.fetchPOs(reset: true);
        } else if (v == 'clone') {
          final res = await Get.to(
                  () => AddPOPage(mode: POFormMode.clone, seedData: po.toCloneData()));
          if (res == true) c.fetchPOs(reset: true);
        }
      },
      itemBuilder: (_) => [
        _item('view', Icons.open_in_new_outlined, 'View Details'),
        if (po.status != 'Completed')
          _item('edit', Icons.edit_outlined, 'Edit PO'),
        _item('clone', Icons.copy_all_outlined, 'Clone PO'),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label) =>
      PopupMenuItem(
        value: v,
        height: 42,
        child: Row(
          children: [
            Icon(icon, size: 16, color: ErpColors.textSecondary),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: ErpColors.textPrimary)),
          ],
        ),
      );
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Purchase Orders",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap + to create your first PO",
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}