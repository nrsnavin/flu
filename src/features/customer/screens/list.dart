import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';
// import '../controllers/customerController.dart' hide CustomerListController;
import 'add_customer_page.dart';
import 'customer_detail_page.dart';
import '../controllers/customer_controller.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  late final CustomerListController _c;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // FIX: use Get.put with permanent=false, delete old instance first
    Get.delete<CustomerListController>(force: true);
    _c = Get.put(CustomerListController());
    // FIX: register scroll listener ONCE here, not in build()
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _c.fetchCustomers();
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
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ErpColors.accentBlue,
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
        onPressed: () async {
          final res = await Get.to(() => AddCustomerPage());
          if (res == true) _c.fetchCustomers(reset: true);
        },
      ),
      body: Column(
        children: [
          _SearchBar(c: _c),
          Expanded(child: _CustomerListBody(c: _c, scroll: _scroll)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: ErpColors.navyDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: const Text(
        "Customers",
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Obx(() => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "${_c.customers.length} records",
              style: const TextStyle(
                  color: ErpColors.textOnDarkSub, fontSize: 12),
            ),
          ),
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final CustomerListController c;
  const _SearchBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ErpColors.borderLight)),
      ),
      child: SizedBox(
        height: 40,
        child: TextField(
          onChanged: c.onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search by name, phone or GSTIN…",
            hintStyle: const TextStyle(
                color: ErpColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                size: 19, color: ErpColors.textMuted),
            filled: true,
            fillColor: ErpColors.bgMuted,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: ErpColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                  color: ErpColors.accentBlue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── List body ──────────────────────────────────────────────────
class _CustomerListBody extends StatelessWidget {
  final CustomerListController c;
  final ScrollController scroll;
  const _CustomerListBody({required this.c, required this.scroll});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value && c.customers.isEmpty) {
        return const Center(
          child:
          CircularProgressIndicator(color: ErpColors.accentBlue),
        );
      }

      if (c.customers.isEmpty) {
        return _EmptyState(onRefresh: () => c.fetchCustomers(reset: true));
      }

      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchCustomers(reset: true),
        child: ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: c.customers.length +
              (c.isMoreLoading.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == c.customers.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: ErpColors.accentBlue),
                ),
              );
            }
            return _CustomerCard(customer: c.customers[i]);
          },
        ),
      );
    });
  }
}

// ── Customer card ──────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final active = customer['status'] == "Active";
    final statusColor =
    active ? ErpColors.successGreen : ErpColors.errorRed;
    final statusBg =
    active ? ErpColors.statusCompletedBg : const Color(0xFFFEF2F2);
    final statusBorder = active
        ? ErpColors.statusCompletedBorder
        : const Color(0xFFFECACA);

    final payTerms = customer['paymentTerms'] ?? '—';
    final payLabel =
    payTerms == 'Advance' ? 'Advance' : '$payTerms Days';

    return GestureDetector(
      // FIX: removed errant `later:` label — navigation now actually fires
      onTap: () => Get.to(
              () => CustomerDetailPage(customerId: customer['_id'])),
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ErpColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: ErpColors.navyDark.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ErpColors.accentBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (customer['name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + contact
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name'] ?? '—',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((customer['contactName'] as String?)
                            ?.isNotEmpty ==
                            true)
                          Text(
                            customer['contactName'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: ErpColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      border: Border.all(color: statusBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      active ? "ACTIVE" : "INACTIVE",
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Meta row ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: ErpColors.borderLight)),
                color: ErpColors.bgMuted,
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  _MetaChip(
                    icon: Icons.phone_outlined,
                    label: customer['phoneNumber'] ?? '—',
                  ),
                  const SizedBox(width: 12),
                  _MetaChip(
                    icon: Icons.schedule_outlined,
                    label: payLabel,
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 16, color: ErpColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ErpColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ErpColors.bgMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: const Icon(Icons.people_outline,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Customers Found",
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: ErpColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap + to add your first customer",
            style: TextStyle(
                color: ErpColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ErpColors.borderMid),
            ),
            icon: const Icon(Icons.refresh,
                size: 16, color: ErpColors.textSecondary),
            label: const Text("Refresh",
                style:
                TextStyle(color: ErpColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}