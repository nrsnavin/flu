import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:production/src/features/Covering/screens/covering_list.dart';
import 'package:production/src/features/Delivery%20Challan/screens/dc_list.dart';
import 'package:production/src/features/Job/screens/job_list_screen.dart';
import 'package:production/src/features/Orders/screens/add_order_page.dart';
import 'package:production/src/features/Orders/screens/order_list_page.dart';
import 'package:production/src/features/PurchaseOrder/controllers/add_po.dart';
import 'package:production/src/features/PurchaseOrder/screnns/add_po.dart';
import 'package:production/src/features/PurchaseOrder/screnns/po_list.dart';
import 'package:production/src/features/PurchaseOrder/screnns/po_aging_page.dart';
import 'package:production/src/features/PurchaseOrder/screnns/low_stock_draft_page.dart';
import 'package:production/src/features/ShiftPlan/screens/shift_plan_create.dart';
import 'package:production/src/features/Warping/screens/warping_list.dart';
import 'package:production/src/features/addendence/screens/attendence.dart';
import 'package:production/src/features/analytics/screens/production_analytics.dart';
import 'package:production/src/features/reports/screens/production_report_screen.dart';
import 'package:production/src/features/reports/screens/dispatch_report_screen.dart';
import 'package:production/src/features/announcement/screens/announcement_list.dart';
import 'package:production/src/features/customer/screens/list.dart';
import 'package:production/src/features/elastic/screens/elastic_list_page.dart';
import 'package:production/src/features/elastic/screens/stock_map_page.dart';
import 'package:production/src/features/employees/screens/empList.dart';
import 'package:production/src/features/feedback/screens/feedback_admin_list.dart';
import 'package:production/src/features/machine_issue/screens/machine_issue_admin_list.dart';
import 'package:production/src/features/ai_advisor/screens/advisor_settings_page.dart';
import 'package:production/src/features/notification_settings/screens/notification_settings_page.dart';
import 'package:production/src/features/data_io/screens/data_import_page.dart';
import 'package:production/src/features/machines/screens/machineList.dart';
import 'package:production/src/features/machines/screens/maintenance_due_page.dart';
import 'package:production/src/features/materials/screens/material_list_screenn.dart';
import 'package:production/src/features/materials/screens/stock_adjust.dart';
import 'package:production/src/features/packing/screens/AddPacking.dart';
import 'package:production/src/features/packing/screens/PackingOverview.dart';
import 'package:production/src/features/payroll/screens/payroll_page.dart';
import 'package:production/src/features/shift/screens/pending_verification_page.dart';
import 'package:production/src/features/shift/screens/shift_list_page.dart';
import 'package:production/src/features/supplier/screen/supplier_list_page.dart';
import 'package:production/src/features/wastage/screens/wastage_list.dart';

/// One module entry — id, display label, icon, what to open, plus a
/// `section` for the grouped Modules page and a `keywords` list for
/// fuzzy search ("po" should find "Purchase Orders").
class NavModule {
  final String id;
  final String label;
  final IconData icon;
  final String section;
  final List<String> keywords;
  final VoidCallback open;

  const NavModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.section,
    required this.open,
    this.keywords = const [],
  });
}

/// Central registry replacing the loose `_Nav` static methods on
/// `more_options.dart`. Holds the catalogue, the user's pinned ids,
/// and a recents queue. All persistence over SharedPreferences so it
/// survives restarts.
///
/// Lifecycle: bound permanent in `main.dart` (or on first access)
/// via `Get.put(NavRegistry(), permanent: true)`. Reads `_load()`
/// asynchronously on construction.
class NavRegistry extends GetxController {
  static NavRegistry get instance =>
      Get.isRegistered<NavRegistry>()
          ? Get.find<NavRegistry>()
          : Get.put(NavRegistry(), permanent: true);

  static const _kPinned  = 'nav.pinned.v1';
  static const _kRecents = 'nav.recents.v1';
  static const _recentsCap = 8;

  final pinned  = <String>[].obs; // ordered, user-controlled
  final recents = <String>[].obs; // newest first, capped at _recentsCap

  late final List<NavModule> _modules;
  Map<String, NavModule> _byId = const {};

  List<NavModule> get all => _modules;
  NavModule? byId(String id) => _byId[id];

