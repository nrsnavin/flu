import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';

import '../controllers/covering_detail.dart';
import '../models/covering.dart';

import 'covering_detail.dart';


// ══════════════════════════════════════════════════════════════
//  COVERING LIST PAGE
//
//  FIX: original CoveringListPage was a StatelessWidget with
//       Get.put() as class field → stale controller on re-nav.
//  FIX: fetch(reset:true) called in build() → infinite refetch.
//  FIX: no error state, no empty state, no loading indicator
//       during initial load.
// ══════════════════════════════════════════════════════════════

class CoveringListPage extends StatefulWidget {
  const CoveringListPage({super.key});

  @override
  State<CoveringListPage> createState() => _CoveringListPageState();
}

class _CoveringListPageState extends State<CoveringListPage> {
  late final CoveringListController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.delete<CoveringListController>(force: true);
    c = Get.put(CoveringListController());
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
      body: Column(children: [
        _SearchBar(ctrl: _searchCtrl, c: c),
        _StatusFilterRow(c: c),
        _SummaryStrip(c: c),
        Expanded(child: _CoveringList(c: c)),
      ]),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
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
      title: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Covering', style: ErpTextStyles.pageTitle),
          Text(
            '${c.list.length} records  •  ${c.statusFilter.value.toUpperCase()}',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10),
          ),
        ],
      )),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value && c.list.isEmpty
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value
              ? null
              : () => c.fetchList(reset: true),
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Search bar ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final CoveringListController c;
  const _SearchBar({required this.ctrl, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: SizedBox(
      height: 40,
      child: TextField(
        controller: ctrl,
        onChanged: c.setSearch,
        style: ErpTextStyles.fieldValue,
        decoration: InputDecoration(
          filled: true,
          fillColor: ErpColors.bgMuted,
          hintText: 'Search by job order number…',
          hintStyle: const TextStyle(
              color: ErpColors.textMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded,
              color: ErpColors.textMuted, size: 17),
          suffixIcon: Obx(() => c.searchQuery.value.isNotEmpty
              ? GestureDetector(
            onTap: () {
              ctrl.clear();
              c.setSearch('');
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

// ── Status filter row ────────────────────────────────────────
class _StatusFilterRow extends StatelessWidget {
  final CoveringListController c;
  const _StatusFilterRow({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CoveringListController.kStatuses.map((s) {
          final isActive = c.statusFilter.value == s;
          final color    = _statusColor(s);
          final label    = s == 'in_progress'
              ? 'In Progress'
              : s[0].toUpperCase() + s.substring(1);
          return GestureDetector(
            onTap: () => c.setStatus(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
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
                label,
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

  Color _statusColor(String s) {
    switch (s) {
      case 'open':        return ErpColors.accentBlue;
      case 'in_progress': return ErpColors.warningAmber;
      case 'completed':   return ErpColors.successGreen;
      case 'cancelled':   return ErpColors.errorRed;
      default:            return ErpColors.textSecondary;
    }
  }
}

// ── Summary strip ────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final CoveringListController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Container(
    color: ErpColors.bgSurface,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(children: [
      _CountBadge(c.list.length,         'Total',       ErpColors.textSecondary),
      const SizedBox(width: 8),
      _CountBadge(c.inProgressCount,     'Running',     ErpColors.warningAmber),
      const SizedBox(width: 8),
      _CountBadge(c.completedCount,      'Completed',   ErpColors.successGreen),
    ]),
  ));
}

class _CountBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _CountBadge(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color:  color.withOpacity(0.09),
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

// ── Main list ────────────────────────────────────────────────
class _CoveringList extends StatelessWidget {
  final CoveringListController c;
  const _CoveringList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Initial load spinner
      if (c.isLoading.value && c.list.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      // Error
      if (c.errorMsg.value != null && c.list.isEmpty) {
        return _ErrorState(
          msg:   c.errorMsg.value!,
          retry: () => c.fetchList(reset: true),
        );
      }
      // Empty
      if (c.list.isEmpty) {
        return _EmptyState(
          status: c.statusFilter.value,
          hasSearch: c.searchQuery.value.isNotEmpty,
        );
      }

      // List + infinite scroll sentinel
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchList(reset: true),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: c.list.length + (c.hasMore.value ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i >= c.list.length) {
              // FIX: infinite scroll — only fetch when not already loading
              if (!c.isLoading.value) c.fetchList();
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: ErpColors.accentBlue, strokeWidth: 2)),
              );
            }
            return _CoveringCard(item: c.list[i]);
          },
        ),
      );
    });
  }
}

// ── Covering card ────────────────────────────────────────────
class _CoveringCard extends StatelessWidget {
  final CoveringListItem item;
  const _CoveringCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    final statusLabel = _statusLabel(item.status);

    return GestureDetector(
      onTap: () => Get.to(
            () => const CoveringDetailPage(),
        arguments: item.id,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            // Icon badge
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Icon(_statusIcon(item.status),
                  size: 20, color: statusColor),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Job #${item.jobOrderNo}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      const SizedBox(width: 8),
                      _StatusPill(label: statusLabel, color: statusColor),
                    ]),
                    if (item.customerName != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.business_outlined,
                            size: 11, color: ErpColors.textMuted),
                        const SizedBox(width: 3),
                        Text(item.customerName!,
                            style: const TextStyle(
                                color: ErpColors.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: ErpColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd MMM yyyy').format(item.date),
                        style: const TextStyle(
                            color: ErpColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ErpColors.textMuted, size: 18),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':        return ErpColors.accentBlue;
      case 'in_progress': return ErpColors.warningAmber;
      case 'completed':   return ErpColors.successGreen;
      case 'cancelled':   return ErpColors.errorRed;
      default:            return ErpColors.textSecondary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress': return 'In Progress';
      case 'open':        return 'Open';
      case 'completed':   return 'Completed';
      case 'cancelled':   return 'Cancelled';
      default:            return s;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'open':        return Icons.hourglass_empty_rounded;
      case 'in_progress': return Icons.autorenew_rounded;
      case 'completed':   return Icons.check_circle_outline_rounded;
      case 'cancelled':   return Icons.cancel_outlined;
      default:            return Icons.circle_outlined;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      border: Border.all(color: color.withOpacity(0.4)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

// ── Empty & Error states ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String status;
  final bool hasSearch;
  const _EmptyState({required this.status, required this.hasSearch});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Icon(Icons.loop_rounded,
            size: 34, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      Text(
        hasSearch ? 'No matching records' : 'No $status coverings',
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: ErpColors.textPrimary),
      ),
      const SizedBox(height: 4),
      const Text('Covering jobs will appear here',
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