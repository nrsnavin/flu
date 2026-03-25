import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';

import '../controllers/customer_controller.dart';
import 'edit_customer_page.dart';

// ══════════════════════════════════════════════════════════════
//  CUSTOMER DETAIL PAGE
//  Shows:
//  • Hero card (name / status / quick contacts)
//  • Primary Contact, Commercial, contact dept sections
//  • Running Orders strip  — all active orders at a glance
//  • Past Orders list      — paginated, load-more on scroll
// ══════════════════════════════════════════════════════════════
class CustomerDetailPage extends StatefulWidget {
  final String customerId;
  const CustomerDetailPage({super.key, required this.customerId});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late final CustomerDetailController _c;
  late final CustomerOrdersController _oc;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.delete<CustomerDetailController>(force: true);
    Get.delete<CustomerOrdersController>(force: true);
    _c  = Get.put(CustomerDetailController(customerId: widget.customerId));
    _oc = Get.put(CustomerOrdersController(customerId: widget.customerId));
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
      _oc.fetchOrders();
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
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (_c.loading.value) {
          return const Center(
              child: CircularProgressIndicator(color: ErpColors.accentBlue));
        }
        final data = _c.customerData;
        if (data.isEmpty) {
          return const Center(child: Text('Customer not found'));
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: () async {
            await _c.fetchCustomer();
            await _oc.fetchOrders(reset: true);
          },
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _HeroCard(data: data),
              const SizedBox(height: 14),
              _InfoSection(
                title: 'PRIMARY CONTACT',
                icon: Icons.person_outline,
                rows: [
                  _InfoItem('Contact Name', data['contactName']),
                  _InfoItem('Phone',        data['phoneNumber']),
                  _InfoItem('Email',        data['email']),
                ],
              ),
              const SizedBox(height: 10),
              _InfoSection(
                title: 'COMMERCIAL',
                icon: Icons.account_balance_outlined,
                rows: [
                  _InfoItem('GSTIN',         data['gstin']),
                  _InfoItem('Payment Terms', _payLabel(data['paymentTerms'])),
                  _InfoItem('Status',        data['status']),
                ],
              ),
              if (_hasContact(data['purchase'])) ...[
                const SizedBox(height: 10),
                _ContactSection(title: 'PURCHASE',     data: data['purchase']),
              ],
              if (_hasContact(data['accountant'])) ...[
                const SizedBox(height: 10),
                _ContactSection(title: 'ACCOUNTS',     data: data['accountant']),
              ],
              if (_hasContact(data['merchandiser'])) ...[
                const SizedBox(height: 10),
                _ContactSection(title: 'MERCHANDISER', data: data['merchandiser']),
              ],

              // ── Orders ──────────────────────────────────
              const SizedBox(height: 14),
              _RunningOrdersSection(oc: _oc),
              const SizedBox(height: 10),
              _PastOrdersSection(oc: _oc),

              const SizedBox(height: 20),
              _DeactivateButton(c: _c),
            ],
          ),
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
            Text('Customer Details', style: ErpTextStyles.pageTitle,
                overflow: TextOverflow.ellipsis),
            Text('Customers  ›  Details',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      actions: [
        Obx(() {
          final data = _c.customerData;
          if (data.isEmpty) return const SizedBox();
          return IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            tooltip: 'Edit',
            onPressed: () async {
              final res = await Get.to(
                    () => EditCustomerPage(
                    customer: Map<String, dynamic>.from(data)),
              );
              if (res == true) {
                _c.fetchCustomer();
                _oc.fetchOrders(reset: true);
              }
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

  bool _hasContact(dynamic val) {
    if (val == null) return false;
    final m = val as Map?;
    return m != null &&
        ((m['name'] as String?)?.isNotEmpty == true ||
            (m['mobile'] as String?)?.isNotEmpty == true ||
            (m['email'] as String?)?.isNotEmpty == true);
  }

  String _payLabel(dynamic val) {
    if (val == null || val.toString().isEmpty) return '—';
    if (val == 'Advance') return 'Advance';
    return '${val} Days';
  }
}

// ══════════════════════════════════════════════════════════════
//  RUNNING ORDERS SECTION
//  All active / in-progress orders — no pagination
// ══════════════════════════════════════════════════════════════
class _RunningOrdersSection extends StatelessWidget {
  final CustomerOrdersController oc;
  const _RunningOrdersSection({required this.oc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading  = oc.isLoadingFirst.value;
      final orders   = oc.runningOrders;
      final hasError = oc.errorMsg.value != null;

      return _SectionShell(
        title: 'RUNNING ORDERS',
        icon: Icons.pending_actions_outlined,
        accentColor: ErpColors.accentBlue,
        trailing: orders.isEmpty
            ? null
            : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: ErpColors.accentBlue.withOpacity(0.35)),
          ),
          child: Text('${orders.length}',
              style: const TextStyle(
                  color: ErpColors.accentBlue,
                  fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        child: loading
            ? const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(
                    color: ErpColors.accentBlue)))
            : hasError
            ? _OrderError(msg: oc.errorMsg.value!, onRetry: () => oc.fetchOrders(reset: true))
            : orders.isEmpty
            ? const _NoOrders(label: 'No active orders')
            : Column(
          children: orders
              .map((o) => _OrderCard(order: o, isRunning: true))
              .toList(),
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
//  PAST ORDERS SECTION
//  Completed / Cancelled — paginated with load-more footer
// ══════════════════════════════════════════════════════════════
class _PastOrdersSection extends StatelessWidget {
  final CustomerOrdersController oc;
  const _PastOrdersSection({required this.oc});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading  = oc.isLoadingFirst.value;
      final orders   = oc.pastOrders;
      final hasError = oc.errorMsg.value != null && orders.isEmpty;

      return _SectionShell(
        title: 'PAST ORDERS',
        icon: Icons.history_rounded,
        accentColor: ErpColors.textMuted,
        child: loading
            ? const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(
                    color: ErpColors.accentBlue)))
            : hasError
            ? _OrderError(msg: oc.errorMsg.value!, onRetry: () => oc.fetchOrders(reset: true))
            : orders.isEmpty
            ? const _NoOrders(label: 'No past orders')
            : Column(
          children: [
            ...orders.map((o) =>
                _OrderCard(order: o, isRunning: false)),
            // Load-more footer
            if (oc.isLoadingMore.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                    child: CircularProgressIndicator(
                        color: ErpColors.accentBlue)),
              )
            else if (oc.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => oc.fetchOrders(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: ErpColors.borderMid),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.expand_more,
                      size: 16,
                      color: ErpColors.textSecondary),
                  label: const Text('Load more',
                      style: TextStyle(
                          color: ErpColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ),
              )
            else if (orders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      'All ${orders.length} past order${orders.length == 1 ? '' : 's'} shown',
                      style: const TextStyle(
                          color: ErpColors.textMuted,
                          fontSize: 11),
                    ),
                  ),
                ),
          ],
        ),
      );
    });
  }
}

