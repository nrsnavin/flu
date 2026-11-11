import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../theme/erp_theme.dart';
import '../controllers/warping_detail_controller.dart';
import '../models/warping.dart';

// ═════════════════════════════════════════════════════════════
//  WARPING DETAIL PAGE — worker view, READ-ONLY.
//
//  Two tabs:
//    • Specs — elastic technical specs table
//    • Plan  — beam-by-beam warping plan (if defined)
// ═════════════════════════════════════════════════════════════
class WarpingDetailPage extends StatefulWidget {
  const WarpingDetailPage({super.key});
  @override
  State<WarpingDetailPage> createState() => _WarpingDetailPageState();
}

class _WarpingDetailPageState extends State<WarpingDetailPage>
    with SingleTickerProviderStateMixin {
  late final EmpWarpingDetailController c;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // Guard the route argument — a malformed deep-link or programmatic
    // Get.to(...) without arguments used to crash the page on cast.
    final arg = Get.arguments;
    final id = (arg is String && arg.isNotEmpty) ? arg : '';
    Get.delete<EmpWarpingDetailController>(force: true);
    c    = Get.put(EmpWarpingDetailController(id));
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchDetail);
        }
        final d = c.warping.value;
        if (d == null) {
          return _ErrorState(msg: 'Warping not found', retry: c.fetchDetail);
        }
        return Column(children: [
          _HeroCard(data: d),
          Container(
            color: ErpColors.bgSurface,
            child: TabBar(
              controller: _tab,
              labelColor: ErpColors.accentBlue,
              unselectedLabelColor: ErpColors.textSecondary,
              indicatorColor: ErpColors.accentBlue,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'SPECS'),
                Tab(text: 'WARPING PLAN'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _SpecsTab(data: d),
                _PlanTab(c: c, data: d),
              ],
            ),
          ),
        ]);
      }),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: Obx(() {
          final d = c.warping.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                d != null
                    ? 'Job #${d.jobOrderNo}  •  Warping'
                    : 'Warping Detail',
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
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                onPressed: c.isLoading.value ? null : c.fetchDetail,
              )),
        ],
      );
}

// ─── Hero card ───────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final WarpingDetail data;
  const _HeroCard({required this.data});

  Color _col(String s) {
    switch (s) {
      case 'open':        return ErpColors.accentBlue;
      case 'in_progress': return ErpColors.warningAmber;
      case 'completed':   return ErpColors.successGreen;
      case 'cancelled':   return ErpColors.errorRed;
      default:            return ErpColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _col(data.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: col.withValues(alpha: 0.6), width: 2),
          ),
          child: Icon(Icons.linear_scale_rounded,
              size: 22, color: col),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Job #${data.jobOrderNo}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                if (data.customerName != null)
                  Text(data.customerName!,
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.22),
                      border: Border.all(color: col.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(data.status.toUpperCase(),
                        style: TextStyle(
                            color: col,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: ErpColors.textOnDarkSub),
                  const SizedBox(width: 3),
                  Text(DateFormat('dd MMM yyyy').format(data.date),
                      style: const TextStyle(
                          color: ErpColors.textOnDarkSub, fontSize: 10)),
                ]),
              ]),
        ),
      ]),
    );
  }
}

// ─── Specs tab ───────────────────────────────────────────────────────
class _SpecsTab extends StatelessWidget {
  final WarpingDetail data;
  const _SpecsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.elastics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No elastic specifications recorded',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 13)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: data.elastics.map((e) => _ElasticCard(detail: e)).toList(),
    );
  }
}

class _ElasticCard extends StatelessWidget {
  final ElasticWarpDetail detail;
  const _ElasticCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: ErpDecorations.card,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2D4A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.grain_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.elasticName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        Text('${detail.plannedQty} m planned',
                            style: const TextStyle(
                                color: ErpColors.textOnDarkSub,
                                fontSize: 10)),
                      ]),
                ),
              ]),
            ),
            // Spec boxes
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  _SpecBox(Icons.straighten_outlined, 'WEIGHT',
                      '${detail.weight} g'),
                  _SpecBox(Icons.linear_scale_outlined, 'SPANDEX ENDS',
                      '${detail.spandexEnds}'),
                  _SpecBox(Icons.format_list_numbered_rtl_outlined,
                      'PICK', '${detail.pick}'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _SpecBox(Icons.view_week_outlined, 'NO. OF HOOK',
                      '${detail.noOfHook}'),
                  _SpecBox(Icons.format_list_bulleted_rounded,
                      'WARP YARNS', '${detail.warpYarns.length}'),
                  _SpecBox(Icons.layers_outlined, 'PLANNED',
                      '${detail.plannedQty} m'),
                ]),
                if (detail.warpSpandex != null) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel('Warp Spandex'),
                  const SizedBox(height: 6),
                  _MaterialRow(m: detail.warpSpandex!),
                ],
                if (detail.warpYarns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel('Warp Yarns'),
                  const SizedBox(height: 6),
                  ...detail.warpYarns.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _MaterialRow(m: m))),
                ],
              ]),
            ),
          ]),
    );
  }
}

