// ══════════════════════════════════════════════════════════════
//  SHIFT DETAIL PAGE
//  File: lib/src/features/production/screens/shift_detail_page.dart
//
//  NEW: Bulk Production Entry
//  A "⚡ Enter Production" FAB appears whenever there are open
//  machines. Tapping it opens a full-height bottom sheet where
//  the operator fills in production + timer for all open
//  machines at once and submits in a single tap.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/productionController.dart';
import '../models/productionBrief.dart';

class ShiftDetailPage extends StatefulWidget {
  final String shiftPlanId;
  const ShiftDetailPage({super.key, required this.shiftPlanId});

  @override
  State<ShiftDetailPage> createState() => _ShiftDetailPageState();
}

class _ShiftDetailPageState extends State<ShiftDetailPage>
    with SingleTickerProviderStateMixin {
  late final ShiftDetailController _c;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      ShiftDetailController(shiftPlanId: widget.shiftPlanId),
      tag: widget.shiftPlanId,
    );
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    Get.delete<ShiftDetailController>(tag: widget.shiftPlanId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      // ── FAB: only when open machines exist ─────────────────
      floatingActionButton: Obx(() {
        final d = _c.detail.value;
        if (d == null || !_c.hasOpenMachines) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          backgroundColor: ErpColors.accentBlue,
          elevation: 4,
          icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          label: Obx(() => Text(
            'Enter Production  (${_c.openMachines.length})',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          )),
          onPressed: () => _openBulkSheet(context),
        );
      }),
      body: Obx(() {
        if (_c.isLoading.value) return const _FullPageLoader();
        if (_c.errorMsg.value != null)
          return _FullPageError(msg: _c.errorMsg.value!, onRetry: _c.fetchDetail);
        final d = _c.detail.value;
        if (d == null) return const SizedBox.shrink();
        return _DetailBody(c: _c, detail: d, tabs: _tabs);
      }),
    );
  }

  void _openBulkSheet(BuildContext context) {
    _c.initBulkEntries();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkEntrySheet(c: _c),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  BULK ENTRY BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _BulkEntrySheet extends StatelessWidget {
  final ShiftDetailController c;
  const _BulkEntrySheet({required this.c});

  @override
  Widget build(BuildContext context) {
    // Covers ~92% of screen height; remaining 8% shows scrim
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ErpColors.bgBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ───────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ErpColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Sheet header ──────────────────────────────
            _BulkSheetHeader(c: c),

            // ── Machine entry cards ───────────────────────
            Expanded(
              child: Obx(() => c.bulkEntries.isEmpty
                  ? const Center(
                child: Text(
                  'No open machines to update.',
                  style: TextStyle(color: ErpColors.textSecondary),
                ),
              )
                  : ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                itemCount: c.bulkEntries.length,
                itemBuilder: (_, i) =>
                    _BulkMachineCard(entry: c.bulkEntries[i], index: i),
              ),
              ),
            ),

            // ── Sticky submit button ──────────────────────
            _BulkSubmitBar(c: c, context: context),
          ],
        ),
      ),
    );
  }
}

// ── Sheet header with running total ──────────────────────────
class _BulkSheetHeader extends StatelessWidget {
  final ShiftDetailController c;
  const _BulkSheetHeader({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
    decoration: BoxDecoration(
      color: ErpColors.bgBase,
      border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bolt_rounded, size: 14, color: ErpColors.accentBlue),
            const SizedBox(width: 4),
            const Text('Bulk Entry',
                style: TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 10),
        Obx(() => Text(
          '${c.bulkEntries.length} open ${c.bulkEntries.length == 1 ? 'machine' : 'machines'}',
          style: const TextStyle(
              color: ErpColors.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w600),
        )),
        const Spacer(),
        // Running total
        Obx(() => c.bulkTotalMeters.value > 0
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ErpColors.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ErpColors.successGreen.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.straighten_rounded,
                size: 13, color: ErpColors.successGreen),
            const SizedBox(width: 4),
            Text(
              '${c.bulkTotalMeters.value} m total',
              style: const TextStyle(
                  color: ErpColors.successGreen,
                  fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ]),
        )
            : const SizedBox.shrink()),
      ]),
      const SizedBox(height: 6),
      const Text(
        'Enter production meters and run time for each machine. '
            'Machines already completed are not shown here.',
        style: TextStyle(
            color: ErpColors.textSecondary, fontSize: 11),
      ),
    ]),
  );
}

