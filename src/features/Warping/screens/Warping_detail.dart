import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/Warping/screens/warping_plan.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/controllers.dart';
import '../models/models.dart';

// ══════════════════════════════════════════════════════════════
//  WARPING DETAIL PAGE
// ══════════════════════════════════════════════════════════════
class WarpingDetailPage extends StatefulWidget {
  final String warpingId;
  const WarpingDetailPage({super.key, required this.warpingId});

  @override
  State<WarpingDetailPage> createState() => _WarpingDetailPageState();
}

class _WarpingDetailPageState extends State<WarpingDetailPage>
    with SingleTickerProviderStateMixin {
  late final WarpingDetailController c;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    Get.delete<WarpingDetailController>(force: true);
    c = Get.put(WarpingDetailController(widget.warpingId));
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    Get.delete<WarpingDetailController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value && c.warping.value == null) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null && c.warping.value == null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchDetail);
        }
        final w = c.warping.value;
        if (w == null) return const SizedBox.shrink();

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: Column(children: [
            _HeroCard(w: w),
            _StatusActions(c: c, w: w),
            TabBar(
              controller: _tabs,
              indicatorColor: ErpColors.accentBlue,
              labelColor: ErpColors.accentBlue,
              unselectedLabelColor: ErpColors.textSecondary,
              labelStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'ELASTICS & YARNS'),
                Tab(text: 'WARPING PLAN'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ElasticsTab(w: w),
                  _PlanTab(c: c, w: w, warpingId: widget.warpingId),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: ErpColors.navyDark,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new,
          size: 16, color: Colors.white),
      onPressed: Get.back,
    ),
    titleSpacing: 4,
    title: Obx(() {
      final w = c.warping.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            w != null ? 'Job #${w.jobOrderNo}' : 'Warping Detail',
            style: ErpTextStyles.pageTitle,
          ),
          const Text('Warping  ›  Detail',
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10)),
        ],
      );
    }),
    actions: [
      Obx(() => IconButton(
        icon: c.isLoading.value
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.refresh_rounded,
            color: Colors.white, size: 20),
        onPressed: c.isLoading.value ? null : c.fetchDetail,
      )),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: Color(0xFF1E3A5F)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final WarpingDetail w;
  const _HeroCard({required this.w});

  Color get _statusColor {
    switch (w.status) {
      case 'open':        return ErpColors.accentBlue;
      case 'in_progress': return const Color(0xFF7C3AED);
      case 'completed':   return ErpColors.successGreen;
      case 'cancelled':   return ErpColors.errorRed;
      default:            return ErpColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: ErpColors.navyDark,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.layers_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Job #${w.jobOrderNo}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              Text(DateFormat('dd MMM yyyy').format(w.date),
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 11)),
            ],
          ),
        ),
        _StatusBadge(w.status, _statusColor),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _StatBox('Elastics', '${w.elastics.length}',
            ErpColors.accentBlue),
        const SizedBox(width: 10),
        _StatBox(
          'Plan',
          w.hasPlan ? '✓ Created' : 'Not set',
          w.hasPlan ? ErpColors.successGreen : ErpColors.warningAmber,
        ),
        const SizedBox(width: 10),
        if (w.completedDate != null)
          _StatBox('Completed',
              DateFormat('dd MMM').format(w.completedDate!),
              ErpColors.successGreen),
      ]),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textOnDarkSub,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge(this.status, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(
      status
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) =>
      w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' '),
      style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w900),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  STATUS ACTIONS  (Start / Complete)
// ══════════════════════════════════════════════════════════════
class _StatusActions extends StatelessWidget {
  final WarpingDetailController c;
  final WarpingDetail w;
  const _StatusActions({required this.c, required this.w});

