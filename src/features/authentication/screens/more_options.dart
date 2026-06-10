import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:production/src/features/Covering/screens/covering_list.dart';
import 'package:production/src/features/Delivery%20Challan/screens/dc_list.dart';
import 'package:production/src/features/Job/screens/job_list_screen.dart';
import 'package:production/src/features/Orders/screens/add_order_page.dart';
import 'package:production/src/features/Orders/screens/order_list_page.dart';
import 'package:production/src/features/PurchaseOrder/screnns/po_list.dart';
import 'package:production/src/features/ShiftPlan/screens/shift_plan_create.dart';
import 'package:production/src/features/Warping/screens/warping_list.dart';
import 'package:production/src/features/addendence/screens/attendence.dart';
import 'package:production/src/features/announcement/screens/announcement_list.dart';
import 'package:production/src/features/authentication/screens/login.dart';
// import 'package:production/src/features/customer/screens/customerList.dart';
import 'package:production/src/features/customer/screens/list.dart';
import 'package:production/src/features/elastic/screens/elastic_list_page.dart';
import 'package:production/src/features/elastic/screens/stock_map_page.dart';
import 'package:production/src/features/employees/screens/empList.dart';
import 'package:production/src/features/feedback/screens/feedback_admin_list.dart';
import 'package:production/src/features/machine_issue/screens/machine_issue_admin_list.dart';
import 'package:production/src/features/materials/screens/stock_adjust.dart';
import 'package:production/src/features/packing/screens/AddPacking.dart';
import 'package:production/src/features/payroll/screens/payroll_page.dart';
import 'package:production/src/features/shift/screens/pending_verification_page.dart';
import 'package:production/src/features/supplier/screen/supplier_list_page.dart';
import 'package:production/src/features/wastage/screens/wastage_list.dart';
import '../../PurchaseOrder/controllers/add_po.dart';
import '../../PurchaseOrder/screnns/add_po.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../analytics/screens/production_analytics.dart';
import '../../materials/screens/material_list_screenn.dart';
import '../../packing/screens/PackingOverview.dart';
import '../../shift/screens/shift_list_page.dart';
// ══════════════════════════════════════════════════════════════
//  MORE OPTIONS PAGE  —  Full module launcher grid
// ══════════════════════════════════════════════════════════════

class MoreOptionsPage extends StatelessWidget {
  const MoreOptionsPage({super.key});