// ── Per-machine entry card ────────────────────────────────────
class _BulkMachineCard extends StatefulWidget {
  final BulkEntry entry;
  final int index;
  const _BulkMachineCard({required this.entry, required this.index});

  @override
  State<_BulkMachineCard> createState() => _BulkMachineCardState();
}

class _BulkMachineCardState extends State<_BulkMachineCard> {
  bool _showRemarks = false;

  BulkEntry get e  => widget.entry;
  MachineShiftDetail get m => e.machine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Machine header ────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF0D1F35),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            // Machine badge
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('M', style: TextStyle(
                      color: ErpColors.accentBlue, fontSize: 7,
                      fontWeight: FontWeight.w700)),
                  Text(
                    m.machineNo.replaceAll(RegExp(r'[^0-9]'), ''),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.machineNo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 12, color: ErpColors.textOnDarkSub),
                  const SizedBox(width: 4),
                  Text(m.operatorName,
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 11)),
                ]),
              ],
            )),
            // Target badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TARGET',
                      style: TextStyle(
                          color: ErpColors.textOnDarkSub,
                          fontSize: 8, fontWeight: FontWeight.w600,
                          letterSpacing: 0.4)),
                  Text('${m.target} m',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ]),
        ),

        // ── Input area ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Row 1: Production (big) + Timer
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Production
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Production (meters) *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: e.productionCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary),
                      decoration: _inputDeco(
                        hint: '0',
                        suffix: const Text('m',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    // Live progress vs target
                    Obx(() {
                      final prod = e.liveMeters.value;
                      if (prod == 0 || m.target == 0) return const SizedBox.shrink();
                      final pct = (prod / m.target).clamp(0.0, 1.0);
                      final over = prod > m.target;
                      final color = over
                          ? ErpColors.successGreen
                          : pct >= 0.85
                          ? ErpColors.warningAmber
                          : ErpColors.errorRed;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 4,
                              backgroundColor: ErpColors.bgMuted,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            over
                                ? '+${prod - m.target} m over target'
                                : '${(pct * 100).toStringAsFixed(0)}% of target',
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w700),
                          ),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Timer
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Run Time'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: e.timerCtrl,
                      keyboardType: TextInputType.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary,
                          letterSpacing: 1),
                      decoration: _inputDeco(hint: 'HH:MM:SS'),
                    ),
                    const SizedBox(height: 4),
                    const Text('HH:MM:SS',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 9)),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // Remarks toggle
            GestureDetector(
              onTap: () => setState(() => _showRemarks = !_showRemarks),
              child: Row(children: [
                Icon(
                    _showRemarks ? Icons.expand_less_rounded : Icons.add_rounded,
                    size: 14, color: ErpColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _showRemarks ? 'Hide remarks' : 'Add remarks (optional)',
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            ),

            if (_showRemarks) ...[
              const SizedBox(height: 8),
              TextField(
                controller: e.remarksCtrl,
                maxLines: 2,
                style: const TextStyle(
                    color: ErpColors.textPrimary, fontSize: 13),
                decoration: _inputDeco(hint: 'Any issues or notes…'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  InputDecoration _inputDeco({required String hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        suffixIcon: suffix != null
            ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintStyle: const TextStyle(
            color: ErpColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: ErpColors.bgBase,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ErpColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: ErpColors.accentBlue, width: 2),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: ErpColors.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2));
}

// ── Sticky submit bar ─────────────────────────────────────────
class _BulkSubmitBar extends StatelessWidget {
  final ShiftDetailController c;
  final BuildContext context;
  const _BulkSubmitBar({required this.c, required this.context});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: const Border(top: BorderSide(color: ErpColors.borderLight)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3)),
      ],
    ),
    child: Obx(() => Row(children: [
      // Cancel
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.borderLight),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: c.isBulkUpdating.value
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 12),
      // Submit
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            disabledBackgroundColor: ErpColors.accentBlue.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: c.isBulkUpdating.value
              ? null
              : () async {
            final ok = await c.bulkSave();
            if (ok && context.mounted) Navigator.of(context).pop();
          },
          icon: c.isBulkUpdating.value
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          label: Text(
            c.isBulkUpdating.value
                ? 'Saving…'
                : 'Submit All  (${c.bulkEntries.length})',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ])),
  );
}

