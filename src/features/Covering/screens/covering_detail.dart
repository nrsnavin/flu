import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/Covering/screens/pdf.dart' hide Expanded;

import '../../PurchaseOrder/services/theme.dart';

import '../controllers/detail_controller.dart';
import '../models/covering.dart';

// ══════════════════════════════════════════════════════════════
//  COVERING DETAIL PAGE
//
//  FIX: original used Get.put() in build() → new controller every
//       rebuild. Converted to StatefulWidget with initState().
//  FIX: _header/_elasticCard/_jobSection all typed dynamic → no
//       null safety. All widgets now use typed parameters.
//  FIX: remarks in completeCovering was always null local var.
//       Now uses controller.remarksCtrl.
// ══════════════════════════════════════════════════════════════

class CoveringDetailPage extends StatefulWidget {
  const CoveringDetailPage({super.key});

  @override
  State<CoveringDetailPage> createState() => _CoveringDetailPageState();
}

class _CoveringDetailPageState extends State<CoveringDetailPage> {
  late final CoveringDetailController c;

  @override
  void initState() {
    super.initState();
    // FIX: Get.arguments is String (id), not List
    final id = Get.arguments as String;
    Get.delete<CoveringDetailController>(force: true);
    c = Get.put(CoveringDetailController(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.errorMsg.value != null) {
          return _ErrorState(msg: c.errorMsg.value!, retry: c.fetchDetail);
        }
        final data = c.covering.value;
        if (data == null) {
          return _ErrorState(
              msg: 'Covering not found', retry: c.fetchDetail);
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(children: [
              _HeroCard(data: data, c: c),
              const SizedBox(height: 12),
              _JobCard(job: data.job),
              const SizedBox(height: 12),
              if (data.remarks != null && data.remarks!.isNotEmpty)
                _RemarksCard(remarks: data.remarks!),
              if (data.remarks != null && data.remarks!.isNotEmpty)
                const SizedBox(height: 12),
              // Elastic program cards
              ...data.elasticPlanned
                  .map((e) => _ElasticProgramCard(detail: e))
                  .toList(),
              const SizedBox(height: 12),
              // Action buttons
              _ActionSection(data: data, c: c),
              const SizedBox(height: 12),
              _BeamEntriesSection(data: data, c: c),
              const SizedBox(height: 12),
              // PDF button
              _PdfButton(data: data),
            ]),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final data = c.covering.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data != null
                  ? 'Job #${data.job.jobOrderNo}  •  Covering'
                  : 'Covering Detail',
              style: ErpTextStyles.pageTitle,
            ),
            const Text('Covering  ›  Detail',
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
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final CoveringDetail data;
  final CoveringDetailController c;
  const _HeroCard({required this.data, required this.c});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(data.status);
    final statusLabel = _statusLabel(data.status);

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        // Navy header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.22),
                shape: BoxShape.circle,
                border: Border.all(
                    color: statusColor.withOpacity(0.6), width: 2),
              ),
              child: Icon(_statusIcon(data.status),
                  size: 24, color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Covering — Job #${data.job.jobOrderNo}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    if (data.job.customerName != null)
                      Text(data.job.customerName!,
                          style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.22),
                        border: Border.all(
                            color: statusColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
            ),
          ]),
        ),
        // Stats strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            _Stat(Icons.calendar_today_outlined, 'DATE',
                DateFormat('dd MMM yyyy').format(data.date)),
            _vDiv(),
            _Stat(Icons.layers_outlined, 'ELASTICS',
                '${data.elasticPlanned.length}'),
            _vDiv(),
            if (data.completedDate != null)
              _Stat(Icons.check_rounded, 'COMPLETED',
                  DateFormat('dd MMM yyyy').format(data.completedDate!)),
          ]),
        ),
      ]),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 36, color: ErpColors.borderLight);

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
      case 'in_progress': return 'IN PROGRESS';
      case 'open':        return 'OPEN';
      case 'completed':   return 'COMPLETED';
      case 'cancelled':   return 'CANCELLED';
      default:            return s.toUpperCase();
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

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 13, color: ErpColors.textMuted),
      const SizedBox(height: 3),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
      const SizedBox(height: 3),
      Text(value,
          style: const TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 11, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  JOB CARD
// ══════════════════════════════════════════════════════════════
class _JobCard extends StatelessWidget {
  final JobSummary job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
    title: 'JOB ORDER',
    icon: Icons.work_outline_rounded,
    child: Column(children: [
      ErpInfoRow('Job #',        '${job.jobOrderNo}'),
      if (job.customerName != null)
        ErpInfoRow('Customer',   job.customerName!),
      if (job.po != null)
        ErpInfoRow('PO No.',     job.po!),
      if (job.orderNo != null)
        ErpInfoRow('Order No.',  job.orderNo!),
      ErpInfoRow('Job Status',   job.status),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  REMARKS CARD
// ══════════════════════════════════════════════════════════════
class _RemarksCard extends StatelessWidget {
  final String remarks;
  const _RemarksCard({required this.remarks});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ErpColors.warningAmber.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: ErpColors.warningAmber.withOpacity(0.4)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.notes_rounded,
          size: 16, color: ErpColors.warningAmber),
      const SizedBox(width: 8),
      Expanded(
        child: Text(remarks,
            style: const TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  ELASTIC PROGRAM CARD
//  (warpSpandex, spandexCovering, testingParameters per elastic)
// ══════════════════════════════════════════════════════════════
class _ElasticProgramCard extends StatelessWidget {
  final CoveringElasticDetail detail;
  const _ElasticProgramCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final el = detail.elastic;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1A2D4A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grain_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(el.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    Text('${el.weaveType}  •  ${detail.quantity} m planned',
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub,
                            fontSize: 10)),
                  ]),
            ),
            _SpecBadge('${el.pick} Pick',   ErpColors.accentBlue),
            const SizedBox(width: 6),
            _SpecBadge('${el.noOfHook} Hook', ErpColors.warningAmber),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Specs row ──────────────────────────────
                Row(children: [
                  _SpecBox(Icons.straighten_outlined, 'WEIGHT',
                      '${el.weight} g'),
                  _SpecBox(Icons.linear_scale_outlined, 'SPANDEX ENDS',
                      '${el.spandexEnds}'),
                  _SpecBox(Icons.format_list_numbered_rtl_outlined,
                      'YARN ENDS', '${el.yarnEnds}'),
                ]),
                const SizedBox(height: 12),

                // ── Warp Spandex ────────────────────────────
                if (el.warpSpandex != null) ...[
                  _SectionLabel('🧶 Warp Spandex'),
                  const SizedBox(height: 6),
                  ErpSectionCard(
                    title: '',
                    icon: Icons.linear_scale_outlined,
                    child: Column(children: [
                      ErpInfoRow('Material', el.warpSpandex!.materialName),
                      ErpInfoRow('Ends',     '${el.warpSpandex!.ends}'),
                      ErpInfoRow('Weight',   '${el.warpSpandex!.weight} g'),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Spandex Covering ────────────────────────
                if (el.spandexCovering != null) ...[
                  _SectionLabel('🧵 Spandex Covering'),
                  const SizedBox(height: 6),
                  ErpSectionCard(
                    title: '',
                    icon: Icons.loop_rounded,
                    child: Column(children: [
                      ErpInfoRow('Material', el.spandexCovering!.materialName),
                      ErpInfoRow('Weight',   '${el.spandexCovering!.weight} g'),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Testing Parameters ─────────────────────
                if (el.testing != null) ...[
                  _SectionLabel('📐 Testing Parameters'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ErpColors.borderLight),
                    ),
                    child: Row(children: [
                      _TestBox(
                        'WIDTH',
                        el.testing!.width != null
                            ? '${el.testing!.width} mm'
                            : '—',
                        ErpColors.accentBlue,
                      ),
                      _TestBox(
                        'ELONGATION',
                        '${el.testing!.elongation}%',
                        ErpColors.successGreen,
                      ),
                      _TestBox(
                        'RECOVERY',
                        '${el.testing!.recovery}%',
                        ErpColors.warningAmber,
                      ),
                    ]),
                  ),
                ],
              ]),
        ),
      ]),
    );
  }
}

class _SpecBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SpecBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      border: Border.all(color: color.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
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
                color: ErpColors.textMuted, fontSize: 8,
                fontWeight: FontWeight.w700, letterSpacing: 0.3),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _TestBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TestBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted, fontSize: 8,
              fontWeight: FontWeight.w700, letterSpacing: 0.3),
          textAlign: TextAlign.center),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: ErpColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3));
}

