import 'package:flutter/material.dart';
import 'package:get/get.dart';


import '../../PurchaseOrder/services/theme.dart';
import '../controllers/employee_controller.dart';
import '../models/employee.dart';

import 'employeeDetail.dart';

import 'add_employee_page.dart';

// ══════════════════════════════════════════════════════════════
//  EMPLOYEE LIST PAGE
// ══════════════════════════════════════════════════════════════

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  late final EmployeeListController c;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // FIX: always delete stale instance before re-creating
    Get.delete<EmployeeListController>(force: true);
    c = Get.put(EmployeeListController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFab(),
      body: Column(children: [
        _SearchBar(ctrl: _searchCtrl, c: c),
        _DeptFilterRow(c: c),
        _SummaryStrip(c: c),
        Expanded(child: _EmployeeList(c: c)),
      ]),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
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
      title: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Employees', style: ErpTextStyles.pageTitle),
          Text(
            c.totalCount > 0
                ? '${c.totalCount} employees registered'
                : 'Employee Registry',
            style: const TextStyle(
                color: ErpColors.textOnDarkSub, fontSize: 10),
          ),
        ],
      )),
      actions: [
        Obx(() => IconButton(
          icon: c.isLoading.value
              ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 20),
          onPressed: c.isLoading.value ? null : c.fetchEmployees,
        )),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      heroTag: 'addEmployee',
      backgroundColor: ErpColors.accentBlue,
      elevation: 2,
      icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
      label: const Text('Add Employee',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      onPressed: () async {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const AddEmployeePage()),
        );
        if (result == true) c.fetchEmployees();
      },
    );
  }
}

// ── Search bar ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final EmployeeListController c;
  const _SearchBar({required this.ctrl, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: ctrl,
          onChanged: c.setSearch,
          style: ErpTextStyles.fieldValue,
          decoration: InputDecoration(
            filled: true,
            fillColor: ErpColors.bgMuted,
            hintText: 'Search by name or role…',
            hintStyle:
            const TextStyle(color: ErpColors.textMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded,
                color: ErpColors.textMuted, size: 17),
            suffixIcon: Obx(() => c.searchQuery.value.isNotEmpty
                ? GestureDetector(
              onTap: () {
                ctrl.clear();
                c.setSearch('');
              },
              child: const Icon(Icons.close_rounded,
                  size: 16, color: ErpColors.textMuted),
            )
                : const SizedBox.shrink()),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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

// ── Department filter row ────────────────────────────────────
class _DeptFilterRow extends StatelessWidget {
  final EmployeeListController c;
  const _DeptFilterRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ErpColors.bgSurface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Obx(() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EmployeeListController.kDepartments.map((dept) {
            final isActive = c.deptFilter.value == dept;
            final label = dept == 'all'
                ? 'All'
                : dept[0].toUpperCase() + dept.substring(1);
            return GestureDetector(
              onTap: () => c.setDeptFilter(dept),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? ErpColors.accentBlue.withOpacity(0.12)
                      : ErpColors.bgMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? ErpColors.accentBlue.withOpacity(0.5)
                        : ErpColors.borderLight,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? ErpColors.accentBlue
                        : ErpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isActive
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      )),
    );
  }
}

// ── Summary strip ────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final EmployeeListController c;
  const _SummaryStrip({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final counts = c.deptCounts;
      final weaving = counts['weaving'] ?? 0;
      final total   = c.totalCount;
      final shown   = c.filteredEmployees.length;

      return Container(
        color: ErpColors.bgSurface,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          _CountBadge(value: total,   label: 'Total',   color: ErpColors.textSecondary),
          const SizedBox(width: 8),
          _CountBadge(value: weaving, label: 'Weaving', color: ErpColors.accentBlue),
          const SizedBox(width: 8),
          _CountBadge(value: shown,   label: 'Shown',   color: ErpColors.successGreen),
        ]),
      );
    });
  }
}

class _CountBadge extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _CountBadge(
      {required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$value',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Employee list ────────────────────────────────────────────
class _EmployeeList extends StatelessWidget {
  final EmployeeListController c;
  const _EmployeeList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(
            child:
            CircularProgressIndicator(color: ErpColors.accentBlue));
      }
      if (c.errorMsg.value != null) {
        return _ErrorState(
            message: c.errorMsg.value!, onRetry: c.fetchEmployees);
      }
      if (c.filteredEmployees.isEmpty) {
        return _EmptyState(
          hasFilter: c.searchQuery.value.isNotEmpty ||
              c.deptFilter.value != 'all',
          onReset: () {
            c.setDeptFilter('all');
            c.setSearch('');
          },
        );
      }
      return RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: c.fetchEmployees,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
          itemCount: c.filteredEmployees.length,
          itemBuilder: (_, i) =>
              _EmployeeCard(employee: c.filteredEmployees[i]),
        ),
      );
    });
  }
}

// ── Employee card ────────────────────────────────────────────
class _EmployeeCard extends StatelessWidget {
  final EmployeeListItem employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final perfColor = employee.performance >= 80
        ? ErpColors.successGreen
        : employee.performance >= 60
        ? ErpColors.warningAmber
        : employee.performance > 0
        ? ErpColors.errorRed
        : ErpColors.textMuted;

    return GestureDetector(
      // FIX: was onDoubleTap → changed to onTap
      // FIX: arguments was List [id] → now String directly
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeDetailPage(employeeId: employee.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: ErpColors.accentBlue.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: ErpColors.accentBlue.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(employee.initial,
                    style: const TextStyle(
                        color: ErpColors.accentBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(employee.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: ErpColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (employee.performance > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: perfColor.withOpacity(0.12),
                            border:
                            Border.all(color: perfColor.withOpacity(0.35)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${employee.performance.toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: perfColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(employee.role,
                        style: const TextStyle(
                            color: ErpColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Chip(Icons.business_outlined,
                          employee.department[0].toUpperCase() +
                              employee.department.substring(1)),
                      if (employee.phoneNumber != null) ...[
                        const SizedBox(width: 8),
                        _Chip(Icons.phone_outlined, employee.phoneNumber!),
                      ],
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: ErpColors.textMuted, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: ErpColors.textMuted),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: ErpColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );
}

// ── Empty + Error states ─────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onReset;
  const _EmptyState({required this.hasFilter, required this.onReset});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            color: ErpColors.bgMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ErpColors.borderLight),
          ),
          child: const Icon(Icons.people_outline_rounded,
              size: 34, color: ErpColors.textMuted),
        ),
        const SizedBox(height: 14),
        Text(hasFilter ? 'No Matching Employees' : 'No Employees Yet',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: ErpColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          hasFilter
              ? 'Try adjusting your search or department filter'
              : 'Add your first employee using the button below',
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        if (hasFilter) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ErpColors.borderMid)),
            icon: const Icon(Icons.filter_alt_off_outlined,
                size: 15, color: ErpColors.textSecondary),
            label: const Text('Clear filters',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color: ErpColors.bgMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ErpColors.borderLight),
        ),
        child: const Icon(Icons.error_outline,
            size: 34, color: ErpColors.textMuted),
      ),
      const SizedBox(height: 14),
      const Text('Failed to load',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: ErpColors.textPrimary)),
      const SizedBox(height: 4),
      Text(message,
          style: const TextStyle(
              color: ErpColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.accentBlue, elevation: 0),
        icon:
        const Icon(Icons.refresh, size: 16, color: Colors.white),
        label: const Text('Retry',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}