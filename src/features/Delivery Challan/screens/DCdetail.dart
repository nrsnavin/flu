import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:production/src/features/Delivery%20Challan/screens/pdf.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../models/dc_model.dart';


// ════════════════════════════════════════════════════════════════
//  CONTROLLER
// ════════════════════════════════════════════════════════════════
class DCDetailController extends GetxController {
  final String dcId;
  DCDetailController(this.dcId);

  final _dio = Dio(BaseOptions(
    baseUrl: 'http://13.233.117.153:2701/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final loading  = false.obs;
  final updating = false.obs;
  final dc       = Rx<DCDetail?>(null);
  final error    = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    try {
      loading.value = true;
      error.value   = null;
      final res = await _dio.get('/dc/detail', queryParameters: {'id': dcId});
      dc.value = DCDetail.fromJson(res.data['dc'] as Map<String, dynamic>);
    } on DioException catch (e) {
      error.value = e.response?.data?['message'] ?? 'Failed to load';
    } finally {
      loading.value = false;
    }
  }

  Future<void> updateStatus(String status, {required VoidCallback onDone}) async {
    try {
      updating.value = true;
      await _dio.patch('/dc/update-status', data: {'id': dcId, 'status': status});
      await fetchDetail();
      Get.snackbar('Updated', 'Status changed to ${status.capitalizeFirst}',
          backgroundColor: ErpColors.successGreen, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      onDone();
    } on DioException catch (e) {
      Get.snackbar('Error', e.response?.data?['message'] ?? 'Update failed',
          backgroundColor: ErpColors.errorRed, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      updating.value = false;
    }
  }

  Future<void> deleteDC({required VoidCallback onDeleted}) async {
    try {
      updating.value = true;
      await _dio.delete('/dc/delete', queryParameters: {'id': dcId});
      Get.snackbar('Deleted', 'Delivery Challan deleted',
          backgroundColor: const Color(0xFF16A34A), colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      onDeleted();
    } on DioException catch (e) {
      Get.snackbar('Error', e.response?.data?['message'] ?? 'Delete failed',
          backgroundColor: ErpColors.errorRed, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      updating.value = false;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════
class DCDetailPage extends StatefulWidget {
  final String dcId;
  const DCDetailPage({super.key, required this.dcId});
  @override
  State<DCDetailPage> createState() => _DCDetailPageState();
}

class _DCDetailPageState extends State<DCDetailPage> {
  late final DCDetailController c;

  @override
  void initState() {
    super.initState();
    Get.delete<DCDetailController>(force: true);
    c = Get.put(DCDetailController(widget.dcId));
  }

  @override
  void dispose() {
    Get.delete<DCDetailController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(context),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        if (c.error.value != null) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: ErpColors.errorRed, size: 38),
            const SizedBox(height: 8),
            Text(c.error.value!, style: const TextStyle(color: ErpColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: c.fetchDetail, child: const Text('Retry')),
          ]));
        }
        final d = c.dc.value;
        if (d == null) return const SizedBox.shrink();
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchDetail,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
            child: Column(children: [
              _HeroBanner(d: d),
              const SizedBox(height: 12),
              _CustomerSection(d: d),
              const SizedBox(height: 10),
              _DispatchSection(d: d),
              const SizedBox(height: 10),
              _ItemsSection(d: d),
              const SizedBox(height: 10),
              if (d.remarks.isNotEmpty) ...[
                _RemarksSection(d: d),
                const SizedBox(height: 10),
              ],
              _StatusSection(d: d, c: c),
            ]),
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: Obx(() {
        final d = c.dc.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d?.dcNumber ?? 'DC Detail', style: ErpTextStyles.pageTitle),
            Text('Dispatch  ›  Detail',
                style: const TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        );
      }),
      actions: [
        Obx(() {
          final d = c.dc.value;
          if (d == null) return const SizedBox.shrink();
          return Row(mainAxisSize: MainAxisSize.min, children: [
            // PDF button
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.white),
              tooltip: 'View / Print PDF',
              onPressed: c.loading.value ? null : () => _openPdf(context, d),
            ),
            // Copy DC number
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18, color: Colors.white70),
              tooltip: 'Copy DC Number',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: d.dcNumber));
                Get.snackbar('Copied', d.dcNumber,
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2));
              },
            ),
            // Delete (draft only)
            if (d.status == 'draft')
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFFC8181)),
                tooltip: 'Delete',
                onPressed: c.updating.value
                    ? null
                    : () => _confirmDelete(context),
              ),
            const SizedBox(width: 6),
          ]);
        }),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  // ── Open PDF preview ────────────────────────────────────────
  Future<void> _openPdf(BuildContext context, DCDetail d) async {
    try {
      final bytes = await DCPdfService.generate(d);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _DCPdfPreviewPage(
          pdfBytes: bytes,
          title: d.dcNumber,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: $e'),
            backgroundColor: ErpColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final d = c.dc.value;
    if (d == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: ErpColors.errorRed.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline, color: ErpColors.errorRed, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Delete Challan', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary, height: 1.5),
            children: [
              const TextSpan(text: 'Delete '),
              TextSpan(text: d.dcNumber, style: const TextStyle(
                  fontWeight: FontWeight.w800, color: ErpColors.textPrimary)),
              const TextSpan(text: '?\n\nThis is permanent and cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.borderMid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(
                color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.errorRed, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
            label: const Text('Delete', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ])],
      ),
    );

    if (confirmed == true && mounted) {
      c.deleteDC(onDeleted: () => Navigator.of(context).pop());
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  DETAIL SECTIONS
// ════════════════════════════════════════════════════════════════

// ── Hero banner with DC number + totals ──────────────────────
class _HeroBanner extends StatelessWidget {
  final DCDetail d;
  const _HeroBanner({required this.d});

  @override
  Widget build(BuildContext context) {
    final typeColor = d.isElastic ? ErpColors.accentBlue : const Color(0xFF7C3AED);
    final typeLabel = d.isElastic ? 'ELASTIC' : 'MACHINE PART';
    final statusColor = _statusColor(d.status);
    String dateStr = '—';
    try { dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(d.dispatchDate)); } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ErpColors.navyDark, typeColor.withOpacity(0.85)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: typeColor.withOpacity(0.25),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: type badge + status
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: Text(typeLabel, style: const TextStyle(
                color: Colors.white70, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withOpacity(0.30)),
            ),
            child: Text(d.status.toUpperCase(), style: TextStyle(
                color: statusColor, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
          const Spacer(),
          Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
        const SizedBox(height: 10),

        // DC Number — large
        Text(d.dcNumber, style: const TextStyle(
            color: Colors.white, fontSize: 26,
            fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        if (d.orderNo != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Order #${d.orderNo}', style: const TextStyle(
                color: Colors.white60, fontSize: 11)),
          ),
        const SizedBox(height: 14),

        // Stats row
        Row(children: [
          _HeroStat(
            label: d.isElastic ? 'TOTAL QTY' : 'TOTAL ITEMS',
            value: d.isElastic
                ? '${d.totalQuantity.toStringAsFixed(0)} m'
                : d.totalQuantity.toStringAsFixed(0),
          ),
          const SizedBox(width: 10),
          if (d.totalAmount > 0)
            _HeroStat(
              label: 'TOTAL AMOUNT',
              value: '₹${NumberFormat('#,##0.##').format(d.totalAmount)}',
            ),
          const SizedBox(width: 10),
          _HeroStat(label: 'ITEMS', value: '${d.items.length}'),
        ]),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 15,
          fontWeight: FontWeight.w900)),
    ]),
  );
}