// ══════════════════════════════════════════════════════════════
//  THE REST OF THE PAGE — unchanged from original
// ══════════════════════════════════════════════════════════════
class _DetailBody extends StatelessWidget {
  final ShiftDetailController c;
  final ShiftPlanDetail detail;
  final TabController tabs;
  const _DetailBody({required this.c, required this.detail, required this.tabs});

  bool get isDay => detail.shiftType == 'day';
  Color get accent => isDay ? ErpColors.accentBlue : const Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar(
          expandedHeight: 232,
          pinned: true,
          backgroundColor: ErpColors.navyDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: c.fetchDetail,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroBanner(detail: detail, accent: accent),
          ),
          bottom: TabBar(
            controller: tabs,
            labelColor: accent,
            unselectedLabelColor: ErpColors.textOnDarkSub,
            indicatorColor: accent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            tabs: const [Tab(text: 'Machine Log'), Tab(text: 'Summary')],
          ),
        ),
      ],
      body: TabBarView(
        controller: tabs,
        children: [
          _MachineLogTab(c: c, accent: accent),
          _SummaryTab(detail: detail, accent: accent),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO BANNER
// ══════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final ShiftPlanDetail detail;
  final Color accent;
  const _HeroBanner({required this.detail, required this.accent});

  bool get isDay => detail.shiftType == 'day';

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ErpColors.navyDark,
            isDay ? const Color(0xFF0D2A4A) : const Color(0xFF1A0D3D),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                  color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(isDay ? 'Day Shift' : 'Night Shift',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 10),
          Text(detail.dateLabel,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          _StatusBadge(detail.status),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${s.totalProduction}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w900, height: 1)),
          const Padding(
            padding: EdgeInsets.only(bottom: 4, left: 4),
            child: Text('m',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub,
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 4),
        Text('Target: ${s.totalTarget} m',
            style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _HeroChip(Icons.settings_rounded,     '${s.totalMachines}', 'Machines',  accent),
            const SizedBox(width: 8),
            _HeroChip(Icons.person_rounded,       '${s.totalOperators}', 'Operators', accent),
            const SizedBox(width: 8),
            _HeroChip(Icons.timer_outlined,       s.formattedRunTime,  'Run Time',  accent),
            const SizedBox(width: 8),
            _HeroChip(
                Icons.pause_circle_outline_rounded,
                '${s.totalDowntime}m', 'Downtime',
                s.totalDowntime > 0 ? ErpColors.warningAmber : ErpColors.successGreen),
            if (detail.supervisorName != null) ...[
              const SizedBox(width: 8),
              _HeroChip(Icons.supervisor_account_rounded,
                  detail.supervisorName!, 'Supervisor', const Color(0xFF0891B2)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _HeroChip(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 8)),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  TAB 1 — MACHINE LOG
// ══════════════════════════════════════════════════════════════
class _MachineLogTab extends StatelessWidget {
  final ShiftDetailController c;
  final Color accent;
  const _MachineLogTab({required this.c, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _FilterBar(c: c, accent: accent),
      Expanded(
        child: Obx(() {
          final machines = c.filteredMachines;
          if (machines.isEmpty) {
            return const Center(
              child: Text('No machines match this filter',
                  style: TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100), // room for FAB
            itemCount: machines.length,
            itemBuilder: (_, i) =>
                _MachineCard(m: machines[i], accent: accent, index: i),
          );
        }),
      ),
    ]);
  }
}

// ── Filter / Sort bar ─────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final ShiftDetailController c;
  final Color accent;
  const _FilterBar({required this.c, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(children: [
        const Text('Sort:', style: TextStyle(color: ErpColors.textSecondary, fontSize: 11)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _SortChip('Row',  'rowIndex',   c, accent),
              _SortChip('Prod', 'production', c, accent),
              _SortChip('Eff',  'efficiency', c, accent),
            ]),
          ),
        ),
        Obx(() => PopupMenuButton<String>(
          initialValue: c.filterStatus.value,
          color: ErpColors.bgSurface,
          onSelected: c.changeFilter,
          itemBuilder: (_) => [
            for (final e in [
              ('all', 'All'), ('completed', 'Completed'),
              ('in_progress', 'In Progress'), ('open', 'Open'),
            ])
              PopupMenuItem(value: e.$1,
                  child: Text(e.$2, style: const TextStyle(
                      color: ErpColors.textPrimary, fontSize: 13))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: ErpColors.borderLight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                c.filterStatus.value == 'all'
                    ? 'All Status'
                    : c.filterStatus.value.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 11, color: ErpColors.textPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded,
                  size: 16, color: ErpColors.textSecondary),
            ]),
          ),
        )),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label, value;
  final ShiftDetailController c;
  final Color accent;
  const _SortChip(this.label, this.value, this.c, this.accent);

  @override
  Widget build(BuildContext context) => Obx(() {
    final active = c.sortBy.value == value;
    return GestureDetector(
      onTap: () => c.changeSort(value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? accent : ErpColors.borderLight),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: active ? Colors.white : ErpColors.textSecondary,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  });
}

// ══════════════════════════════════════════════════════════════
//  MACHINE CARD — same as original + "Open" badge highlight
// ══════════════════════════════════════════════════════════════
class _MachineCard extends StatefulWidget {
  final MachineShiftDetail m;
  final Color accent;
  final int index;
  const _MachineCard({required this.m, required this.accent, required this.index});

  @override
  State<_MachineCard> createState() => _MachineCardState();
}

class _MachineCardState extends State<_MachineCard> {
  bool _expanded = false;

  MachineShiftDetail get m => widget.m;

  Color get _statusColor {
    switch (m.status) {
      case 'completed':   return ErpColors.successGreen;
      case 'in_progress': return ErpColors.accentBlue;
      default:            return ErpColors.warningAmber;
    }
  }

  Color get _effColor {
    if (m.efficiency >= 100) return ErpColors.successGreen;
    if (m.efficiency >= 85)  return ErpColors.warningAmber;
    return ErpColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final pct = m.target > 0 ? (m.production / m.target).clamp(0.0, 1.0) : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _expanded
              ? widget.accent.withOpacity(0.4)
              : ErpColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: widget.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('M', style: TextStyle(
                          fontSize: 8, color: ErpColors.textSecondary)),
                      Text(
                        m.machineNo.replaceAll(RegExp(r'[^0-9]'), ''),
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: widget.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(m.machineNo,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: ErpColors.textPrimary)),
                      const SizedBox(width: 6),
                      if (m.machineType.isNotEmpty && m.machineType != '-')
                        _TypeTag(m.machineType),
                      const SizedBox(width: 6),
                      // Open status highlight
                      if (m.status == 'open')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ErpColors.warningAmber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: ErpColors.warningAmber.withOpacity(0.4)),
                          ),
                          child: const Text('OPEN',
                              style: TextStyle(
                                  color: ErpColors.warningAmber,
                                  fontSize: 8, fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 12, color: ErpColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(m.operatorName,
                          style: const TextStyle(
                              fontSize: 11, color: ErpColors.textSecondary)),
                    ]),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${m.production}m',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: ErpColors.textPrimary)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _effColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${m.efficiency.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: _effColor)),
                  ),
                ]),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded,
                      color: widget.accent, size: 20),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Stack(children: [
                  Container(height: 5,
                      decoration: BoxDecoration(
                          color: ErpColors.bgMuted,
                          borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(height: 5,
                        decoration: BoxDecoration(
                            color: _effColor,
                            borderRadius: BorderRadius.circular(3))),
                  ),
                ])),
                const SizedBox(width: 8),
                Text('${m.production}/${m.target}m',
                    style: const TextStyle(
                        fontSize: 9, color: ErpColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _QuickStat(Icons.grid_view_rounded, '${m.noOfHeads}', 'Heads',    widget.accent),
                const SizedBox(width: 6),
                _QuickStat(Icons.speed_rounded,     '${m.speed}',    'Speed',    widget.accent),
                const SizedBox(width: 6),
                _QuickStat(Icons.timer_outlined,    m.formattedRunTime, 'Run Time', ErpColors.successGreen),
                const SizedBox(width: 6),
                _QuickStat(
                    Icons.pause_circle_outline_rounded,
                    m.formattedDowntime, 'Downtime',
                    m.downtimeMinutes > 0 ? ErpColors.warningAmber : ErpColors.textMuted),
              ]),
            ]),
          ),
        ),

        if (_expanded) ...[
          Container(height: 1, color: ErpColors.borderLight),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHead('Operator Details'),
              const SizedBox(height: 6),
              _DetailGrid([
                _GridItem('Name', m.operatorName),
                _GridItem('Department', m.operatorDept),
                _GridItem('Skill', m.operatorSkill),
              ]),
              const SizedBox(height: 12),
              _SectionHead('Machine Specs'),
              const SizedBox(height: 6),
              _DetailGrid([
                _GridItem('Machine No', m.machineNo),
                _GridItem('Type', m.machineType),
                _GridItem('Department', m.department),
                _GridItem('No of Heads', '${m.noOfHeads}'),
                _GridItem('Speed', '${m.speed} RPM'),
              ]),
              const SizedBox(height: 12),
              _SectionHead('Timer Details'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.accent.withOpacity(0.2)),
                ),
                child: Column(children: [
                  _TimerRow('Start Time', m.timerStart ?? '—',
                      Icons.play_circle_outline_rounded, ErpColors.successGreen),
                  const SizedBox(height: 6),
                  _TimerRow('End Time', m.timerEnd ?? '—',
                      Icons.stop_circle_outlined, ErpColors.errorRed),
                  const SizedBox(height: 6),
                  _TimerRow('Total Run', m.formattedRunTime,
                      Icons.timer_rounded, widget.accent),
                  const SizedBox(height: 6),
                  _TimerRow('Active Time', '${m.activeMinutes}m',
                      Icons.bolt_rounded, ErpColors.accentBlue),
                  const SizedBox(height: 6),
                  _TimerRow('Downtime', m.formattedDowntime,
                      Icons.pause_circle_outline_rounded,
                      m.downtimeMinutes > 0 ? ErpColors.warningAmber : ErpColors.textMuted),
                ]),
              ),

              if (m.downtimeReasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHead('Downtime Reasons'),
                const SizedBox(height: 6),
                ...m.downtimeReasons.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: ErpColors.warningAmber.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: ErpColors.warningAmber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.reason,
                        style: const TextStyle(
                            fontSize: 11, color: ErpColors.textPrimary))),
                    Text('${r.minutes}m',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: ErpColors.warningAmber)),
                  ]),
                )),
              ],

              const SizedBox(height: 12),
              _SectionHead('Production Detail'),
              const SizedBox(height: 6),
              _DetailGrid([
                _GridItem('Target', '${m.target} m'),
                _GridItem('Produced', '${m.production} m'),
                _GridItem('Variance',
                    '${m.production - m.target >= 0 ? '+' : ''}${m.production - m.target} m'),
                _GridItem('Efficiency', '${m.efficiency.toStringAsFixed(1)}%'),
              ]),

              if (m.remarks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(7)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.notes_rounded,
                        size: 13, color: ErpColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.remarks,
                        style: const TextStyle(
                            fontSize: 11, color: ErpColors.textSecondary,
                            fontStyle: FontStyle.italic))),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _QuickStat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 8, color: ErpColors.textSecondary)),
      ]),
    ),
  );
}

