import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/shift/screens/shift_detail.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../shiftProgram/screens/shiftDetailScreen.dart';
import '../controllers/machine_controller.dart';
import '../models/machine.dart';
import 'log.dart';

// ══════════════════════════════════════════════════════════════
//  MACHINE DETAIL PAGE
// ══════════════════════════════════════════════════════════════

class MachineDetailPage extends StatefulWidget {
  const MachineDetailPage({super.key});

  @override
  State<MachineDetailPage> createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage> {
  late final MachineDetailController c;

  @override
  void initState() {
    super.initState();
    // FIX: old code used Get.arguments[0] (List indexing) → brittle
    // Now we pass the raw String machineId directly as Get.arguments
    final machineId = Get.arguments as String;
    Get.delete<MachineDetailController>(force: true);
    c = Get.put(MachineDetailController(machineId));
    // Rebuild when service logs update
    ever(c.serviceLogs, (_) { if (mounted) setState(() {}); });
  }

  void _showEditHeadsDialog(BuildContext context) {
    final current = c.machine.value?.noOfHeads ?? 1;
    final ctrl = TextEditingController(text: '$current');
    final localCount = current.obs;

    void sync(int v) {
      localCount.value = v;
      ctrl.text = '$v';
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: ErpColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ErpColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.view_week_outlined,
                        size: 20,
                        color: ErpColors.accentBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Head Count',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Machine must be free to change heads',
                            style: TextStyle(
                              fontSize: 11,
                              color: ErpColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: ErpColors.borderLight),
              // Stepper row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Obx(
                      () => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepButton(
                        icon: Icons.remove,
                        enabled: localCount.value > 1,
                        onTap: () => sync(localCount.value - 1),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: ctrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,

                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: ErpColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          maxLength: 3,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 1) localCount.value = n;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      _StepButton(
                        icon: Icons.add,
                        enabled: localCount.value < 99,
                        onTap: () => sync(localCount.value + 1),
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                'heads',
                style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Info note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: ErpColors.statusApprovedBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: ErpColors.statusApprovedBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: ErpColors.accentBlue,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Changing head count takes effect on the next job assignment.',
                          style: TextStyle(
                            color: ErpColors.accentBlue,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: ErpColors.borderMid),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: ErpColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Obx(
                            () => SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed:
                            (c.isUpdating.value || localCount.value < 1)
                                ? null
                                : () {
                              Navigator.of(context).pop();
                              c.updateHeads(localCount.value);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ErpColors.accentBlue,
                              disabledBackgroundColor: ErpColors.accentBlue
                                  .withOpacity(0.35),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: c.isUpdating.value
                                ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              c.isUpdating.value ? 'Saving…' : 'Confirm',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }

        if (c.errorMsg.value != null) {
          return _buildError();
        }

        final machine = c.machine.value;
        if (machine == null) return _buildError();

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                _HeroCard(machine: machine),
                const SizedBox(height: 12),
                _InfoCard(machine: machine),
                if (machine.elastics.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ElasticAssignmentCard(elastics: machine.elastics),
                ],
                const SizedBox(height: 12),
                _PerformanceStats(c: c),
                const SizedBox(height: 12),
                _ServiceLogSection(c: c),
                const SizedBox(height: 12),
                _ShiftHistorySection(c: c),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final m = c.machine.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m != null ? m.machineCode : 'Machine Detail',
              style: ErpTextStyles.pageTitle,
            ),
            const Text(
              'Machines  ›  Detail',
              style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        );
      }),
      actions: [
        // Add service log button — always visible
        Obx(() {
          final m = c.machine.value;
          if (m == null) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(
              Icons.build_circle_outlined,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Add service log',
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddServiceLogPage(
                    machineMongoId:   c.machineId,
                    machineDisplayId: m.machineCode,
                  ),
                ),
              );
              if (result == true) c.fetchDetail();
            },
          );
        }),
        Obx(() {
          final m = c.machine.value;
          if (m == null || !m.isFree) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(
              Icons.view_week_outlined,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Update head count',
            onPressed: c.isUpdating.value
                ? null
                : () => _showEditHeadsDialog(context),
          );
        }),
        Obx(
              () => IconButton(
            icon: c.isLoading.value
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: c.isLoading.value ? null : c.fetchDetail,
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 34,
              color: ErpColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Failed to load machine',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.errorMsg.value ?? 'Unknown error',
            style: const TextStyle(
              color: ErpColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: c.fetchDetail,
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              elevation: 0,
            ),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
            label: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD  (machine identity + status)
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final MachineDetail machine;
  const _HeroCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(machine.status);
    final icon = _statusIcon(machine.status);
    final statusLabel =
        machine.status[0].toUpperCase() + machine.status.substring(1);

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Dark navy header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: const BoxDecoration(
              color: ErpColors.navyDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Icon(icon, size: 27, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machine.machineCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 12,
                            color: ErpColors.textOnDarkSub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            machine.manufacturer,
                            style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (machine.currentJobNo != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.work_outline,
                              size: 11,
                              color: ErpColors.textOnDarkSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Job #${machine.currentJobNo}',
                              style: const TextStyle(
                                color: ErpColors.textOnDarkSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.22),
                    border: Border.all(color: color.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Stats strip ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _StatBox(
                  icon: Icons.view_week_outlined,
                  label: 'HEADS',
                  value: '${machine.noOfHeads}',
                ),
                _vDiv(),
                _StatBox(
                  icon: Icons.link_rounded,
                  label: 'HOOKS',
                  value: '${machine.noOfHooks}',
                ),
                _vDiv(),
                _StatBox(
                  icon: Icons.calendar_today_outlined,
                  label: 'PURCHASE',
                  value: machine.dateOfPurchase ?? '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 36, color: ErpColors.borderLight);

  Color _statusColor(String s) {
    switch (s) {
      case 'running':
        return ErpColors.accentBlue;
      case 'free':
        return ErpColors.successGreen;
      case 'maintenance':
        return ErpColors.warningAmber;
      default:
        return ErpColors.textSecondary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'running':
        return Icons.precision_manufacturing_rounded;
      case 'free':
        return Icons.check_circle_outline_rounded;
      case 'maintenance':
        return Icons.build_outlined;
      default:
        return Icons.device_unknown_outlined;
    }
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 13, color: ErpColors.textMuted),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: ErpColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: ErpColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  INFO CARD  (static fields)
// ══════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final MachineDetail machine;
  const _InfoCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'MACHINE SPECIFICATIONS',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          ErpInfoRow('Machine ID', machine.machineCode),
          ErpInfoRow('Manufacturer', machine.manufacturer),
          ErpInfoRow('No. of Heads', '${machine.noOfHeads}'),
          ErpInfoRow('No. of Hooks', '${machine.noOfHooks}'),
          ErpInfoRow(
            'Status',
            machine.status[0].toUpperCase() + machine.status.substring(1),
          ),
          if (machine.currentJobNo != null)
            ErpInfoRow('Current Job', 'Job #${machine.currentJobNo}'),
          if (machine.dateOfPurchase != null)
            ErpInfoRow('Date of Purchase', machine.dateOfPurchase!),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ELASTIC ASSIGNMENT CARD  (heads → elastic map)
// ══════════════════════════════════════════════════════════════
class _ElasticAssignmentCard extends StatelessWidget {
  final List<Map<String, dynamic>> elastics;
  const _ElasticAssignmentCard({required this.elastics});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'HEAD → ELASTIC ASSIGNMENT',
      icon: Icons.grid_view_rounded,
      accentColor: ErpColors.accentBlue,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: elastics.map((e) {
          final head = e['head']?.toString() ?? '?';
          final elastic = e['elastic'];
          final name = elastic is Map
              ? (elastic['name'] ?? '—').toString()
              : '—';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ErpColors.statusApprovedBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.statusApprovedBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'H$head',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PERFORMANCE STATS  (last 10 shifts averages)
// ══════════════════════════════════════════════════════════════
class _PerformanceStats extends StatelessWidget {
  final MachineDetailController c;
  const _PerformanceStats({required this.c});

  @override
  Widget build(BuildContext context) {
    final shifts = c.shifts;
    if (shifts.isEmpty) return const SizedBox.shrink();

    final avgEff = c.avgEfficiency;
    final avgOut = c.avgOutput;
    final total = c.totalOutput;
    final count = shifts.length;

    // Efficiency color
    Color effColor;
    if (avgEff >= 80) {
      effColor = ErpColors.successGreen;
    } else if (avgEff >= 60) {
      effColor = ErpColors.warningAmber;
    } else {
      effColor = ErpColors.errorRed;
    }

    return ErpSectionCard(
      title: 'PERFORMANCE SUMMARY  (last $count shifts)',
      icon: Icons.bar_chart_rounded,
      accentColor: effColor,
      child: Column(
        children: [
          // ── 3 stat boxes ─────────────────────────────────────
          Row(
            children: [
              _PerfBox(
                label: 'AVG EFFICIENCY',
                value: '${avgEff.toStringAsFixed(1)}%',
                subLabel: 'per shift',
                color: effColor,
                icon: Icons.speed_rounded,
              ),
              Container(width: 1, color: ErpColors.borderLight),
              _PerfBox(
                label: 'AVG OUTPUT',
                value: '${avgOut.toStringAsFixed(0)} m',
                subLabel: 'per shift',
                color: ErpColors.accentBlue,
                icon: Icons.straighten_outlined,
              ),
              Container(width: 1, color: ErpColors.borderLight),
              _PerfBox(
                label: 'TOTAL OUTPUT',
                value: '$total m',
                subLabel: '$count shifts',
                color: ErpColors.successGreen,
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Efficiency bar ────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Average Efficiency',
                    style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${avgEff.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: effColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (avgEff / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: ErpColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(effColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Legend(ErpColors.successGreen, '≥ 80%  Good'),
                  const SizedBox(width: 12),
                  _Legend(ErpColors.warningAmber, '60–79%  Fair'),
                  const SizedBox(width: 12),
                  _Legend(ErpColors.errorRed, '< 60%  Poor'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerfBox extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final Color color;
  final IconData icon;
  const _PerfBox({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            subLabel,
            style: const TextStyle(color: ErpColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          color: ErpColors.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  SHIFT HISTORY SECTION
// ══════════════════════════════════════════════════════════════
class _ShiftHistorySection extends StatelessWidget {
  final MachineDetailController c;
  const _ShiftHistorySection({required this.c});

  @override
  Widget build(BuildContext context) {
    final shifts = c.shifts;

    return ErpSectionCard(
      title: 'LAST ${shifts.length} SHIFTS',
      icon: Icons.schedule_outlined,
      child: shifts.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No shift history available',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 12),
          ),
        ),
      )
          : Column(children: shifts.map((sh) => _ShiftRow(shift: sh)).toList()),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final MachineShiftHistory shift;
  const _ShiftRow({required this.shift});

  @override
  Widget build(BuildContext context) {
    final effColor = shift.efficiency >= 80
        ? ErpColors.successGreen
        : shift.efficiency >= 60
        ? ErpColors.warningAmber
        : ErpColors.errorRed;

    final isDay = shift.shiftType == 'DAY';
    final shiftColor = isDay ? ErpColors.warningAmber : ErpColors.accentBlue;

    return GestureDetector(
      // Navigate to ShiftDetailScreen using the shift's id
      // FIX: old code wrapped id in a List: arguments: [shift.id]
      // Now we pass String directly
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShiftDetailPage(shiftId: shift.id),
          )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(
          children: [
            // Shift type indicator
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shiftColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                size: 17,
                color: shiftColor,
              ),
            ),
            const SizedBox(width: 10),
            // Date + operator
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('dd MMM yyyy').format(shift.date)}  •  ${shift.shiftType}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 11,
                        color: ErpColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          shift.operatorName,
                          style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Runtime
                      _MicroChip(
                        Icons.timer_outlined,
                        shift.runtimeFormatted,
                        ErpColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      // Output
                      _MicroChip(
                        Icons.straighten_outlined,
                        '${shift.outputMeters} m',
                        ErpColors.accentBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Efficiency badge + progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${shift.efficiency.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: effColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'efficiency',
                  style: TextStyle(color: ErpColors.textMuted, fontSize: 9),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (shift.efficiency / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: ErpColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(effColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: ErpColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MicroChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  SERVICE LOG SECTION
// ══════════════════════════════════════════════════════════════
class _ServiceLogSection extends StatelessWidget {
  final MachineDetailController c;
  const _ServiceLogSection({required this.c});

  Color _typeColor(String t) {
    switch (t) {
      case 'Preventive':  return ErpColors.successGreen;
      case 'Corrective':  return ErpColors.accentBlue;
      case 'Breakdown':   return ErpColors.errorRed;
      case 'Inspection':  return ErpColors.warningAmber;
      default:            return ErpColors.textSecondary;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'Preventive':  return Icons.health_and_safety_outlined;
      case 'Corrective':  return Icons.build_circle_outlined;
      case 'Breakdown':   return Icons.warning_amber_rounded;
      case 'Inspection':  return Icons.search_rounded;
      default:            return Icons.miscellaneous_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = c.serviceLogs;
    return ErpSectionCard(
      title: 'SERVICE HISTORY',
      icon: Icons.build_outlined,
      accentColor: ErpColors.warningAmber,
      child: logs.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'No service logs yet',
            style: TextStyle(color: ErpColors.textMuted, fontSize: 12),
          ),
        ),
      )
          : Column(
        children: logs.map((log) {
          final color = _typeColor(log.type);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: type badge + date + resolved chip
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_typeIcon(log.type), size: 11, color: color),
                      const SizedBox(width: 4),
                      Text(log.type, style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const Spacer(),
                  if (!log.resolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ErpColors.errorRed.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('OPEN',
                          style: TextStyle(
                              color: ErpColors.errorRed, fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(log.date),
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 10),
                  ),
                ]),
                const SizedBox(height: 8),

                // Description
                Text(log.description,
                    style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w600)),

                // Technician + cost row
                if (log.technician.isNotEmpty || log.cost > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    if (log.technician.isNotEmpty) ...[
                      const Icon(Icons.engineering_outlined,
                          size: 11, color: ErpColors.textMuted),
                      const SizedBox(width: 4),
                      Text(log.technician,
                          style: const TextStyle(
                              color: ErpColors.textSecondary, fontSize: 11)),
                    ],
                    if (log.technician.isNotEmpty && log.cost > 0)
                      const Text('  ·  ',
                          style: TextStyle(color: ErpColors.textMuted)),
                    if (log.cost > 0)
                      Text('₹${log.cost.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: ErpColors.textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ],

                // Next service date
                if (log.nextServiceDate != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.event_rounded,
                        size: 11, color: ErpColors.accentBlue),
                    const SizedBox(width: 4),
                    Text(
                        'Next: ${DateFormat('dd MMM yyyy').format(log.nextServiceDate!)}',
                        style: const TextStyle(
                            color: ErpColors.accentBlue, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: enabled
            ? ErpColors.accentBlue.withOpacity(0.1)
            : ErpColors.bgMuted,
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled
              ? ErpColors.accentBlue.withOpacity(0.4)
              : ErpColors.borderLight,
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: enabled ? ErpColors.accentBlue : ErpColors.textMuted,
      ),
    ),
  );
}