// ── Order card ────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isRunning;
  const _OrderCard({required this.order, required this.isRunning});

  // Status → colour mapping
  static const _statusColors = {
    'Open':       Color(0xFF1D6AE5),
    'Approved':   Color(0xFF0891B2),
    'InProgress': Color(0xFF7C3AED),
    'Completed':  Color(0xFF16A34A),
    'Cancelled':  Color(0xFFDC2626),
  };
  static const _statusBg = {
    'Open':       Color(0xFFEFF6FF),
    'Approved':   Color(0xFFE0F4F8),
    'InProgress': Color(0xFFF5F3FF),
    'Completed':  Color(0xFFF0FDF4),
    'Cancelled':  Color(0xFFFEF2F2),
  };

  @override
  Widget build(BuildContext context) {
    final status     = order['status'] as String? ?? '—';
    final fg         = _statusColors[status] ?? ErpColors.textSecondary;
    final bg         = _statusBg[status]     ?? ErpColors.bgMuted;
    final orderNo    = order['orderNo']?.toString()   ?? '—';
    final po         = order['po']?.toString()        ?? '—';
    final elastics   = order['elasticOrdered'] as List? ?? [];
    final totalQty   = elastics.fold<int>(
        0, (s, e) => s + ((e['quantity'] as num?)?.toInt() ?? 0));

    String? supplyStr;
    try {
      if (order['supplyDate'] != null) {
        supplyStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(order['supplyDate'].toString()));
      }
    } catch (_) {}

    String? createdStr;
    try {
      if (order['createdAt'] != null) {
        createdStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(order['createdAt'].toString()));
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRunning
              ? ErpColors.accentBlue.withOpacity(0.25)
              : ErpColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: order number + status
          Row(children: [
            Expanded(
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 14, color: ErpColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  'Order #$orderNo',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary),
                ),
                if (po.isNotEmpty && po != '—') ...[
                  const SizedBox(width: 6),
                  Text('· PO: $po',
                      style: const TextStyle(
                          fontSize: 11, color: ErpColors.textSecondary)),
                ],
              ]),
            ),
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(4)),
              child: Text(
                status,
                style: TextStyle(
                    color: fg, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
            ),
          ]),

          const SizedBox(height: 8),
          const Divider(height: 1, color: ErpColors.borderLight),
          const SizedBox(height: 8),

          // Meta row: quantity + dates
          Row(children: [
            if (totalQty > 0) ...[
              _Meta(Icons.straighten_outlined, '$totalQty m ordered'),
              const SizedBox(width: 14),
            ],
            if (supplyStr != null)
              _Meta(Icons.local_shipping_outlined, 'Due $supplyStr'),
            const Spacer(),
            if (createdStr != null)
              Text(createdStr,
                  style: const TextStyle(
                      color: ErpColors.textMuted, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Meta(this.icon, this.label);
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

class _NoOrders extends StatelessWidget {
  final String label;
  const _NoOrders({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inbox_outlined, size: 18, color: ErpColors.textMuted),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted, fontSize: 13)),
    ]),
  );
}

