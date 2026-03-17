

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:production/src/features/PurchaseOrder/screnns/pdf.dart';
import '../controllers/add_po.dart';
import '../controllers/po_detail.dart';

import '../models/po_models.dart';
import '../services/theme.dart';
import 'add_po.dart';

import 'material_inward.dart';


class PODetailPage extends StatelessWidget {
  final String poId;
  const PODetailPage({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PODetailController(poId));
    return _PODetailView(c: c);
  }
}

class _PODetailView extends StatefulWidget {
  final PODetailController c;
  const _PODetailView({required this.c});

  @override
  State<_PODetailView> createState() => _PODetailViewState();
}

class _PODetailViewState extends State<_PODetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Obx(() {
      final po = c.po.value;
      return Scaffold(
        backgroundColor: ErpColors.bgBase,
        appBar: _buildAppBar(po, c),
        body: c.loading.value
            ? const Center(
            child: CircularProgressIndicator(
                color: ErpColors.accentBlue))
            : po == null
            ? const Center(child: Text("Purchase Order not found"))
            : Column(
          children: [
            _SummaryHeader(po: po),
            Container(
              color: ErpColors.bgSurface,
              child: TabBar(
                controller: _tabs,
                labelColor: ErpColors.accentBlue,
                unselectedLabelColor:
                ErpColors.textSecondary,
                indicatorColor: ErpColors.accentBlue,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13),
                tabs: [
                  Tab(text: "Items (${po.items.length})"),
                  Obx(() => Tab(
                      text:
                      "Inward (${c.inwardHistory.length})")),
                ],
              ),
            ),
            const Divider(
                height: 1, color: ErpColors.borderLight),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ItemsTab(po: po),
                  _InwardHistoryTab(c: c),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: po != null && po.status != 'Completed'
            ? FloatingActionButton.extended(
          onPressed: () async {
            final res = await Get.to(
                    () => MaterialInwardPage(),arguments: po);
            if (res == true) c.fetchDetail();
          },
          backgroundColor: ErpColors.accentBlue,
          icon: const Icon(Icons.input, color: Colors.white),
          label: const Text("Add Inward",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        )
            : null,
      );
    });
  }

  PreferredSizeWidget _buildAppBar(
      POModel? po, PODetailController c) {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              po != null ? "PO #${po.poNo}" : "PO Detail",
              style: ErpTextStyles.pageTitle,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              "Purchase Orders",
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        // ── PDF Preview button ─────────────────────────
        if (po != null)
          Obx(() => _PdfButton(
            po: po,
            inwardHistory: c.inwardHistory.toList(),
          )),
        // ── Clone ──────────────────────────────────────
        if (po != null)
          IconButton(
            icon: const Icon(Icons.copy_all_outlined,
                color: Colors.white70, size: 20),
            tooltip: "Clone PO",
            onPressed: () async {
              final res = await Get.to(() => AddPOPage(
                mode: POFormMode.clone,
                seedData: po.toCloneData(),
              ));
              if (res == true) c.fetchDetail();
            },
          ),
        // ── Edit (Open/Partial only) ───────────────────
        if (po != null && po.status != 'Completed')
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            tooltip: "Edit PO",
            onPressed: () async {
              final res = await Get.to(() => AddPOPage(
                mode: POFormMode.edit,
                seedData: po.toEditData(),
              ));
              if (res == true) c.fetchDetail();
            },
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

// ══════════════════════════════════════════════════════════════
//  PDF BUTTON — generates PDF then opens PdfPreviewPage
// ══════════════════════════════════════════════════════════════
class _PdfButton extends StatefulWidget {
  final POModel po;
  final List<InwardRecord> inwardHistory;

  const _PdfButton({required this.po, required this.inwardHistory});

  @override
  State<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<_PdfButton> {
  bool _loading = false;

  Future<void> _openPdf() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final bytes = await POPdfService.generate(
        widget.po,
        widget.inwardHistory,
      );
      if (!mounted) return;
      await Get.to(() => _PdfPreviewPage(
        pdfBytes: bytes,
        title: "PO #${widget.po.poNo}",
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to generate PDF: $e"),
            backgroundColor: ErpColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "View PDF",
      child: GestureDetector(
        onTap: _openPdf,
        child: Container(
          margin:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: Colors.white.withOpacity(0.25)),
          ),
          child: _loading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  size: 15, color: Colors.white),
              SizedBox(width: 5),
              Text(
                "PDF",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PDF PREVIEW PAGE — full-screen in-app viewer with share/print
// ══════════════════════════════════════════════════════════════
class _PdfPreviewPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const _PdfPreviewPage(
      {required this.pdfBytes, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: ErpTextStyles.pageTitle),
            const Text(
              "Purchase Order PDF",
              style: TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: PdfPreview(
        // Feed the already-generated bytes directly — no regeneration
        build: (_) => pdfBytes,
        // Clean up the built-in toolbar to match app style
        pdfPreviewPageDecoration: const BoxDecoration(
          color: Color(0xFFE5E8EF),
        ),
        previewPageMargin:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        // Show print + share actions at the bottom
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share_outlined),
            onPressed: (ctx, build, pageFormat) async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: '${title.replaceAll(' ', '_')}.pdf',
              );
            },
          ),
          PdfPreviewAction(
            icon: const Icon(Icons.print_outlined),
            onPressed: (ctx, build, pageFormat) async {
              await Printing.layoutPdf(
                onLayout: (_) => pdfBytes,
                name: title,
              );
            },
          ),
        ],
        // Remove the default "Open PDF" button — we provide our own
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        // Error widget styled to match app
        loadingWidget: const Center(
          child: CircularProgressIndicator(
              color: ErpColors.accentBlue),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SUMMARY HEADER
// ══════════════════════════════════════════════════════════════
class _SummaryHeader extends StatelessWidget {
  final POModel po;
  const _SummaryHeader({required this.po});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("dd MMM yyyy");
    final received = po.totalOrderValue > 0
        ? (po.totalOrderValue - po.totalPendingValue) /
        po.totalOrderValue
        : (po.status == 'Completed' ? 1.0 : 0.0);
    final progressColor =
    received >= 1 ? ErpColors.successGreen : ErpColors.accentBlue;

    return Container(
      color: ErpColors.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PURCHASE ORDER",
                          style: ErpTextStyles.fieldLabel),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            "#${po.poNo}",
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: ErpColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ErpStatusBadge(status: po.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFmt.format(po.date),
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("ORDER VALUE",
                        style: ErpTextStyles.fieldLabel),
                    const SizedBox(height: 3),
                    Text(
                      "₹${NumberFormat('#,##,###').format(po.totalOrderValue)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: ErpColors.textPrimary,
                      ),
                    ),
                    if (po.totalPendingValue > 0)
                      Text(
                        "Pending: ₹${NumberFormat('#,##,###').format(po.totalPendingValue)}",
                        style: const TextStyle(
                            color: ErpColors.warningAmber,
                            fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.business_outlined,
                    size: 13, color: ErpColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    po.supplier?.name ?? "—",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (po.supplier?.phone != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    po.supplier!.phone!,
                    style: const TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (po.supplier?.gstin != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(35, 2, 16, 0),
              child: Text(
                "GSTIN: ${po.supplier!.gstin!}",
                style: const TextStyle(
                    color: ErpColors.textMuted, fontSize: 11),
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("RECEIPT PROGRESS",
                        style: ErpTextStyles.fieldLabel),
                    Text(
                      "${(received * 100).clamp(0, 100).toStringAsFixed(0)}% received  ·  ${po.items.length} items",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: received.clamp(0, 1),
                    backgroundColor: ErpColors.borderLight,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: ErpColors.borderLight),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ITEMS TAB
// ══════════════════════════════════════════════════════════════
class _ItemsTab extends StatelessWidget {
  final POModel po;
  const _ItemsTab({required this.po});

  @override
  Widget build(BuildContext context) {
    if (po.items.isEmpty) {
      return const Center(
        child: Text("No items in this PO",
            style: TextStyle(color: ErpColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      itemCount: po.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) =>
          _ItemCard(item: po.items[i], index: i),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final POItem item;
  final int index;
  const _ItemCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final progress = item.quantity > 0
        ? (item.receivedQuantity / item.quantity).clamp(0.0, 1.0)
        : 0.0;
    final progressColor = item.isFullyReceived
        ? ErpColors.successGreen
        : progress > 0
        ? ErpColors.warningAmber
        : ErpColors.statusOpenText;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: const BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                  bottom: BorderSide(color: ErpColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                        color: progressColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.rawMaterial?.name ?? "—",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.rawMaterial?.unit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      border:
                      Border.all(color: ErpColors.borderMid),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      item.rawMaterial!.unit!,
                      style: const TextStyle(
                          color: ErpColors.textSecondary,
                          fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                _StatCell(
                    label: "ORDERED",
                    value: "${item.quantity} kg",
                    valueColor: ErpColors.textPrimary),
                const SizedBox(width: 8),
                _StatCell(
                    label: "RECEIVED",
                    value: "${item.receivedQuantity} kg",
                    valueColor: item.receivedQuantity > 0
                        ? ErpColors.successGreen
                        : ErpColors.textMuted),
                const SizedBox(width: 8),
                _StatCell(
                    label: "PENDING",
                    value: "${item.pendingQuantity} kg",
                    valueColor: item.pendingQuantity > 0
                        ? ErpColors.errorRed
                        : ErpColors.successGreen),
                const SizedBox(width: 8),
                _StatCell(
                    label: "PRICE",
                    value: "₹${item.price}",
                    valueColor: ErpColors.textPrimary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.isFullyReceived
                          ? "Fully Received"
                          : progress > 0
                          ? "Partially Received"
                          : "Not Received",
                      style: TextStyle(
                          color: progressColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "${(progress * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                          color: progressColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: ErpColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progressColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _StatCell(
      {required this.label,
        required this.value,
        required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INWARD HISTORY TAB
// ══════════════════════════════════════════════════════════════
class _InwardHistoryTab extends StatelessWidget {
  final PODetailController c;
  const _InwardHistoryTab({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.inwardHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.input_outlined,
                  size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text("No inward records yet",
                  style: TextStyle(
                      color: ErpColors.textSecondary, fontSize: 14)),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        itemCount: c.inwardHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) =>
            _InwardRecordCard(record: c.inwardHistory[i]),
      );
    });
  }
}

class _InwardRecordCard extends StatelessWidget {
  final InwardRecord record;
  const _InwardRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("dd MMM yyyy");
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ErpColors.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: ErpColors.successGreen.withOpacity(0.3)),
          ),
          child: const Icon(Icons.arrow_downward,
              size: 18, color: ErpColors.successGreen),
        ),
        title: Text(
          record.rawMaterial?.name ?? "—",
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateFmt.format(record.inwardDate),
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${record.quantity} kg",
              style: const TextStyle(
                  color: ErpColors.successGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
            if (record.remarks?.isNotEmpty == true)
              SizedBox(
                width: 100,
                child: Text(
                  record.remarks!,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}