class _SpecBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _SpecBox(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: Column(children: [
            Icon(icon, size: 14, color: ErpColors.textSecondary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: ErpColors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _MaterialRow extends StatelessWidget {
  final WarpMaterial m;
  const _MaterialRow({required this.m});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: Row(children: [
          const Icon(Icons.fiber_manual_record,
              size: 8, color: ErpColors.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(m.name,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          Text('${m.ends} ends',
              style: const TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${m.weight} g',
              style: const TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );
}

// ─── Plan tab ────────────────────────────────────────────────────────
class _PlanTab extends StatelessWidget {
  final EmpWarpingDetailController c;
  final WarpingDetail data;
  const _PlanTab({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isPlanLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      final plan = c.plan.value;
      if (!data.hasPlan || plan == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_outlined,
                      size: 38, color: ErpColors.textMuted),
                  const SizedBox(height: 10),
                  const Text('No warping plan yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ErpColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text(
                      'Your supervisor will create the beam plan before warping starts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 12)),
                ]),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          _PlanSummary(plan: plan),
          const SizedBox(height: 10),
          ...plan.beams.map((b) => _BeamCard(beam: b)),
          if (plan.remarks != null && plan.remarks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ErpColors.warningAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ErpColors.warningAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded,
                        size: 14, color: ErpColors.warningAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(plan.remarks!,
                          style: const TextStyle(
                              color: ErpColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
            ),
          ],
        ],
      );
    });
  }
}

class _PlanSummary extends StatelessWidget {
  final WarpingPlanDetail plan;
  const _PlanSummary({required this.plan});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ErpColors.navyDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Beams', style: ErpTextStyles.kpiLabel),
                  const SizedBox(height: 2),
                  Text('${plan.noOfBeams}', style: ErpTextStyles.kpiValue),
                ]),
          ),
          Container(width: 1, height: 36, color: ErpColors.navyLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Ends', style: ErpTextStyles.kpiLabel),
                  const SizedBox(height: 2),
                  Text('${plan.totalEnds}', style: ErpTextStyles.kpiValue),
                ]),
          ),
        ]),
      );
}

class _BeamCard extends StatelessWidget {
  final WarpingBeamDetail beam;
  const _BeamCard({required this.beam});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: ErpDecorations.card,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: ErpColors.bgMuted,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(
                      bottom: BorderSide(color: ErpColors.borderLight)),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: ErpColors.accentBlue.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text('${beam.beamNo}',
                        style: const TextStyle(
                            color: ErpColors.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Beam #${beam.beamNo}',
                        style: const TextStyle(
                            color: ErpColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text('${beam.totalEnds} ends',
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  if (beam.pairedBeamNo != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ErpColors.warningAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: ErpColors.warningAmber.withValues(alpha: 0.4)),
                      ),
                      child: Text('PAIR #${beam.pairedBeamNo}',
                          style: const TextStyle(
                              color: ErpColors.warningAmber,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                    children: beam.sections
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                const Icon(Icons.arrow_right_rounded,
                                    size: 16,
                                    color: ErpColors.textMuted),
                                Expanded(
                                  child: Text(s.warpYarnName,
                                      style: const TextStyle(
                                          color: ErpColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text('${s.ends} ends',
                                    style: const TextStyle(
                                        color: ErpColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                if (s.maxMeters > 0) ...[
                                  const SizedBox(width: 6),
                                  Text('• ${s.maxMeters} m',
                                      style: const TextStyle(
                                          color: ErpColors.textMuted,
                                          fontSize: 10)),
                                ],
                              ]),
                            ))
                        .toList()),
              ),
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
          const Icon(Icons.cloud_off_outlined,
              size: 40, color: ErpColors.textMuted),
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
            icon: const Icon(Icons.refresh,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
