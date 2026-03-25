import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';

import '../controller/supplier_list_controller.dart';

import 'edit_supplier_page.dart';

// ══════════════════════════════════════════════════════════════
//  SUPPLIER DETAIL PAGE
//  Sections:
//  • Hero card  (name, isActive badge, quick info strip)
//  • Contact Details
//  • Commercial
//  • Purchase Orders  (paginated, load-more on scroll)
//  • Deactivate button
// ══════════════════════════════════════════════════════════════
class SupplierDetailPage extends StatefulWidget {
  final String supplierId;
  const SupplierDetailPage({super.key, required this.supplierId});

  @override
  State<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends State<SupplierDetailPage> {
  late final SupplierDetailController _c;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.delete<SupplierDetailController>(force: true);
    _c = Get.put(
        SupplierDetailController(supplierId: widget.supplierId));
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
      _c.fetchPos();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _appBar(context),
      body: Obx(() {
        if (_c.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(
                  color: ErpColors.accentBlue));
        }
        if (_c.errorMsg.value != null && _c.supplier.isEmpty) {
          return _ErrorBody(
              msg: _c.errorMsg.value!, retry: _c.fetchSupplier);
        }
        final s = _c.supplier;
        if (s.isEmpty) return const SizedBox.shrink();

        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: () async {
            await _c.fetchSupplier();
            await _c.fetchPos(reset: true);
          },
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _HeroCard(supplier: s),
              const SizedBox(height: 14),
              _InfoSection(
                title: 'CONTACT DETAILS',
                icon: Icons.person_outline,
                rows: [
                  _InfoItem('Contact Person', s['contactPerson']),
                  _InfoItem('Phone',          s['phoneNumber']),
                  _InfoItem('Email',          s['email']),
                  if ((s['address'] as String?)?.isNotEmpty == true)
                    _InfoItem('Address', s['address']),
                ],
              ),
              const SizedBox(height: 10),
              _InfoSection(
                title: 'COMMERCIAL',
                icon: Icons.account_balance_outlined,
                rows: [
                  _InfoItem('GSTIN', s['gstin']),
                ],
              ),
              const SizedBox(height: 14),
              _PurchaseOrdersSection(c: _c),
              const SizedBox(height: 20),
              _DeactivateButton(c: _c),
            ],
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
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 16, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 4,
      title: const Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Supplier Details',
                style: ErpTextStyles.pageTitle,
                overflow: TextOverflow.ellipsis),
            Text('Suppliers  ›  Details',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      actions: [
        Obx(() {
          final s = _c.supplier;
          if (s.isEmpty) return const SizedBox();
          return IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            tooltip: 'Edit',
            onPressed: () async {
              final res = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditSupplierPage(
                      supplier: Map<String, dynamic>.from(s)),
                ),
              );
              if (res == true) _c.fetchSupplier();
            },
          );
        }),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Hero card ──────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  const _HeroCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final active  = supplier['isActive'] != false;
    final statusColor  = active ? ErpColors.successGreen : ErpColors.errorRed;
    final statusBg     = active ? ErpColors.statusCompletedBg : const Color(0xFFFEF2F2);
    final statusBorder = active ? ErpColors.statusCompletedBorder : const Color(0xFFFECACA);

    String? dateStr;
    try {
      if (supplier['createdAt'] != null) {
        dateStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(supplier['createdAt'].toString()));
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Navy gradient top band
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [ErpColors.navyDark, Color(0xFF0D1F35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              left: BorderSide(color: Color(0xFF7C3AED), width: 4),
            ),
          ),
          child: Row(children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                (supplier['name'] as String? ?? '?')
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier['name'] ?? '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  if (dateStr != null)
                    Text('Added $dateStr',
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub,
                            fontSize: 11)),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusBg,
                  border: Border.all(color: statusBorder),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                active ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
          ]),
        ),
        // Quick info strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            if ((supplier['phoneNumber'] as String?)?.isNotEmpty == true) ...[
              _QuickInfo(icon: Icons.phone_outlined,
                  value: supplier['phoneNumber']),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: _QuickInfo(
                  icon: Icons.receipt_outlined,
                  value: supplier['gstin'] ?? '—',
                  overflow: true),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _QuickInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool overflow;
  const _QuickInfo(
      {required this.icon, required this.value, this.overflow = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(value,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ErpColors.textPrimary),
        overflow: overflow ? TextOverflow.ellipsis : null);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: ErpColors.textMuted),
      const SizedBox(width: 6),
      overflow ? Expanded(child: text) : text,
    ]);
  }
}