class _OrderError extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _OrderError({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined,
          size: 28, color: ErpColors.textMuted),
      const SizedBox(height: 6),
      Text(msg,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: ErpColors.borderMid)),
        icon: const Icon(Icons.refresh, size: 14, color: ErpColors.textSecondary),
        label: const Text('Retry',
            style: TextStyle(color: ErpColors.textSecondary)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  SHARED SECTION SHELL
// ══════════════════════════════════════════════════════════════
class _SectionShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;
  final Widget child;
  const _SectionShell({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2))),
          Icon(icon, size: 13, color: ErpColors.textSecondary),
          const SizedBox(width: 6),
          Text(title, style: ErpTextStyles.sectionHeader),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ]),
      ),
      // Body
      Padding(padding: const EdgeInsets.all(12), child: child),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  HERO CARD  (unchanged from original)
// ══════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final active       = data['status'] == 'Active';
    final statusColor  = active ? ErpColors.successGreen : ErpColors.errorRed;
    final statusBg     = active ? ErpColors.statusCompletedBg : const Color(0xFFFEF2F2);
    final statusBorder = active ? ErpColors.statusCompletedBorder : const Color(0xFFFECACA);

    String? dateStr;
    try {
      if (data['createdAt'] != null) {
        dateStr = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(data['createdAt'].toString()));
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ErpColors.borderLight),
        boxShadow: [BoxShadow(
          color: ErpColors.navyDark.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        // Navy band
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: const BoxDecoration(
            color: ErpColors.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: ErpColors.accentBlue.withOpacity(0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                (data['name'] as String? ?? '?')
                    .substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? '—',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  if (dateStr != null)
                    Text('Added $dateStr',
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 11)),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusBg,
                  border: Border.all(color: statusBorder),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                active ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(color: statusColor, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ]),
        ),
        // Quick info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            _QuickInfo(icon: Icons.phone_outlined,
                value: data['phoneNumber'] ?? '—'),
            const SizedBox(width: 16),
            Expanded(child: _QuickInfo(
                icon: Icons.email_outlined,
                value: data['email'] ?? '—',
                overflow: true)),
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
            fontSize: 13, fontWeight: FontWeight.w500,
            color: ErpColors.textPrimary),
        overflow: overflow ? TextOverflow.ellipsis : null);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: ErpColors.textMuted),
      const SizedBox(width: 6),
      overflow ? Expanded(child: text) : text,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  INFO SECTIONS  (unchanged from original)
// ══════════════════════════════════════════════════════════════
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoItem> rows;
  const _InfoSection(
      {required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: ErpColors.borderLight),
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
          Container(
              width: 3, height: 12,
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
        child: Column(children: rows.map(_buildRow).toList()),
      ),
    ]),
  );

  Widget _buildRow(_InfoItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
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

class _InfoItem {
  final String label;
  final dynamic value;
  const _InfoItem(this.label, this.value);
}

class _ContactSection extends StatelessWidget {
  final String title;
  final dynamic data;
  const _ContactSection({required this.title, required this.data});
  @override
  Widget build(BuildContext context) {
    final m = data as Map? ?? {};
    return _InfoSection(
      title: title,
      icon: Icons.contact_phone_outlined,
      rows: [
        _InfoItem('Name',   m['name']),
        _InfoItem('Mobile', m['mobile']),
        _InfoItem('Email',  m['email']),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DEACTIVATE BUTTON  (unchanged)
// ══════════════════════════════════════════════════════════════
class _DeactivateButton extends StatelessWidget {
  final CustomerDetailController c;
  const _DeactivateButton({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() {
    final active = c.customerData['status'] == 'Active';
    if (!active) return const SizedBox();
    return OutlinedButton.icon(
      onPressed: () => _confirmDeactivate(context),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: ErpColors.errorRed),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.block_outlined,
          size: 16, color: ErpColors.errorRed),
      label: const Text('Deactivate Customer',
          style: TextStyle(
              color: ErpColors.errorRed, fontWeight: FontWeight.w600)),
    );
  });

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Deactivate Customer',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will mark the customer as Inactive. '
                'You can reactivate them later by editing.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              Get.back();
              await c.deactivateCustomer();
            },
            child: const Text('Deactivate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}