// ══════════════════════════════════════════════════════════════
//  ACTION SECTION  (Start / Complete buttons)
// ══════════════════════════════════════════════════════════════
class _ActionSection extends StatelessWidget {
  final CoveringDetail data;
  final CoveringDetailController c;
  const _ActionSection({required this.data, required this.c});

  @override
  Widget build(BuildContext context) {
    if (data.isCompleted || data.isCancelled) return const SizedBox.shrink();

    return Obx(() {
      final busy = c.isActioning.value;

      if (data.isOpen) {
        return Column(children: [
          // Running indicator placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ErpColors.accentBlue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.accentBlue.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: ErpColors.accentBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ready to begin covering process',
                    style: TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: busy ? null : c.startCovering,
              icon: busy
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 20),
              label: Text(busy ? 'Starting…' : 'Move to IN PROGRESS',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
        ]);
      }

      if (data.isInProgress) {
        return Column(children: [
          // Running indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ErpColors.warningAmber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: ErpColors.warningAmber.withOpacity(0.3)),
            ),
            child: Row(children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: ErpColors.warningAmber, strokeWidth: 2.5),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Covering is running…',
                    style: TextStyle(
                        color: ErpColors.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Remarks field
          TextFormField(
            controller: c.remarksCtrl,
            maxLines: 2,
            style: ErpTextStyles.fieldValue,
            decoration: ErpDecorations.formInput(
              'Remarks (optional)',
              hint: 'Add any notes about the covering process',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ErpColors.successGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: busy ? null : c.completeCovering,
              icon: busy
                  ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 20),
              label: Text(busy ? 'Completing…' : 'Mark as Completed',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
        ]);
      }

      return const SizedBox.shrink();
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  PDF BUTTON
// ══════════════════════════════════════════════════════════════
class _PdfButton extends StatelessWidget {
  final CoveringDetail data;
  const _PdfButton({required this.data});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: ErpColors.accentBlue, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () async {
        try {
          await CoveringProgramPdf.generate(data);
        } catch (e) {
          Get.snackbar('PDF Error', e.toString(),
              backgroundColor: const Color(0xFFDC2626),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
      },
      icon: const Icon(Icons.picture_as_pdf_outlined,
          color: ErpColors.accentBlue, size: 19),
      label: const Text('View Covering Program PDF',
          style: TextStyle(
              color: ErpColors.accentBlue,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  BEAM ENTRIES SECTION
// ══════════════════════════════════════════════════════════════
class _BeamEntriesSection extends StatefulWidget {
  final CoveringDetail data;
  final CoveringDetailController c;
  const _BeamEntriesSection({required this.data, required this.c});
  @override
  State<_BeamEntriesSection> createState() => _BeamEntriesSectionState();
}

class _BeamEntriesSectionState extends State<_BeamEntriesSection> {
  CoveringDetailController get c => widget.c;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    c.isAddingBeam.listen((_) { if (mounted) setState(() {}); });
    // Pre-fill next beam number
    c.beamNoCtrl.text = '${c.nextBeamNo}';
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.beamEntries;
    final canEdit = !widget.data.isCompleted && !widget.data.isCancelled;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Section header ────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: const BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
          ),
          child: Row(children: [
            Container(
              width: 3, height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: ErpColors.successGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.scale_outlined, size: 13,
                color: ErpColors.textSecondary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('BEAM ENTRIES',
                  style: TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4)),
            ),
            // Produced weight pill
            if (widget.data.producedWeight > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ErpColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: ErpColors.successGreen.withOpacity(0.35)),
                ),
                child: Text(
                  '${_wt(widget.data.producedWeight)} kg total',
                  style: const TextStyle(
                      color: ErpColors.successGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            if (canEdit) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showForm = !_showForm;
                    if (_showForm) {
                      c.beamNoCtrl.text = '${c.nextBeamNo}';
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showForm
                        ? ErpColors.errorRed.withOpacity(0.10)
                        : ErpColors.accentBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showForm
                          ? ErpColors.errorRed.withOpacity(0.35)
                          : ErpColors.accentBlue.withOpacity(0.35),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _showForm ? Icons.close_rounded : Icons.add_rounded,
                      size: 13,
                      color: _showForm
                          ? ErpColors.errorRed
                          : ErpColors.accentBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showForm ? 'Cancel' : 'Add Beam',
                      style: TextStyle(
                          color: _showForm
                              ? ErpColors.errorRed
                              : ErpColors.accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),

        // ── Add beam form ─────────────────────────────────
        if (_showForm && canEdit) _BeamEntryForm(c: c, onSaved: () {
          setState(() { _showForm = false; });
        }),

        // ── Summary row ───────────────────────────────────
        if (entries.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BeamStat('${entries.length}', 'Beams', ErpColors.accentBlue),
                Container(
                    width: 1, height: 28, color: ErpColors.borderLight),
                _BeamStat(
                    _wt(widget.data.producedWeight),
                    'Total kg',
                    ErpColors.successGreen),
                Container(
                    width: 1, height: 28, color: ErpColors.borderLight),
                _BeamStat(
                    entries.isNotEmpty
                        ? _wt(widget.data.producedWeight / entries.length)
                        : '—',
                    'Avg kg',
                    ErpColors.warningAmber),
              ],
            ),
          ),

        // ── Entries list ──────────────────────────────────
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No beam entries yet',
                  style: TextStyle(
                      color: ErpColors.textMuted, fontSize: 12)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: entries.asMap().entries.map((entry) {
                final i  = entry.key;
                final be = entry.value;
                final isLast = i == entries.length - 1;
                return _BeamEntryRow(
                  entry:   be,
                  isLast:  isLast,
                  canEdit: canEdit,
                  onDelete: canEdit
                      ? () => _confirmDelete(context, be)
                      : null,
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, BeamEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        title: const Text('Remove Beam Entry?',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
        content: Text(
            'Beam #${entry.beamNo} — ${_wt(entry.weight)} kg will be removed.',
            style: const TextStyle(
                fontSize: 12, color: ErpColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              c.deleteBeamEntry(entry.id);
            },
            child: const Text('Remove',
                style: TextStyle(
                    color: ErpColors.errorRed,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ── Beam entry form ───────────────────────────────────────────
class _BeamEntryForm extends StatelessWidget {
  final CoveringDetailController c;
  final VoidCallback onSaved;
  const _BeamEntryForm({required this.c, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F35),
        border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('New Beam Entry',
            style: TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          // Beam No
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: c.beamNoCtrl,
              keyboardType: TextInputType.number,
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Beam No *',
                hint: '1',
                prefix: const Icon(Icons.view_week_outlined,
                    size: 16, color: ErpColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Weight
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: c.beamWtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: ErpTextStyles.fieldValue,
              decoration: ErpDecorations.formInput(
                'Weight (kg) *',
                hint: '0.000',
                prefix: const Icon(Icons.scale_outlined,
                    size: 16, color: ErpColors.textMuted),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.beamNoteCtrl,
          style: ErpTextStyles.fieldValue,
          decoration: ErpDecorations.formInput(
            'Note (optional)',
            hint: 'Any observation about this beam…',
            prefix: const Icon(Icons.notes_rounded,
                size: 16, color: ErpColors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.successGreen,
              disabledBackgroundColor:
              ErpColors.successGreen.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: c.isAddingBeam.value
                ? null
                : () async {
              final ok = await c.addBeamEntry();
              if (ok) onSaved();
            },
            icon: c.isAddingBeam.value
                ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add_circle_outline_rounded,
                size: 16, color: Colors.white),
            label: Text(
              c.isAddingBeam.value ? 'Saving…' : 'Add Beam Entry',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
        )),
      ]),
    );
  }
}

// ── Single beam entry row ─────────────────────────────────────
class _BeamEntryRow extends StatelessWidget {
  final BeamEntry entry;
  final bool isLast;
  final bool canEdit;
  final VoidCallback? onDelete;
  const _BeamEntryRow({
    required this.entry,
    required this.isLast,
    required this.canEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Row(children: [
        // Beam number badge
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: ErpColors.accentBlue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${entry.beamNo}',
                  style: const TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
              const Text('BM',
                  style: TextStyle(
                      color: ErpColors.accentBlue,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.scale_outlined,
                  size: 13, color: ErpColors.textMuted),
              const SizedBox(width: 4),
              Text('${_wt(entry.weight)} kg',
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMM yyyy  HH:mm').format(entry.enteredAt),
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 10),
            ),
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(entry.note,
                  style: const TextStyle(
                      color: ErpColors.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        )),
        if (canEdit && onDelete != null)
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: ErpColors.errorRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: ErpColors.errorRed.withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 15, color: ErpColors.errorRed),
            ),
          ),
      ]),
    );
  }
}

class _BeamStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _BeamStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value,
        style: TextStyle(
            color: color, fontSize: 15, fontWeight: FontWeight.w900)),
    Text(label,
        style: const TextStyle(
            color: ErpColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700)),
  ]);
}

String _wt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  // 3 decimal places max, trim trailing zeros
  final s = v.toStringAsFixed(3);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

// ── Error state ───────────────────────────────────────────────
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