// ── Customer ─────────────────────────────────────────────────
class _CustomerSection extends StatelessWidget {
  final DCDetail d;
  const _CustomerSection({required this.d});

  @override
  Widget build(BuildContext context) => _Section(
    title: 'CUSTOMER', icon: Icons.person_outline_rounded,
    child: Column(children: [
      ErpInfoRow('Name',    d.customerName),
      if (d.customerPhone.isNotEmpty)   ErpInfoRow('Phone',   d.customerPhone),
      if (d.customerGstin.isNotEmpty)   ErpInfoRow('GSTIN',   d.customerGstin),
      if (d.customerAddress.isNotEmpty) ErpInfoRow('Address', d.customerAddress),
    ]),
  );
}

// ── Dispatch ─────────────────────────────────────────────────
class _DispatchSection extends StatelessWidget {
  final DCDetail d;
  const _DispatchSection({required this.d});

  @override
  Widget build(BuildContext context) {
    String dateStr = d.dispatchDate;
    try { dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(d.dispatchDate)); } catch (_) {}

    return _Section(
      title: 'DISPATCH DETAILS', icon: Icons.local_shipping_outlined,
      child: Column(children: [
        ErpInfoRow('Dispatch Date', dateStr),
        if (d.vehicleNo.isNotEmpty)   ErpInfoRow('Vehicle No',  d.vehicleNo),
        if (d.driverName.isNotEmpty)  ErpInfoRow('Driver',      d.driverName),
        if (d.transporter.isNotEmpty) ErpInfoRow('Transporter', d.transporter),
        if (d.lrNumber.isNotEmpty)    ErpInfoRow('LR Number',   d.lrNumber),
      ]),
    );
  }
}

// ── Items table ───────────────────────────────────────────────
class _ItemsSection extends StatelessWidget {
  final DCDetail d;
  const _ItemsSection({required this.d});