// ── Info section ───────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoItem> rows;
  const _InfoSection(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(
                    bottom: BorderSide(color: ErpColors.borderLight)),
              ),
              child: Row(children: [
                Container(
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: ErpColors.accentBlue,
                        borderRadius: BorderRadius.circular(2))),
                Icon(icon, size: 13, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                Text(title, style: ErpTextStyles.sectionHeader),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  children: rows.map((r) => _buildRow(r)).toList()),
            ),
          ]),
    );
  }

  Widget _buildRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(item.label, style: ErpTextStyles.fieldLabel)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.value?.toString().isNotEmpty == true
                    ? item.value.toString()
                    : '—',
                style: ErpTextStyles.fieldValue,
              ),
            ),
          ]),
    );
  }
}

class _InfoItem {
  final String label;
  final dynamic value;
  const _InfoItem(this.label, this.value);
}

// ══════════════════════════════════════════════════════════════
//  PURCHASE ORDERS SECTION
// ══════════════════════════════════════════════════════════════
class _PurchaseOrdersSection extends StatelessWidget {
  final SupplierDetailController c;
  const _PurchaseOrdersSection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section header
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: ErpColors.bgMuted,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(
                    bottom: BorderSide(color: ErpColors.borderLight)),
              ),
              child: Row(children: [
                Container(
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: ErpColors.warningAmber,
                        borderRadius: BorderRadius.circular(2))),
                const Icon(Icons.assignment_outlined,
                    size: 13, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                Text('PURCHASE ORDERS',
                    style: ErpTextStyles.sectionHeader),
                const Spacer(),
                // PO count badge
                Obx(() => c.pos.isEmpty
                    ? const SizedBox()
                    : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: ErpColors.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                        ErpColors.warningAmber.withOpacity(0.35)),
                  ),
                  child: Text('${c.pos.length}',
                      style: const TextStyle(
                          color: ErpColors.warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                )),
              ]),
            ),

            Obx(() {
              if (c.isPosLoading.value) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: ErpColors.accentBlue)),
                );
              }
              if (c.pos.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 18, color: ErpColors.textMuted),
                        SizedBox(width: 8),
                        Text('No purchase orders yet',
                            style: TextStyle(
                                color: ErpColors.textMuted,
                                fontSize: 13)),
                      ]),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  ...c.pos.map((po) => _PoCard(po: po)),
                  // Load-more
                  if (c.isPosMoreLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: ErpColors.accentBlue)),
                    )
                  else if (c.posHasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => c.fetchPos(),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: ErpColors.borderMid),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6))),
                        icon: const Icon(Icons.expand_more,
                            size: 16, color: ErpColors.textSecondary),
                        label: const Text('Load more',
                            style: TextStyle(
                                color: ErpColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  else if (c.pos.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'All ${c.pos.length} orders shown',
                            style: const TextStyle(
                                color: ErpColors.textMuted, fontSize: 11),
                          ),
                        ),
                      ),
                ]),
              );
            }),
          ]),
    );
  }
}

// ── PO card ────────────────────────────────────────────────────
class _PoCard extends StatelessWidget {
  final Map<String, dynamic> po;
  const _PoCard({required this.po});