  @override
  Widget build(BuildContext context) {
    if (w.status == 'cancelled') return const SizedBox.shrink();

    if (w.status == 'completed') {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ErpColors.successGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border:
          Border.all(color: ErpColors.successGreen.withOpacity(0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded,
              color: ErpColors.successGreen, size: 16),
          SizedBox(width: 8),
          Text('Warping Completed',
              style: TextStyle(
                  color: ErpColors.successGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ]),
      );
    }

    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(children: [
        if (w.status == 'open')
          Expanded(
            child: _ActionButton(
              label: 'Start Warping',
              icon: Icons.play_arrow_rounded,
              color: ErpColors.accentBlue,
              loading: c.isActing.value,
              onTap: () => _confirm(
                context,
                'Start Warping',
                'Begin warping process for Job #${w.jobOrderNo}?',
                    () => c.startWarping(),
              ),
            ),
          ),
        if (w.status == 'in_progress') ...[
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.3)),
            ),
            child: const Row(children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C3AED)),
              ),
              SizedBox(width: 6),
              Text('In Progress',
                  style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              label: 'Complete',
              icon: Icons.check_rounded,
              color: ErpColors.successGreen,
              loading: c.isActing.value,
              onTap: () => _confirm(
                context,
                'Complete Warping',
                'Mark warping as completed for Job #${w.jobOrderNo}?',
                    () => c.completeWarping(),
              ),
            ),
          ),
        ],
      ]),
    ));
  }

  void _confirm(BuildContext ctx, String title, String msg,
      Future<bool> Function() action) {
    Get.defaultDialog(
      title: title,
      middleText: msg,
      textConfirm: 'Confirm',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: ErpColors.accentBlue,
      onConfirm: () {
        Get.back();
        action();
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ELASTICS TAB
// ══════════════════════════════════════════════════════════════
class _ElasticsTab extends StatelessWidget {
  final WarpingDetail w;
  const _ElasticsTab({required this.w});

  @override
  Widget build(BuildContext context) {
    if (w.elastics.isEmpty) {
      return const Center(
          child: Text('No elastics found',
              style: TextStyle(color: ErpColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      itemCount: w.elastics.length,
      itemBuilder: (_, i) => _ElasticCard(e: w.elastics[i]),
    );
  }
}

class _ElasticCard extends StatelessWidget {
  final ElasticWarpDetail e;
  const _ElasticCard({required this.e});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [
        BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2))
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: ErpColors.navyDark.withOpacity(0.03),
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(7)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(e.elasticName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ErpColors.textPrimary)),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Qty: ${e.plannedQty}',
                style: const TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Wrap(spacing: 16, runSpacing: 4, children: [
          _InfoChip(Icons.settings, 'Hooks: ${e.noOfHook}'),
          _InfoChip(Icons.tune, 'Pick: ${e.pick}'),
          _InfoChip(Icons.scale_outlined, '${e.weight}g/m'),
        ]),
      ),
      const Divider(
          height: 1,
          indent: 14,
          endIndent: 14,
          color: ErpColors.borderLight),
      // Warp Spandex
      if (e.warpSpandex != null) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WARP SPANDEX',
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                _MaterialRow(e.warpSpandex!),
              ]),
        ),
        const Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: ErpColors.borderLight),
      ],
      // Warp Yarns
      if (e.warpYarns.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WARP YARNS',
                    style: TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                ...e.warpYarns.map((y) => _MaterialRow(y)),
              ]),
        ),
    ]),
  );
}