  @override
  Widget build(BuildContext context) {
    final typeColor = d.isElastic ? ErpColors.accentBlue : const Color(0xFF7C3AED);

    return _Section(
      title: d.isElastic ? 'ELASTIC ITEMS' : 'PART / SERVICE ITEMS',
      icon: d.isElastic ? Icons.layers_outlined : Icons.precision_manufacturing_outlined,
      accentColor: typeColor,
      child: Column(children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: typeColor.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Expanded(flex: 3, child: Text('ITEM',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: ErpColors.textSecondary, letterSpacing: 0.4))),
            const SizedBox(width: 6,
                child: Text('QTY', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: ErpColors.textSecondary))),
            Expanded(flex: 1, child: Text('QTY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: typeColor, letterSpacing: 0.4),
                textAlign: TextAlign.right)),
            const SizedBox(width: 8),
            const Expanded(flex: 1, child: Text('RATE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: ErpColors.textSecondary), textAlign: TextAlign.right)),
            const SizedBox(width: 8),
            const Expanded(flex: 1, child: Text('AMT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: ErpColors.successGreen), textAlign: TextAlign.right)),
          ]),
        ),
        const SizedBox(height: 4),

        // Rows
        ...d.items.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value;
          final isEven = i.isEven;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isEven ? ErpColors.bgMuted : ErpColors.bgSurface,
              border: const Border(
                  bottom: BorderSide(color: ErpColors.borderLight, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: ErpColors.textPrimary)),
                  Text(item.unit, style: const TextStyle(
                      fontSize: 10, color: ErpColors.textMuted)),
                ],
              )),
              Expanded(flex: 1, child: Text(
                item.quantity.toStringAsFixed(
                    item.quantity % 1 == 0 ? 0 : 2),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: typeColor),
                textAlign: TextAlign.right,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: Text(
                item.rate > 0 ? '₹${_fmt(item.rate)}' : '—',
                style: const TextStyle(fontSize: 11, color: ErpColors.textSecondary),
                textAlign: TextAlign.right,
              )),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: Text(
                item.amount > 0 ? '₹${_fmt(item.amount)}' : '—',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: ErpColors.successGreen),
                textAlign: TextAlign.right,
              )),
            ]),
          );
        }),

        // Totals row
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: typeColor.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Expanded(flex: 3, child: Text('TOTAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: ErpColors.textPrimary))),
            Expanded(flex: 1, child: Text(
              d.totalQuantity.toStringAsFixed(
                  d.totalQuantity % 1 == 0 ? 0 : 2),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: typeColor),
              textAlign: TextAlign.right,
            )),
            const SizedBox(width: 8),
            const Expanded(flex: 1, child: SizedBox.shrink()),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: Text(
              d.totalAmount > 0 ? '₹${_fmt(d.totalAmount)}' : '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  color: ErpColors.successGreen),
              textAlign: TextAlign.right,
            )),
          ]),
        ),
      ]),
    );
  }
  String _fmt(double v) => NumberFormat('#,##0.##').format(v);
}

// ── Remarks ───────────────────────────────────────────────────
class _RemarksSection extends StatelessWidget {
  final DCDetail d;
  const _RemarksSection({required this.d});

  @override
  Widget build(BuildContext context) => _Section(
    title: 'REMARKS', icon: Icons.notes_outlined,
    child: Text(d.remarks, style: ErpTextStyles.fieldValue),
  );
}

// ── Status update section ─────────────────────────────────────
class _StatusSection extends StatelessWidget {
  final DCDetail d;
  final DCDetailController c;
  const _StatusSection({required this.d, required this.c});

  static const _flow = [
    ('draft',       'Draft',       Icons.edit_note_outlined,     ErpColors.warningAmber),
    ('dispatched',  'Dispatched',  Icons.local_shipping_outlined, ErpColors.accentBlue),
    ('delivered',   'Delivered',   Icons.check_circle_outline,    ErpColors.successGreen),
    ('cancelled',   'Cancelled',   Icons.cancel_outlined,         ErpColors.errorRed),
  ];

  String? _nextStatus() => switch (d.status) {
    'draft'     => 'dispatched',
    'dispatched' => 'delivered',
    _            => null,
  };

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus();
    if (d.status == 'delivered' || d.status == 'cancelled') {
      return const SizedBox.shrink();
    }