  static final _sections = <_Section>[
    _Section('PEOPLE', [
      _Tile(Icons.people_alt_rounded, 'Employees', _Nav.employees),
    ]),
    _Section('CUSTOMERS & ORDERS', [
      _Tile(Icons.people_alt_outlined, 'Customers', _Nav.customerList),
      _Tile(Icons.shopping_bag_outlined, 'Suppliers', _Nav.supplierList),
      _Tile(Icons.receipt_long_outlined, 'Orders', _Nav.orderList),
      _Tile(Icons.military_tech_outlined, 'Jobs', _Nav.jobList),
      _Tile(Icons.request_quote_outlined, 'Purchase Orders', _Nav.poList),
      _Tile(Icons.add_shopping_cart_rounded, 'Add PO', _Nav.addPO),
    ]),
    _Section('PRODUCTION', [
      _Tile(Icons.linear_scale_rounded, 'Elastics', _Nav.elasticList),
      _Tile(Icons.inventory_outlined, 'Elastic Stock', _Nav.elasticStock),
      _Tile(Icons.inventory_2_outlined, 'Raw Materials', _Nav.rawMaterials),
      _Tile(Icons.inventory_2_outlined, 'Stock Adjust', _Nav.stockAdjust),
      _Tile(Icons.layers_outlined, 'Warping', _Nav.warping),
      _Tile(Icons.auto_awesome_motion_outlined, 'Covering', _Nav.covering),
      _Tile(Icons.warning_amber_outlined, 'Wastage', _Nav.wastage),
    ]),
    _Section('PACKING & SHIPPING', [
      _Tile(Icons.inventory_outlined, 'Packing Overview', _Nav.packingOverview),
      _Tile(Icons.add_box_outlined, 'Add Packing', _Nav.addPacking),
      _Tile(Icons.local_shipping, 'Delivery Challan', _Nav.dc),
      _Tile(
        Icons.local_shipping_outlined,
        'Material Inward',
        _Nav.materialInward,
      ),
    ]),
    _Section('SHIFT MANAGEMENT', [
      _Tile(
        Icons.calendar_month_outlined,
        'Create Shift Plan',
        _Nav.createShiftPlan,
      ),
      _Tile(Icons.access_time_outlined, 'Shift Production', _Nav.shiftList),
      _Tile(Icons.hourglass_top_rounded,
          'Pending Verifications', _Nav.pendingVerification),
      _Tile(Icons.access_time_outlined, 'Attendence', _Nav.attendence),
      _Tile(Icons.access_time_outlined, 'Payroll', _Nav.payroll),
    ]),

    _Section('HR & COMMUNICATION', [
      _Tile(Icons.feedback_outlined, 'Employee Feedback', _Nav.feedback),
      _Tile(Icons.build_circle_outlined, 'Machine Issues', _Nav.machineIssues),
      _Tile(Icons.campaign_outlined, 'Notice Board', _Nav.noticeBoard),
    ]),

    _Section('ANALYTICS', [_Tile(Icons.dataset, 'ANALYTICS', _Nav.analytics)]),
    _Section('ACCOUNT', [
      _Tile(Icons.logout_rounded, 'Logout', _Nav.logout, isDanger: true),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modules', style: ErpTextStyles.pageTitle),
            Text(
              'All ERP features',
              style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 10),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        itemCount: _sections.length,
        itemBuilder: (_, sectionIdx) {
          final section = _sections[sectionIdx];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionIdx > 0) const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: section.tiles.length,
                itemBuilder: (_, tileIdx) {
                  final tile = section.tiles[tileIdx];
                  return _TileWidget(tile: tile);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Nav {
  static void employees() => Get.to(() => const EmployeeListPage());
  static void customerList() => Get.to(() => CustomerListPage());
  static void supplierList() => Get.to(() => SupplierListPage());
  static void orderList() => Get.to(() => OrderListPage());
  static void jobList() => Get.to(() => JobListPage());
  static void poList() => Get.to(() => POListPage());
  static void addPO() => Get.to(() => AddPOPage(mode: POFormMode.create));
  static void elasticList() => Get.to(() => ElasticListPage());
  static void elasticStock() => Get.to(() => const StockMapPage());
  static void rawMaterials() => Get.to(() => RawMaterialListPage());
  static void warping() => Get.to(() => WarpingListPage());
  static void covering() => Get.to(() => CoveringListPage());
  static void wastage() => Get.to(() => WastageListPage());
  static void packingOverview() => Get.to(() => PackingOverviewPage());
  static void addPacking() => Get.to(() => const AddPackingPage());

  static void payroll() => Get.to(() => const PayrollPage());

  static void stockAdjust() => Get.to(() => const StockAdjustPage());
  static void materialInward() =>
      Get.to(() => AddPOPage(mode: POFormMode.create));
  static void createShiftPlan() => Get.to(() => CreateShiftPlanPage());
  static void shiftList() => Get.to(() => ShiftListPage());
  static void pendingVerification() =>
      Get.to(() => const PendingVerificationPage());

  static void analytics() => Get.to(() => ProductionAnalyticsPage());

  static void dc() => Get.to(() => DCListPage());

  static void attendence() => Get.to(() => AttendancePage());

  static void feedback() => Get.to(() => const FeedbackAdminListPage());
  static void machineIssues() =>
      Get.to(() => const MachineIssueAdminListPage());
  static void noticeBoard() => Get.to(() => const AnnouncementListPage());

  static void logout() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: ErpColors.textPrimary,
      ),
      middleText: 'Are you sure you want to sign out?',
      middleTextStyle: const TextStyle(
        color: ErpColors.textSecondary,
        fontSize: 13,
      ),
      confirm: SizedBox(
        height: 38,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.errorRed,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: () {
            Get.offAll(() => const Login());
          },
          child: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      cancel: TextButton(
        onPressed: Get.back,
        child: const Text(
          'Cancel',
          style: TextStyle(
            color: ErpColors.accentBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final List<_Tile> tiles;
  const _Section(this.title, this.tiles);
}

class _Tile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;
  const _Tile(this.icon, this.label, this.onTap, {this.isDanger = false});
}

class _TileWidget extends StatelessWidget {
  final _Tile tile;
  const _TileWidget({required this.tile});

  @override
  Widget build(BuildContext context) {
    final color = tile.isDanger ? ErpColors.errorRed : ErpColors.accentBlue;

    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: tile.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tile.isDanger
                  ? ErpColors.errorRed.withOpacity(0.35)
                  : ErpColors.borderLight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(tile.icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                tile.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tile.isDanger
                      ? ErpColors.errorRed
                      : ErpColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
