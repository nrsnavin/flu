import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/machine_controller.dart';
import '../models/machine.dart';

import 'AddMachine.dart';
import 'machineDetail.dart';

class MachineListPage extends StatefulWidget {
  const MachineListPage({super.key});

  @override
  State<MachineListPage> createState() => _MachineListPageState();
}

class _MachineListPageState extends State<MachineListPage> {
  late final MachineListController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // FIX: was Get.put at class-field level → stale instances
    Get.delete<MachineListController>(force: true);
    c = Get.put(MachineListController());
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
        // Search bar
        _SearchBar(controller: _searchCtrl, c: c),
        // Status filter tabs
        _StatusFilterTabs(c: c),
        // Summary counters
        _SummaryStrip(c: c),
        // List
        Expanded(child: _MachineList(c: c)),
      ]),
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
        final total = c.totalCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Machines', style: ErpTextStyles.pageTitle),
            Text(
              total > 0 ? '$total machines registered' : 'Machine Registry',
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        );
      }),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetchMachines,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'addMachine',
      backgroundColor: ErpColors.accentBlue,
      elevation: 2,
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      label: const Text('Add Machine',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13)),
      onPressed: () async {
        final result = await Get.to(() => const AddMachinePage());
        if (result == true) c.fetchMachines();
      },
    );
  }
}

// ── Search bar ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final MachineListController c;
  const _SearchBar({required this.controller, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          onChanged: c.setSearch,
          style: ErpTextStyles.fieldValue,
          decoration: InputDecoration(
            filled: true,
            fillColor: ErpColors.bgMuted,
            hintText: 'Search by ID or manufacturer…',
            hintStyle: const TextStyle(
                color: ErpColors.textMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded,
                color: ErpColors.textMuted, size: 17),
            suffixIcon: Obx(() => c.searchQuery.value.isNotEmpty
                ? GestureDetector(
              onTap: () {
                controller.clear();
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
}

// ── Status filter tabs ───────────────────────────────────────
class _StatusFilterTabs extends StatelessWidget {
  final MachineListController c;
  const _StatusFilterTabs({required this.c});

  static const _filters = [
    ('all',         'All',         null),
    ('free',        'Free',        ErpColors.successGreen),
    ('running',     'Running',     ErpColors.accentBlue),
    ('maintenance', 'Maintenance', ErpColors.warningAmber),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final (key, label, color) = f;
            final isActive = c.statusFilter.value == key;
            final activeColor = color ?? ErpColors.textSecondary;
            return GestureDetector(
              onTap: () => c.setStatusFilter(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withOpacity(0.12)
                      : ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? activeColor.withOpacity(0.5)
                        : ErpColors.borderLight,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? activeColor
                        : ErpColors.textSecondary,
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
  }
}

// ── Summary counters strip ───────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final MachineListController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(children: [
        _CountBadge(
            value: c.totalCount,
            label: 'Total',
            color: ErpColors.textSecondary),
        const SizedBox(width: 8),
        _CountBadge(
            value: c.runningCount,
            label: 'Running',
            color: ErpColors.accentBlue),
        const SizedBox(width: 8),
        _CountBadge(
            value: c.freeCount,
            label: 'Free',
            color: ErpColors.successGreen),
        const SizedBox(width: 8),
        _CountBadge(
            value: c.maintenanceCount,
            label: 'Maint.',
            color: ErpColors.warningAmber),
      ]),
    ));
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _CountBadge(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$value',
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Machine List ─────────────────────────────────────────────
class _MachineList extends StatelessWidget {
  final MachineListController c;
  const _MachineList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }

      if (c.errorMsg.value != null) {
        return _ErrorState(message: c.errorMsg.value!, onRetry: c.fetchMachines);
      }

      if (c.filteredMachines.isEmpty) {
        return _EmptyState(
          hasFilter: c.searchQuery.value.isNotEmpty ||
              c.statusFilter.value != 'all',
          onReset: () {
            c.setStatusFilter('all');
            c.setSearch('');
          },
        );
      }

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetchMachines,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: c.filteredMachines.length,
          itemBuilder: (_, i) => _MachineCard(machine: c.filteredMachines[i]),
        ),
      );
    });
  }
}

// ── Machine card ─────────────────────────────────────────────
class _MachineCard extends StatelessWidget {
  final MachineListItem machine;
  const _MachineCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(machine.status);
    final statusIcon  = _statusIcon(machine.status);

    return GestureDetector(
      // FIX: was onDoubleTap → changed to onTap
      onTap: () => Get.to(
            () => const MachineDetailPage(),
        arguments: machine.id,
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
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: statusColor.withOpacity(0.3)),
              ),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          machine.machineCode,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(status: machine.status),
                    ]),
                    const SizedBox(height: 3),
                    Text(machine.manufacturer,
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Chip(
                          Icons.view_week_outlined,
                          '${machine.noOfHeads} heads'),
                      const SizedBox(width: 8),
                      _Chip(
                          Icons.link_outlined,
                          '${machine.noOfHooks} hooks'),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: ErpColors.textMuted, size: 18),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'running':     return ErpColors.accentBlue;
      case 'free':        return ErpColors.successGreen;
      case 'maintenance': return ErpColors.warningAmber;
      default:            return ErpColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'running':     return Icons.precision_manufacturing_rounded;
      case 'free':        return Icons.check_circle_outline_rounded;
      case 'maintenance': return Icons.build_outlined;
      default:            return Icons.device_unknown_outlined;
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: ErpColors.textMuted),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color bg, border, text;
    switch (status) {
      case 'running':
        bg = ErpColors.statusApprovedBg;
        border = ErpColors.statusApprovedBorder;
        text = ErpColors.statusApprovedText;
        break;
      case 'free':
        bg = ErpColors.statusCompletedBg;
        border = ErpColors.statusCompletedBorder;
        text = ErpColors.statusCompletedText;
        break;
      case 'maintenance':
        bg = ErpColors.statusInProgressBg;
        border = ErpColors.statusInProgressBorder;
        text = ErpColors.statusInProgressText;
        break;
      default:
        bg = ErpColors.statusOpenBg;
        border = ErpColors.statusOpenBorder;
        text = ErpColors.statusOpenText;
    }
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: text, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

// ── Empty + Error states ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onReset;
  const _EmptyState({required this.hasFilter, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: const Icon(Icons.precision_manufacturing_outlined,
              size: 34, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No Matching Machines' : 'No Machines Yet',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          hasFilter
              ? 'Try adjusting your search or filter'
              : 'Add your first machine using the button below',
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        if (hasFilter) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.filter_alt_off_outlined,
                size: 15, color: ErpColors.textSecondary),
            label: const Text('Clear filters',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: const Icon(Icons.error_outline,
              size: 34, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 14),
        const Text('Failed to load',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text(message,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: onRetry,
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
}