  static const _statusFg = {
    'Open':      Color(0xFF1D6AE5),
    'Partial':   Color(0xFFF59E0B),
    'Completed': Color(0xFF16A34A),
  };
  static const _statusBg = {
    'Open':      Color(0xFFEFF6FF),
    'Partial':   Color(0xFFFFFBEB),
    'Completed': Color(0xFFF0FDF4),
  };

  @override
  Widget build(BuildContext context) {
    final status  = po['status'] as String? ?? '—';
    final fg      = _statusFg[status] ?? ErpColors.textSecondary;
    final bg      = _statusBg[status] ?? ErpColors.bgMuted;
    final poNo    = po['poNo']?.toString() ?? '—';
    final items   = po['items'] as List? ?? [];
    final totalQty = items.fold<num>(
        0, (s, e) => s + ((e['quantity'] as num?) ?? 0));
    final totalAmt = items.fold<num>(
        0,
            (s, e) =>
        s +
            (((e['quantity'] as num?) ?? 0) *
                ((e['price'] as num?) ?? 0)));

    String? createdStr;
    try {
      if (po['createdAt'] != null) {
        createdStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(po['createdAt'].toString()));
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ErpColors.bgBase,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ErpColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: PO number + status
            Row(children: [
              const Icon(Icons.assignment_outlined,
                  size: 14, color: ErpColors.textMuted),
              const SizedBox(width: 5),
              Text('PO #$poNo',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(4)),
                child: Text(status,
                    style: TextStyle(
                        color: fg,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
              ),
            ]),
            const SizedBox(height: 8),
            const Divider(height: 1, color: ErpColors.borderLight),
            const SizedBox(height: 8),
            // Meta row
            Row(children: [
              _PoMeta(Icons.inventory_2_outlined,
                  '$totalQty units'),
              const SizedBox(width: 14),
              _PoMeta(Icons.currency_rupee,
                  totalAmt > 0 ? '₹${totalAmt.toStringAsFixed(0)}' : '—'),
              const Spacer(),
              if (createdStr != null)
                Text(createdStr,
                    style: const TextStyle(
                        color: ErpColors.textMuted, fontSize: 10)),
            ]),
            // Items preview
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: items.take(3).map((item) {
                  final matName =
                  (item['rawMaterial'] is Map)
                      ? item['rawMaterial']['name'] ?? '—'
                      : '—';
                  final qty = item['quantity']?.toString() ?? '0';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: ErpColors.bgMuted,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: ErpColors.borderLight),
                    ),
                    child: Text('$matName · $qty',
                        style: const TextStyle(
                            fontSize: 10,
                            color: ErpColors.textSecondary)),
                  );
                }).toList(),
              ),
            ],
          ]),
    );
  }
}

class _PoMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PoMeta(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: ErpColors.textMuted),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 11)),
    ],
  );
}

// ── Deactivate button ──────────────────────────────────────────
class _DeactivateButton extends StatelessWidget {
  final SupplierDetailController c;
  const _DeactivateButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = c.supplier['isActive'] != false;
      if (!active) return const SizedBox();
      return OutlinedButton.icon(
        onPressed: () => _confirmDeactivate(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: ErpColors.errorRed),
          padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.block_outlined,
            size: 16, color: ErpColors.errorRed),
        label: const Text('Deactivate Supplier',
            style: TextStyle(
                color: ErpColors.errorRed,
                fontWeight: FontWeight.w600)),
      );
    });
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        title: const Text('Deactivate Supplier',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will mark the supplier as inactive. '
                'You can reactivate them later by editing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style:
                TextStyle(color: ErpColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final ok = await c.deactivate();
              if (ok && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Deactivate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Error body ─────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String msg;
  final VoidCallback retry;
  const _ErrorBody({required this.msg, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined,
            size: 48, color: ErpColors.textMuted),
        const SizedBox(height: 14),
        const Text('Failed to load supplier',
            style: TextStyle(
                color: ErpColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(msg,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: retry,
          style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.refresh,
              size: 16, color: Colors.white),
          label: const Text('Retry',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}