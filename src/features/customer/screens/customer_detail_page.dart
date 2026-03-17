import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../PurchaseOrder/services/theme.dart';

import '../controllers/customer_controller.dart';
import 'edit_customer_page.dart';


class CustomerDetailPage extends StatelessWidget {
  final String customerId;
  const CustomerDetailPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    Get.delete<CustomerDetailController>(force: true);
    final c = Get.put(CustomerDetailController(customerId: customerId));
    return _CustomerDetailView(c: c);
  }
}

class _CustomerDetailView extends StatelessWidget {
  final CustomerDetailController c;
  const _CustomerDetailView({required this.c});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(context),
      body: Obx(() {
        if (c.loading.value) {
          return const Center(
            child: CircularProgressIndicator(color: ErpColors.accentBlue),
          );
        }
        final data = c.customerData;
        if (data.isEmpty) {
          return const Center(child: Text("Customer not found"));
        }
        return RefreshIndicator(
          color: ErpColors.accentBlue,
          onRefresh: c.fetchCustomer,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroCard(data: data),
                const SizedBox(height: 14),
                _InfoSection(
                  title: "PRIMARY CONTACT",
                  icon: Icons.person_outline,
                  rows: [
                    _InfoItem("Contact Name", data['contactName']),
                    _InfoItem("Phone",        data['phoneNumber']),
                    _InfoItem("Email",        data['email']),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoSection(
                  title: "COMMERCIAL",
                  icon: Icons.account_balance_outlined,
                  rows: [
                    _InfoItem("GSTIN",         data['gstin']),
                    // FIX: don't blindly append " Days" to "Advance"
                    _InfoItem("Payment Terms", _payLabel(data['paymentTerms'])),
                    _InfoItem("Status",        data['status']),
                  ],
                ),
                if (_hasContact(data['purchase'])) ...[
                  const SizedBox(height: 10),
                  _ContactSection(title: "PURCHASE", data: data['purchase']),
                ],
                if (_hasContact(data['accountant'])) ...[
                  const SizedBox(height: 10),
                  _ContactSection(title: "ACCOUNTS", data: data['accountant']),
                ],
                if (_hasContact(data['merchandiser'])) ...[
                  const SizedBox(height: 10),
                  _ContactSection(
                      title: "MERCHANDISER", data: data['merchandiser']),
                ],
                const SizedBox(height: 20),
                _DeactivateButton(c: c),
              ],
            ),
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
        onPressed: () => Get.back(),
      ),
      titleSpacing: 4,
      title: Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("Customer Details", style: ErpTextStyles.pageTitle,
                overflow: TextOverflow.ellipsis),
            Text("Customers  ›  Details",
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      actions: [
        // Edit button
        Obx(() {
          final data = c.customerData;
          if (data.isEmpty) return const SizedBox();
          return IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white, size: 20),
            tooltip: "Edit",
            onPressed: () async {
              // FIX: pass plain Map<String,dynamic> — not the RxMap
              final res = await Get.to(
                () => EditCustomerPage(
                    customer: Map<String, dynamic>.from(data)),
              );
              if (res == true) c.fetchCustomer();
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

  // FIX: render "Advance" correctly, not "Advance Days"
  String _payLabel(dynamic val) {
    if (val == null || val.toString().isEmpty) return '—';
    if (val == 'Advance') return 'Advance';
    return '${val} Days';
  }
}

// ── Hero card ──────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final active = data['status'] == "Active";
    final statusColor =
        active ? ErpColors.successGreen : ErpColors.errorRed;
    final statusBg =
        active ? ErpColors.statusCompletedBg : const Color(0xFFFEF2F2);
    final statusBorder = active
        ? ErpColors.statusCompletedBorder
        : const Color(0xFFFECACA);

    String? dateStr;
    try {
      if (data['createdAt'] != null) {
        final dt = DateTime.parse(data['createdAt'].toString());
        dateStr = DateFormat("dd MMM yyyy").format(dt);
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top navy band
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: const BoxDecoration(
              color: ErpColors.navyDark,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: ErpColors.accentBlue.withOpacity(0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (data['name'] as String? ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateStr != null)
                        Text(
                          "Added $dateStr",
                          style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 11),
                        ),
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    active ? "ACTIVE" : "INACTIVE",
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Quick info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _QuickInfo(
                    icon: Icons.phone_outlined,
                    value: data['phoneNumber'] ?? '—'),
                const SizedBox(width: 16),
                Expanded(
                  child: _QuickInfo(
                      icon: Icons.email_outlined,
                      value: data['email'] ?? '—',
                      overflow: true),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final text = Text(
      value,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ErpColors.textPrimary),
      overflow: overflow ? TextOverflow.ellipsis : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ErpColors.textMuted),
        const SizedBox(width: 6),
        overflow ? Expanded(child: text) : text,
      ],
    );
  }
}

// ── Info section card ──────────────────────────────────────────
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue,
                      borderRadius: BorderRadius.circular(2),
                    )),
                Icon(icon, size: 13, color: ErpColors.textSecondary),
                const SizedBox(width: 6),
                Text(title, style: ErpTextStyles.sectionHeader),
              ],
            ),
          ),
          // Rows
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: rows.map((r) => _buildRow(r)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              item.label,
              style: ErpTextStyles.fieldLabel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.value?.toString().isNotEmpty == true
                  ? item.value.toString()
                  : '—',
              style: ErpTextStyles.fieldValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final dynamic value;
  const _InfoItem(this.label, this.value);
}

// ── Contact section ────────────────────────────────────────────
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
        _InfoItem("Name",   m['name']),
        _InfoItem("Mobile", m['mobile']),
        _InfoItem("Email",  m['email']),
      ],
    );
  }
}

// ── Deactivate button ──────────────────────────────────────────
class _DeactivateButton extends StatelessWidget {
  final CustomerDetailController c;
  const _DeactivateButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = c.customerData['status'] == "Active";
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
        label: const Text(
          "Deactivate Customer",
          style: TextStyle(
              color: ErpColors.errorRed, fontWeight: FontWeight.w600),
        ),
      );
    });
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        title: const Text("Deactivate Customer",
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            "This will mark the customer as Inactive. You can reactivate them later by editing."),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel",
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
            child: const Text("Deactivate",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
