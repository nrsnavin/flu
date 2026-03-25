import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../PurchaseOrder/services/theme.dart';

import '../controller/supplier_list_controller.dart';
import 'add_supplier_page.dart';
import 'supplier_detail_page.dart';

// ══════════════════════════════════════════════════════════════
//  SUPPLIER LIST PAGE
// ══════════════════════════════════════════════════════════════
class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  late final SupplierListController _c;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Get.delete<SupplierListController>(force: true);
    _c = Get.put(SupplierListController());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _c.fetchSuppliers();
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
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final res = await Get.to(() => AddSupplierPage());
          if (res == true) _c.fetchSuppliers(reset: true);
        },
      ),
      body: Column(
        children: [
          _SearchBar(c: _c),
          Expanded(child: _ListBody(c: _c, scroll: _scroll)),
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
        'Suppliers',
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
              '${_c.suppliers.length} records',
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
  final SupplierListController c;
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
            hintText: 'Search by name or GSTIN…',
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
              borderSide:
              const BorderSide(color: ErpColors.accentBlue, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── List body ──────────────────────────────────────────────────
class _ListBody extends StatelessWidget {
  final SupplierListController c;
  final ScrollController scroll;
  const _ListBody({required this.c, required this.scroll});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value && c.suppliers.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(
                color: ErpColors.accentBlue));
      }
      if (c.suppliers.isEmpty) {
        return _EmptyState(
            onRefresh: () => c.fetchSuppliers(reset: true));
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: () => c.fetchSuppliers(reset: true),
        child: ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount:
          c.suppliers.length + (c.isMoreLoading.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == c.suppliers.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: ErpColors.accentBlue)),
              );
            }
            return _SupplierCard(
                supplier: c.suppliers[i], listController: c);
          },
        ),
      );
    });
  }
}

// ── Supplier card ──────────────────────────────────────────────
class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> supplier;
  final SupplierListController listController;
  const _SupplierCard(
      {required this.supplier, required this.listController});

  @override
  Widget build(BuildContext context) {
    final active = supplier['isActive'] != false;
    final statusColor =
    active ? ErpColors.successGreen : ErpColors.errorRed;
    final statusBg =
    active ? ErpColors.statusCompletedBg : const Color(0xFFFEF2F2);
    final statusBorder = active
        ? ErpColors.statusCompletedBorder
        : const Color(0xFFFECACA);

    return GestureDetector(
      onTap: () async {
        final res = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SupplierDetailPage(
                supplierId: supplier['_id'] ?? ''),
          ),
        );
        if (res == true) listController.fetchSuppliers(reset: true);
      },
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
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (supplier['name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF7C3AED),
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
                          supplier['name'] ?? '—',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ErpColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((supplier['contactPerson'] as String?)
                            ?.isNotEmpty ==
                            true)
                          Text(
                            supplier['contactPerson'],
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
                  // Active/Inactive badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      border: Border.all(color: statusBorder),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      active ? 'ACTIVE' : 'INACTIVE',
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
                border:
                Border(top: BorderSide(color: ErpColors.borderLight)),
                color: ErpColors.bgMuted,
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  if ((supplier['phoneNumber'] as String?)
                      ?.isNotEmpty ==
                      true)
                    _MetaChip(
                      icon: Icons.phone_outlined,
                      label: supplier['phoneNumber'],
                    ),
                  if ((supplier['gstin'] as String?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(width: 12),
                    _MetaChip(
                      icon: Icons.receipt_outlined,
                      label: supplier['gstin'],
                    ),
                  ],
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
        Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary, fontSize: 12)),
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
            child: const Icon(Icons.local_shipping_outlined,
                size: 32, color: ErpColors.textMuted),
          ),
          const SizedBox(height: 16),
          const Text('No Suppliers Found',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ErpColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Tap + to add your first supplier',
              style: TextStyle(
                  color: ErpColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.refresh,
                size: 16, color: ErpColors.textSecondary),
            label: const Text('Refresh',
                style: TextStyle(color: ErpColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}