class _SectionHead extends StatelessWidget {
  final String title;
  const _SectionHead(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800,
          color: ErpColors.textSecondary, letterSpacing: 0.8));
}

class _GridItem { final String label, value; const _GridItem(this.label, this.value); }

class _DetailGrid extends StatelessWidget {
  final List<_GridItem> items;
  const _DetailGrid(this.items);
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6, runSpacing: 6,
    children: items.map((item) => Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: ErpColors.bgBase, borderRadius: BorderRadius.circular(7),
          border: Border.all(color: ErpColors.borderLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.label,
            style: const TextStyle(fontSize: 8, color: ErpColors.textSecondary)),
        const SizedBox(height: 2),
        Text(item.value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: ErpColors.textPrimary)),
      ]),
    )).toList(),
  );
}

class _TimerRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TimerRow(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary)),
    const Spacer(),
    Text(value, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: color)),
  ]);
}

class _TypeTag extends StatelessWidget {
  final String type;
  const _TypeTag(this.type);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: ErpColors.bgMuted, borderRadius: BorderRadius.circular(4)),
    child: Text(type,
        style: const TextStyle(fontSize: 9, color: ErpColors.textSecondary)),
  );
}

// ══════════════════════════════════════════════════════════════
//  TAB 2 — SUMMARY (unchanged)
// ══════════════════════════════════════════════════════════════
class _SummaryTab extends StatelessWidget {
  final ShiftPlanDetail detail;
  final Color accent;
  const _SummaryTab({required this.detail, required this.accent});

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        _SummaryCard(title: 'Shift Overview', icon: Icons.info_outline_rounded, accent: accent,
            children: [
              _SummaryRow('Date', detail.dateLabel),
              _SummaryRow('Shift Type', detail.shiftType == 'day' ? 'Day Shift' : 'Night Shift'),
              _SummaryRow('Status', detail.status.replaceAll('_', ' ').toUpperCase()),
              _SummaryRow('Start Time', detail.startTime ?? 'Not recorded'),
              _SummaryRow('End Time',   detail.endTime   ?? 'Not recorded'),
              if (detail.supervisorName != null) _SummaryRow('Supervisor', detail.supervisorName!),
              if (detail.jobNo != null) _SummaryRow('Job Order', detail.jobNo!),
              _SummaryRow('Department', detail.department),
            ]),
        const SizedBox(height: 12),
        _SummaryCard(title: 'Production Summary', icon: Icons.straighten_rounded, accent: ErpColors.successGreen,
            children: [
              _SummaryRow('Total Production', '${s.totalProduction} m'),
              _SummaryRow('Total Target',     '${s.totalTarget} m'),
              _SummaryRow('Variance',
                  '${s.totalProduction - s.totalTarget >= 0 ? '+' : ''}${s.totalProduction - s.totalTarget} m'),
              _SummaryRow('Avg Efficiency', '${s.avgEfficiency.toStringAsFixed(1)}%'),
              _SummaryRow('Top Machine', s.highestProducer),
            ]),
        const SizedBox(height: 12),
        _SummaryCard(title: 'Workforce', icon: Icons.people_alt_rounded, accent: const Color(0xFF0891B2),
            children: [
              _SummaryRow('Machines Running', '${s.totalMachines}'),
              _SummaryRow('Total Operators',  '${s.totalOperators}'),
            ]),
        const SizedBox(height: 12),
        _SummaryCard(title: 'Time Analysis', icon: Icons.access_time_rounded, accent: ErpColors.warningAmber,
            children: [
              _SummaryRow('Total Run Time', s.formattedRunTime),
              _SummaryRow('Total Downtime', '${s.totalDowntime} min'),
              _SummaryRow('Downtime %',
                  s.totalRunMinutes > 0
                      ? '${(s.totalDowntime / s.totalRunMinutes * 100).toStringAsFixed(1)}%'
                      : '—'),
            ]),
        const SizedBox(height: 12),
        _SummaryCard(title: 'Machine Performance', icon: Icons.bar_chart_rounded, accent: accent,
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: ErpColors.borderLight),
                    borderRadius: BorderRadius.circular(6)),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                    child: const Row(children: [
                      _TH('Machine', flex: 2),
                      _TH('Operator', flex: 3),
                      _TH('Heads', flex: 1),
                      _TH('Prod', flex: 2),
                      _TH('Eff%', flex: 2),
                    ]),
                  ),
                  ...detail.machines.asMap().entries.map((e) {
                    final m = e.value;
                    final effColor = m.efficiency >= 100
                        ? ErpColors.successGreen
                        : m.efficiency >= 85 ? ErpColors.warningAmber : ErpColors.errorRed;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      color: e.key.isOdd ? ErpColors.bgMuted : ErpColors.bgSurface,
                      child: Row(children: [
                        _TD(m.machineNo, flex: 2, bold: true, color: accent),
                        _TD(m.operatorName, flex: 3),
                        _TD('${m.noOfHeads}', flex: 1),
                        _TD('${m.production}m', flex: 2),
                        _TD('${m.efficiency.toStringAsFixed(1)}%',
                            flex: 2, color: effColor, bold: true),
                      ]),
                    );
                  }),
                ]),
              ),
            ]),

        if (detail.remarks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: ErpColors.bgSurface, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ErpColors.borderLight)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_rounded, color: ErpColors.textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Shift Remarks',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: ErpColors.textSecondary)),
                const SizedBox(height: 4),
                Text(detail.remarks,
                    style: const TextStyle(
                        fontSize: 12, color: ErpColors.textPrimary,
                        fontStyle: FontStyle.italic)),
              ])),
            ]),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;
  const _SummaryCard({required this.title, required this.icon,
    required this.accent, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.03), blurRadius: 6,
          offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border(bottom: BorderSide(color: accent.withOpacity(0.2))),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(children: children),
      ),
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 130, child: Text(label,
          style: const TextStyle(fontSize: 12, color: ErpColors.textSecondary))),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: ErpColors.textPrimary))),
    ]),
  );
}

