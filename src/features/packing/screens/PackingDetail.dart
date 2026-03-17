import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:production/src/features/packing/screens/pdf.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../controllers/packing_controller.dart';
import '../models/PackingModel.dart';

// ══════════════════════════════════════════════════════════════
//  PACKING DETAIL PAGE
//
//  BUGS FIXED:
//  1. Was StatelessWidget with Get.put at field level → stale controller
//  2. fetchDetail called in build() → refetched every rebuild
//  3. Used GET /packing/:id which doesn't populate elastic →
//     elasticName was always empty. Now uses GET /packing/detail/:id
//  4. PackingModel.fromJson(res.data['packing']) but /:id route
//     returned object directly (not wrapped)
// ══════════════════════════════════════════════════════════════

class PackingDetailPage extends StatefulWidget {
  const PackingDetailPage({super.key});

  @override
  State<PackingDetailPage> createState() => _PackingDetailPageState();
}

class _PackingDetailPageState extends State<PackingDetailPage> {
  late final PackingDetailController c;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as String;
    Get.delete<PackingDetailController>(force: true);
    c = Get.put(PackingDetailController(id));
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
        if (c.errorMsg.value != null || c.packing.value == null) {
          return _ErrorState(
              msg: c.errorMsg.value ?? 'Not found', retry: c.fetchDetail);
        }
        final p = c.packing.value!;
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(children: [
              _HeroCard(p: p),
              const SizedBox(height: 12),
              _ElasticCard(p: p),
              const SizedBox(height: 10),
              _ProductionCard(p: p),
              const SizedBox(height: 10),
              _WeightCard(p: p),
              const SizedBox(height: 10),
              _QcCard(p: p),
              const SizedBox(height: 20),
              _PdfActions(p: p),
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
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final p = c.packing.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p != null ? 'Job #${p.jobOrderNo}' : 'Packing Detail',
                style: ErpTextStyles.pageTitle),
            const Text('Packing  ›  Box Detail',
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

// ── Hero card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final PackingDetail p;
  const _HeroCard({required this.p});

  @override
  Widget build(BuildContext context) {
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
      child: Column(children: [
        // Navy header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ErpColors.accentBlue.withOpacity(0.5)),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  size: 26, color: ErpColors.accentBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job #${p.jobOrderNo}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.business_outlined,
                        size: 11, color: ErpColors.textOnDarkSub),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(p.customerName,
                          style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.receipt_outlined,
                        size: 11, color: ErpColors.textOnDarkSub),
                    const SizedBox(width: 4),
                    Text('PO: ${p.po}',
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(DateFormat('dd MMM yyyy').format(DateTime.parse(p.date)),
                  style: const TextStyle(
                      color: ErpColors.textOnDarkSub, fontSize: 10)),
            ]),
          ]),
        ),
        // Stats strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            _StatBox(Icons.straighten_outlined, 'METERS',
                '${p.meters.toStringAsFixed(2)} m'),
            _vDiv(),
            _StatBox(Icons.link_outlined, 'JOINTS', '${p.joints}'),
            _vDiv(),
            _StatBox(Icons.expand_outlined, 'STRETCH', p.stretch),
            if (p.size.isNotEmpty) ...[
              _vDiv(),
              _StatBox(Icons.aspect_ratio_outlined, 'SIZE', p.size),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _vDiv() =>
      Container(width: 1, height: 36, color: ErpColors.borderLight);
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBox(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 13, color: ErpColors.textMuted),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
      const SizedBox(height: 3),
      Text(value,
          style: const TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Elastic card ──────────────────────────────────────────────
class _ElasticCard extends StatelessWidget {
  final PackingDetail p;
  const _ElasticCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'ELASTIC DETAILS',
      icon: Icons.fiber_manual_record_outlined,
      accentColor: ErpColors.accentBlue,
      child: Column(children: [
        ErpInfoRow('Elastic Name', p.elasticName),
        if (p.stretch != null)
          ErpInfoRow('Stretch %', '${p.stretch}%'),
      ]),
    );
  }
}