    return _Section(
      title: 'STATUS', icon: Icons.timeline_outlined,
      child: Column(children: [
        // Progress steps
        Row(children: _flow.where((f) => f.$1 != 'cancelled').map((f) {
          final idx      = _flow.indexOf(f);
          final curIdx   = _flow.indexWhere((e) => e.$1 == d.status);
          final done     = idx <= curIdx;
          final current  = f.$1 == d.status;

          return Expanded(child: Row(children: [
            if (idx > 0) Expanded(child: Container(
              height: 2,
              color: done ? f.$4.withOpacity(0.5) : ErpColors.borderLight,
            )),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current
                    ? f.$4.withOpacity(0.15)
                    : done ? f.$4.withOpacity(0.08) : ErpColors.bgMuted,
                border: Border.all(
                  color: done ? f.$4 : ErpColors.borderLight,
                  width: current ? 2 : 1,
                ),
              ),
              child: Icon(f.$3,
                  size: 16,
                  color: done ? f.$4 : ErpColors.textMuted),
            ),
          ]));
        }).toList()),
        const SizedBox(height: 6),
        // Status label row
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _flow.where((f) => f.$1 != 'cancelled').map((f) {
              final curIdx = _flow.indexWhere((e) => e.$1 == d.status);
              final idx    = _flow.indexOf(f);
              final active = idx <= curIdx;
              return Text(f.$2, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: active ? f.$4 : ErpColors.textMuted));
            }).toList()),

        const SizedBox(height: 16),

        // Action buttons
        Obx(() => Row(children: [
          if (d.status == 'draft') ...[
            Expanded(child: _actionBtn(
              label: 'Mark Dispatched',
              icon: Icons.local_shipping_outlined,
              color: ErpColors.accentBlue,
              loading: c.updating.value,
              onTap: () => _confirmStatus(context, 'dispatched'),
            )),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: c.updating.value
                    ? null : () => _confirmStatus(context, 'cancelled'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ErpColors.errorRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Cancel DC',
                    style: TextStyle(color: ErpColors.errorRed, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          if (d.status == 'dispatched')
            Expanded(child: _actionBtn(
              label: 'Mark Delivered',
              icon: Icons.check_circle_outline,
              color: ErpColors.successGreen,
              loading: c.updating.value,
              onTap: () => _confirmStatus(context, 'delivered'),
            )),
        ])),
      ]),
    );
  }

  Widget _actionBtn({required String label, required IconData icon,
    required Color color, required bool loading, required VoidCallback onTap}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: loading
            ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _confirmStatus(BuildContext context, String status) {
    final labels = <String, String>{
      'dispatched': 'Mark as Dispatched',
      'delivered':  'Mark as Delivered',
      'cancelled':  'Cancel this DC',
    };
    final colors = <String, Color>{
      'dispatched': ErpColors.accentBlue,
      'delivered':  ErpColors.successGreen,
      'cancelled':  ErpColors.errorRed,
    };
    final color = colors[status] ?? ErpColors.accentBlue;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(labels[status] ?? 'Update Status',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: ErpColors.textPrimary)),
        content: Text(
          'Confirm status change to "${status.capitalizeFirst}" for ${d.dcNumber}?',
          style: const TextStyle(fontSize: 13, color: ErpColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.borderMid),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(
                color: ErpColors.textSecondary, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              c.updateStatus(status, onDone: () {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Confirm', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ])],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  const _Section({required this.title, required this.icon, required this.child,
    this.accentColor = ErpColors.accentBlue});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      border: Border.all(color: ErpColors.borderLight),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
          blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
        ),
        child: Row(children: [
          Container(width: 3, height: 12, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          Icon(icon, size: 13, color: ErpColors.textSecondary),
          const SizedBox(width: 6),
          Text(title, style: ErpTextStyles.sectionHeader),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

Color _statusColor(String s) => switch (s) {
  'draft'      => ErpColors.warningAmber,
  'dispatched' => ErpColors.accentBlue,
  'delivered'  => ErpColors.successGreen,
  'cancelled'  => ErpColors.errorRed,
  _            => ErpColors.textSecondary,
};

// ════════════════════════════════════════════════════════════════
//  PDF PREVIEW PAGE
// ════════════════════════════════════════════════════════════════
class _DCPdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  const _DCPdfPreviewPage({required this.pdfBytes, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: ErpTextStyles.pageTitle),
            const Text('Delivery Challan  ›  PDF Preview',
                style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: PdfPreview(
        build: (_) => pdfBytes,
        pdfPreviewPageDecoration: const BoxDecoration(color: Color(0xFFE5E8EF)),
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: ErpColors.accentBlue),
        ),
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: (ctx, build, pageFormat) async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: '${title.replaceAll('/', '-').replaceAll(' ', '_')}.pdf',
              );
            },
          ),
          PdfPreviewAction(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            onPressed: (ctx, build, pageFormat) async {
              await Printing.layoutPdf(
                onLayout: (_) => pdfBytes,
                name: title,
              );
            },
          ),
        ],
      ),
    );
  }
}