class _MaterialRow extends StatelessWidget {
  final WarpMaterial m;
  const _MaterialRow(this.m);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: ErpColors.accentBlue, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(m.name,
              style: const TextStyle(
                  color: ErpColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600))),
      _Chip('Ends: ${m.ends}'),
      const SizedBox(width: 8),
      _Chip('${m.weight}g'),
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: ErpColors.bgMuted,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: ErpColors.borderLight),
    ),
    child: Text(label,
        style: const TextStyle(
            color: ErpColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: ErpColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

// ══════════════════════════════════════════════════════════════
//  PLAN TAB
// ══════════════════════════════════════════════════════════════
class _PlanTab extends StatelessWidget {
  final WarpingDetailController c;
  final WarpingDetail w;
  final String warpingId;
  const _PlanTab(
      {required this.c, required this.w, required this.warpingId});

  @override
  Widget build(BuildContext context) => Obx(() {
    final plan = c.plan.value;

    if (!w.hasPlan && plan == null) {
      return _NoPlanView(w: w, warpingId: warpingId, c: c);
    }
    if (plan == null) {
      return const Center(
          child:
          CircularProgressIndicator(color: ErpColors.accentBlue));
    }
    return _PlanView(c: c, plan: plan, w: w);
  });
}

// ── No plan ────────────────────────────────────────────────
class _NoPlanView extends StatelessWidget {
  final WarpingDetail w;
  final String warpingId;
  final WarpingDetailController c;
  const _NoPlanView(
      {required this.w, required this.warpingId, required this.c});

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
        child: const Icon(Icons.assignment_outlined,
            size: 34, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      const Text('No Warping Plan',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      const Text('Create a plan to start warping',
          style: TextStyle(
              color: ErpColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 20),
      if (w.status == 'open' || w.status == 'in_progress')
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add, color: Colors.white, size: 16),
          label: const Text('Create Warping Plan',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          onPressed: () async {
            final result = await Get.to(
                  () => WarpingPlanPage(
                jobId:     w.jobId,
                warpingId: warpingId,
              ),
            );
            if (result != null) c.fetchDetail();
          },
        ),
    ]),
  );
}

// ── Plan view ──────────────────────────────────────────────
class _PlanView extends StatelessWidget {
  final WarpingDetailController c;
  final WarpingPlanDetail plan;
  final WarpingDetail w;
  const _PlanView(
      {required this.c, required this.plan, required this.w});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
    children: [
      // ── Plan summary header with PDF button ────────────
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WARPING PLAN SUMMARY',
                      style: TextStyle(
                          color: ErpColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    '${plan.noOfBeams} Beams  ·  ${plan.totalEnds} Total Ends',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ErpColors.textPrimary),
                  ),
                  if (plan.remarks?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 3),
                    Text(plan.remarks!,
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11)),
                  ],
                ]),
          ),
          const SizedBox(width: 10),
          // ── PDF export button ───────────────────────────
          Obx(() => SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.navyDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 0),
              ),
              onPressed:
              c.isExportingPdf.value ? null : c.exportPdf,
              icon: c.isExportingPdf.value
                  ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.white, size: 14),
              label: Text(
                c.isExportingPdf.value ? 'Exporting…' : 'Export PDF',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 12),
      // ── Beam cards ──────────────────────────────────────
      ...plan.beams.map((b) => _BeamCard(beam: b)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  BEAM CARD
// ══════════════════════════════════════════════════════════════
class _BeamCard extends StatelessWidget {
  final WarpingBeamDetail beam;
  const _BeamCard({required this.beam});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
      boxShadow: [
        BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 2))
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Beam header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: ErpColors.navyDark.withOpacity(0.04),
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(7)),
        ),
        child: Row(children: [
          // Beam number badge
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ErpColors.accentBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${beam.beamNo}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Text('Beam ${beam.beamNo}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ErpColors.textPrimary)),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${beam.totalEnds} Ends',
                style: const TextStyle(
                    color: ErpColors.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      // Sections table
      Table(
        border: TableBorder(
          horizontalInside:
          BorderSide(color: ErpColors.borderLight, width: 1),
        ),
        columnWidths: const {
          0: FixedColumnWidth(46),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(70),
        },
        children: [
          TableRow(
            decoration:
            const BoxDecoration(color: Color(0xFFF8FAFD)),
            children: [
              _TH('Sec'),
              _TH('Warp Yarn'),
              _TH('Ends'),
            ],
          ),
          ...beam.sections.asMap().entries.map((e) => TableRow(
            decoration: BoxDecoration(
              color: e.key.isOdd
                  ? const Color(0xFFF8FAFC)
                  : Colors.white,
            ),
            children: [
              _TD('${e.key + 1}'),
              _TDLeft(e.value.warpYarnName.isNotEmpty
                  ? e.value.warpYarnName
                  : '—'),
              _TD('${e.value.ends}'),
            ],
          )),
        ],
      ),
    ]),
  );
}

Widget _TH(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(t,
        style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: ErpColors.textSecondary)));

Widget _TD(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(t,
        style: const TextStyle(
            fontSize: 12, color: ErpColors.textPrimary),
        textAlign: TextAlign.center));

Widget _TDLeft(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(t,
        style: const TextStyle(
            fontSize: 12,
            color: ErpColors.textPrimary,
            fontWeight: FontWeight.w600)));

// ══════════════════════════════════════════════════════════════
//  ERROR STATE
// ══════════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorState({required this.msg, required this.retry});

  @override
  Widget build(BuildContext context) =>
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline,
              size: 40, color: ErpColors.textMuted),
          const SizedBox(height: 12),
          const Text('Failed to load',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg,
                style: const TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
          ),
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