// ── Production card ───────────────────────────────────────────
class _ProductionCard extends StatelessWidget {
  final PackingDetail p;
  const _ProductionCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'PRODUCTION DATA',
      icon: Icons.precision_manufacturing_outlined,
      child: Column(children: [
        ErpInfoRow('Meters',
            '${p.meters.toStringAsFixed(2)} m'),
        ErpInfoRow('No. of Joints', '${p.joints}'),
        ErpInfoRow('Stretch', p.stretch.isNotEmpty ? '${p.stretch}%' : '—'),
        if (p.size.isNotEmpty)
          ErpInfoRow('Size', p.size),
      ]),
    );
  }
}

// ── Weight card ───────────────────────────────────────────────
class _WeightCard extends StatelessWidget {
  final PackingDetail p;
  const _WeightCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'WEIGHT DETAILS',
      icon: Icons.monitor_weight_outlined,
      accentColor: ErpColors.warningAmber,
      child: Column(children: [
        // Visual weight summary
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          child: Row(children: [
            _WeightBox('Net', p.netWeight, ErpColors.successGreen),
            Container(width: 1, color: ErpColors.borderLight),
            _WeightBox('Tare', p.tareWeight, ErpColors.textSecondary),
            Container(width: 1, color: ErpColors.borderLight),
            _WeightBox('Gross', p.grossWeight, ErpColors.warningAmber),
          ]),
        ),
        const Divider(height: 1, color: ErpColors.borderLight),
        const SizedBox(height: 8),
        ErpInfoRow('Net Weight',   '${p.netWeight.toStringAsFixed(3)} kg'),
        ErpInfoRow('Tare Weight',  '${p.tareWeight.toStringAsFixed(3)} kg'),
        ErpInfoRow('Gross Weight', '${p.grossWeight.toStringAsFixed(3)} kg'),
      ]),
    );
  }
}

class _WeightBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _WeightBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text('${value.toStringAsFixed(2)}',
          style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text('$label kg',
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── QC card ───────────────────────────────────────────────────
class _QcCard extends StatelessWidget {
  final PackingDetail p;
  const _QcCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'QUALITY CONTROL',
      icon: Icons.verified_outlined,
      accentColor: ErpColors.successGreen,
      child: Column(children: [
        _QcRow(Icons.person_search_outlined, 'Checked By', p.checkedBy,
            ErpColors.successGreen),
        const SizedBox(height: 4),
        _QcRow(Icons.inventory_outlined, 'Packed By', p.packedBy,
            ErpColors.accentBlue),
      ]),
    );
  }
}

class _QcRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _QcRow(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              color: ErpColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800)),
    ]),
  );
}

// ── PDF action buttons ────────────────────────────────────────
class _PdfActions extends StatefulWidget {
  final PackingDetail p;
  const _PdfActions({required this.p});
  @override
  State<_PdfActions> createState() => _PdfActionsState();
}

class _PdfActionsState extends State<_PdfActions> {
  bool _generating = false;

  Future<void> _openPdf() async {
    setState(() => _generating = true);
    try {
      await PackingSlipPdf.generate(
        packingId:    widget.p.id,
        elasticName:  widget.p.elasticName,
        customerName: widget.p.customerName,
        po:           widget.p.po,
        jobOrderNo:   widget.p.jobOrderNo,
        joints:       widget.p.joints,
        checkedBy:    widget.p.checkedBy,
        packedBy:     widget.p.packedBy,
        meters:       widget.p.meters,
        stretch:      widget.p.stretch,     // String, as-stored in DB
        netWeight:    widget.p.netWeight,
        tareWeight:   widget.p.tareWeight,
        grossWeight:  widget.p.grossWeight,
        size:         widget.p.size,
      );
    } catch (e) {
      Get.snackbar('PDF Error', e.toString(),
          backgroundColor: const Color(0xFFDC2626),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _generating ? null : _openPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              disabledBackgroundColor:
              ErpColors.accentBlue.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: _generating
                ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined,
                size: 18, color: Colors.white),
            label: Text(
              _generating ? 'Generating…' : 'View Packing Slip',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _generating ? null : _openPdf, // opens PDF viewer, user can print from there
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.accentBlue),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.print_outlined,
              size: 18, color: ErpColors.accentBlue),
          label: const Text('Print',
              style: TextStyle(
                  color: ErpColors.accentBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    ]);
  }
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
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}