class _TH extends StatelessWidget {
  final String text;
  final int flex;
  const _TH(this.text, {required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(flex: flex,
      child: Text(text, textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)));
}

class _TD extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  const _TD(this.text, {required this.flex, this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Expanded(flex: flex,
      child: Text(text, textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10,
              color: color ?? ErpColors.textPrimary,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)));
}

// ══════════════════════════════════════════════════════════════
//  FULL-PAGE STATES
// ══════════════════════════════════════════════════════════════
class _FullPageLoader extends StatelessWidget {
  const _FullPageLoader();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: ErpColors.bgBase,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: ErpColors.accentBlue),
      SizedBox(height: 14),
      Text('Loading shift details…',
          style: TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
    ])),
  );
}

class _FullPageError extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _FullPageError({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ErpColors.bgBase,
    appBar: AppBar(
      backgroundColor: ErpColors.navyDark,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.maybePop(context)),
      title: const Text('Shift Detail',
          style: TextStyle(color: Colors.white, fontSize: 15)),
    ),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: ErpColors.errorRed, size: 52),
        const SizedBox(height: 14),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: ErpColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
          label: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    )),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final map = {
      'completed':   (ErpColors.successGreen,  const Color(0xFFF0FDF4)),
      'in_progress': (const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      'open':        (ErpColors.accentBlue,    const Color(0xFFEFF6FF)),
    };
    final (fg, bg) = map[status] ?? (ErpColors.textMuted, ErpColors.bgMuted);
    final lbl = {'completed': 'Completed', 'in_progress': 'In Progress', 'open': 'Open'}[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(lbl,
          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}