  /// Sections in the canonical display order used by the Modules page.
  static const sectionsOrder = <String>[
    'PEOPLE',
    'CUSTOMERS & ORDERS',
    'PRODUCTION',
    'PACKING & SHIPPING',
    'SHIFT MANAGEMENT',
    'HR & COMMUNICATION',
    'ANALYTICS',
  ];

  List<NavModule> modulesInSection(String section) =>
      _modules.where((m) => m.section == section).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    _modules = _buildCatalog();
    _byId = {for (final m in _modules) m.id: m};
    unawaited(_load());
  }

  // ── Persistence ────────────────────────────────────────────
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    pinned.assignAll(p.getStringList(_kPinned) ?? const []);
    recents.assignAll(p.getStringList(_kRecents) ?? const []);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kPinned,  pinned.toList());
    await p.setStringList(_kRecents, recents.toList());
  }

  // ── Record / pin API ──────────────────────────────────────
  /// Push `id` to the front of `recents` and persist. No-op for
  /// unknown ids so a typo doesn't poison the queue.
  void recordOpen(String id) {
    if (_byId[id] == null) return;
    recents
      ..remove(id)
      ..insert(0, id);
    if (recents.length > _recentsCap) {
      recents.removeRange(_recentsCap, recents.length);
    }
    unawaited(_save());
  }

  bool isPinned(String id) => pinned.contains(id);

  void togglePin(String id) {
    if (_byId[id] == null) return;
    if (pinned.contains(id)) {
      pinned.remove(id);
    } else {
      pinned.add(id);
    }
    unawaited(_save());
  }

  void reorderPinned(int oldIdx, int newIdx) {
    if (oldIdx < 0 || oldIdx >= pinned.length) return;
    final adjusted = newIdx > oldIdx ? newIdx - 1 : newIdx;
    final item = pinned.removeAt(oldIdx);
    pinned.insert(adjusted.clamp(0, pinned.length), item);
    unawaited(_save());
  }

  /// Convenience used by every nav surface — opens the module via
  /// `Get.to(...)` and records the tap. Keeps the call sites tiny.
  void open(String id) {
    final m = _byId[id];
    if (m == null) return;
    m.open();
    recordOpen(id);
  }

  /// Substring + keyword fuzzy match used by the global search sheet.
  /// Case-insensitive. Empty query returns `[]`.
  List<NavModule> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _modules.where((m) {
      if (m.label.toLowerCase().contains(q)) return true;
      for (final k in m.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  // ── Catalog — single source of truth ──────────────────────
  // Section names match the legacy MoreOptionsPage layout exactly so
  // existing muscle memory translates. Keywords add common aliases /
  // abbreviations.
  List<NavModule> _buildCatalog() => [
    // PEOPLE
    NavModule(
      id: 'employees', label: 'Employees',
      icon: Icons.people_alt_rounded, section: 'PEOPLE',
      keywords: const ['staff', 'workers', 'hr'],
      open: () => Get.to(() => const EmployeeListPage()),
    ),

    // CUSTOMERS & ORDERS
    NavModule(
      id: 'customers', label: 'Customers',
      icon: Icons.people_alt_outlined, section: 'CUSTOMERS & ORDERS',
      keywords: const ['clients', 'buyers'],
      open: () => Get.to(() => CustomerListPage()),
    ),
    NavModule(
      id: 'suppliers', label: 'Suppliers',
      icon: Icons.shopping_bag_outlined, section: 'CUSTOMERS & ORDERS',
      keywords: const ['vendors'],
      open: () => Get.to(() => SupplierListPage()),
    ),
    NavModule(
      id: 'orders', label: 'Orders',
      icon: Icons.receipt_long_outlined, section: 'CUSTOMERS & ORDERS',
      keywords: const ['sales orders'],
      open: () => Get.to(() => OrderListPage()),
    ),
    NavModule(
      id: 'jobs', label: 'Jobs',
      icon: Icons.military_tech_outlined, section: 'CUSTOMERS & ORDERS',
      keywords: const ['job orders', 'work orders'],
      open: () => Get.to(() => JobListPage()),
    ),
    NavModule(
      id: 'po_list', label: 'Purchase Orders',
      icon: Icons.request_quote_outlined, section: 'CUSTOMERS & ORDERS',
      keywords: const ['po', 'pos'],
      open: () => Get.to(() => POListPage()),
    ),
    NavModule(
      id: 'po_add', label: 'Add PO',
      icon: Icons.add_shopping_cart_rounded, section: 'CUSTOMERS & ORDERS',
      keywords: const ['new po', 'create po'],
      open: () => Get.to(() => AddPOPage(mode: POFormMode.create)),
    ),
    NavModule(
      id: 'po_aging', label: 'PO Aging',
      icon: Icons.hourglass_bottom_rounded, section: 'CUSTOMERS & ORDERS',
      keywords: const ['receipt aging', 'overdue po'],
      open: () => Get.to(() => const POAgingPage()),
    ),
    NavModule(
      id: 'low_stock_draft', label: 'Draft POs',
      icon: Icons.edit_note_rounded, section: 'CUSTOMERS & ORDERS',
      keywords: const ['low stock', 'auto po', 'reorder'],
      open: () => Get.to(() => const LowStockDraftPage()),
    ),
    NavModule(
      id: 'advisor_settings', label: 'Advisor preferences',
      icon: Icons.tune_rounded, section: 'CUSTOMERS & ORDERS',
      keywords: const ['advisor', 'ai', 'suggestions', 'preferences'],
      open: () => Get.to(() => const AdvisorSettingsPage()),
    ),
    NavModule(
      id: 'data_import', label: 'Import data',
      icon: Icons.upload_file_rounded, section: 'PRODUCTION',
      keywords: const ['excel', 'import', 'raw material', 'elastic', 'xlsx', 'bulk'],
      open: () => Get.to(() => const DataImportPage()),
    ),
    // PRODUCTION
    NavModule(
      id: 'elastics', label: 'Elastics',
      icon: Icons.linear_scale_rounded, section: 'PRODUCTION',
      keywords: const ['sku', 'catalog'],
      open: () => Get.to(() => ElasticListPage()),
    ),
    NavModule(
      id: 'elastic_stock', label: 'Elastic Stock',
      icon: Icons.inventory_outlined, section: 'PRODUCTION',
      keywords: const ['stock map', 'inventory'],
      open: () => Get.to(() => const StockMapPage()),
    ),
    NavModule(
      id: 'raw_materials', label: 'Raw Materials',
      icon: Icons.inventory_2_outlined, section: 'PRODUCTION',
      keywords: const ['yarn', 'materials'],
      open: () => Get.to(() => RawMaterialListPage()),
    ),
    NavModule(
      id: 'stock_adjust', label: 'Stock Adjust',
      icon: Icons.tune_rounded, section: 'PRODUCTION',
      keywords: const ['adjustment'],
      open: () => Get.to(() => const StockAdjustPage()),
    ),
    NavModule(
      id: 'warping', label: 'Warping',
      icon: Icons.layers_outlined, section: 'PRODUCTION',
      open: () => Get.to(() => WarpingListPage()),
    ),
    NavModule(
      id: 'covering', label: 'Covering',
      icon: Icons.auto_awesome_motion_outlined, section: 'PRODUCTION',
      open: () => Get.to(() => CoveringListPage()),
    ),
    NavModule(
      id: 'wastage', label: 'Wastage',
      icon: Icons.warning_amber_outlined, section: 'PRODUCTION',
      keywords: const ['waste', 'scrap'],
      open: () => Get.to(() => WastageListPage()),
    ),
    NavModule(
      id: 'machines', label: 'Machines',
      icon: Icons.precision_manufacturing_outlined, section: 'PRODUCTION',
      keywords: const ['equipment'],
      open: () => Get.to(() => const MachineListPage()),
    ),

    // PACKING & SHIPPING
    NavModule(
      id: 'packing_overview', label: 'Packing Overview',
      icon: Icons.inventory_outlined, section: 'PACKING & SHIPPING',
      open: () => Get.to(() => PackingOverviewPage()),
    ),
    NavModule(
      id: 'packing_add', label: 'Add Packing',
      icon: Icons.add_box_outlined, section: 'PACKING & SHIPPING',
      open: () => Get.to(() => const AddPackingPage()),
    ),
    NavModule(
      id: 'dc', label: 'Delivery Challan',
      icon: Icons.local_shipping, section: 'PACKING & SHIPPING',
      keywords: const ['dispatch', 'delivery'],
      open: () => Get.to(() => DCListPage()),
    ),
    NavModule(
      id: 'material_inward', label: 'Material Inward',
      icon: Icons.local_shipping_outlined, section: 'PACKING & SHIPPING',
      keywords: const ['receive', 'inward', 'goods receipt'],
      open: () => Get.to(() => AddPOPage(mode: POFormMode.create)),
    ),

    // SHIFT MANAGEMENT
    NavModule(
      id: 'shift_plan_create', label: 'Create Shift Plan',
      icon: Icons.calendar_month_outlined, section: 'SHIFT MANAGEMENT',
      keywords: const ['roster', 'planning'],
      open: () => Get.to(() => CreateShiftPlanPage()),
    ),
    NavModule(
      id: 'shift_list', label: 'Shift Production',
      icon: Icons.access_time_outlined, section: 'SHIFT MANAGEMENT',
      open: () => Get.to(() => ShiftListPage()),
    ),
    NavModule(
      id: 'pending_verification', label: 'Pending Verifications',
      icon: Icons.hourglass_top_rounded, section: 'SHIFT MANAGEMENT',
      keywords: const ['approve shifts', 'verify'],
      open: () => Get.to(() => const PendingVerificationPage()),
    ),
    NavModule(
      id: 'attendance', label: 'Attendance',
      icon: Icons.event_available_outlined, section: 'SHIFT MANAGEMENT',
      keywords: const ['attendence'],
      open: () => Get.to(() => AttendancePage()),
    ),
    NavModule(
      id: 'payroll', label: 'Payroll',
      icon: Icons.payments_outlined, section: 'SHIFT MANAGEMENT',
      keywords: const ['pay', 'salary', 'wages'],
      open: () => Get.to(() => const PayrollPage()),
    ),

    // HR & COMMUNICATION
    NavModule(
      id: 'feedback', label: 'Employee Feedback',
      icon: Icons.feedback_outlined, section: 'HR & COMMUNICATION',
      keywords: const ['complaints', 'suggestions'],
      open: () => Get.to(() => const FeedbackAdminListPage()),
    ),
    NavModule(
      id: 'machine_issues', label: 'Machine Issues',
      icon: Icons.build_circle_outlined, section: 'HR & COMMUNICATION',
      keywords: const ['breakdown', 'tickets'],
      open: () => Get.to(() => const MachineIssueAdminListPage()),
    ),
    NavModule(
      id: 'maintenance_due', label: 'Maintenance Due',
      icon: Icons.engineering_outlined, section: 'HR & COMMUNICATION',
      keywords: const ['service', 'preventive'],
      open: () => Get.to(() => const MaintenanceDuePage()),
    ),
    NavModule(
      id: 'notice_board', label: 'Notice Board',
      icon: Icons.campaign_outlined, section: 'HR & COMMUNICATION',
      keywords: const ['announcement'],
      open: () => Get.to(() => const AnnouncementListPage()),
    ),
    NavModule(
      id: 'whatsapp_notifications', label: 'WhatsApp Alerts',
      icon: Icons.notifications_active_outlined,
      section: 'HR & COMMUNICATION',
      keywords: const [
        'whatsapp', 'notifications', 'alerts', 'digest',
        'evening report', 'recipients',
      ],
      open: () => Get.to(() => const NotificationSettingsPage()),
    ),

    // ANALYTICS
    NavModule(
      id: 'analytics', label: 'Analytics',
      icon: Icons.insights_rounded, section: 'ANALYTICS',
      keywords: const ['kpis', 'production analytics'],
      open: () => Get.to(() => ProductionAnalyticsPage()),
    ),
    NavModule(
      id: 'reports_production', label: 'Production Report',
      icon: Icons.assessment_outlined, section: 'ANALYTICS',
      keywords: const ['report', 'production report', 'meters', 'summary'],
      open: () => Get.to(() => const ProductionReportScreen()),
    ),
    NavModule(
      id: 'reports_dispatch', label: 'Sales Report',
      icon: Icons.local_shipping_outlined, section: 'ANALYTICS',
      keywords: const ['report', 'dispatch', 'sales', 'delivery', 'revenue', 'value'],
      open: () => Get.to(() => const DispatchReportScreen()),
    ),
  ];
}
