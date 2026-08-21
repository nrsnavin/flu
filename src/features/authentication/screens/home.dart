import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/models/user.dart';
import 'package:production/src/features/authentication/screens/more_options.dart';
import 'package:production/src/features/dashboard/screens/dashboard_page.dart';
import 'package:production/src/features/machines/screens/machineList.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../production/screens/productionView.dart';
import '../../shiftPlanView/screens/shiftPlanToday.dart';
import '../controllers/login_controller.dart';
import 'erp_shell.dart';

// Flip to `false` to fall back to the legacy 5-tab shell while the
// new adaptive shell rolls out.
const bool kUseNewShell = true;

// ══════════════════════════════════════════════════════════════
//  HOME / SHELL — entry point.
//  Defaults to `ErpShell` (adaptive bottom nav / side rail + global
//  search + NavRegistry-driven module catalogue). Set
//  `kUseNewShell = false` to fall back to the legacy 5-tab shell
//  (Dashboard / Machines / Production / Shift / More).
// ══════════════════════════════════════════════════════════════

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final LoginController _loginCtrl;
  late final User _user;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loginCtrl = Get.find<LoginController>();
    _user      = _loginCtrl.user.value;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  static const _tabs = [
    _TabDef(icon: Icons.dashboard_outlined,             activeIcon: Icons.dashboard_rounded,        label: 'Dashboard'),
    _TabDef(icon: Icons.precision_manufacturing_outlined, activeIcon: Icons.precision_manufacturing,  label: 'Machines'),
    _TabDef(icon: Icons.analytics_outlined,             activeIcon: Icons.analytics_rounded,        label: 'Production'),
    _TabDef(icon: Icons.calendar_today_outlined,        activeIcon: Icons.calendar_today_rounded,   label: 'Shift'),
    _TabDef(icon: Icons.grid_view_outlined,             activeIcon: Icons.grid_view_rounded,        label: 'More'),
  ];

  final _pages = <int, Widget>{};
  Widget _pageFor(int index) {
    return _pages.putIfAbsent(index, () {
      switch (index) {
        case 0: return const DashboardPage();
        case 1: return const MachineListPage();
        case 2: return const ProductionRangePage();
        case 3: return const TodayShiftPage();
        case 4: return const MoreOptionsPage();
        default: return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kUseNewShell) return const ErpShell();
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_tabs.length, _pageFor),
      ),
      bottomNavigationBar: _ErpBottomNav(
        tabs:          _tabs,
        selectedIndex: _selectedIndex,
        onTap:         (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef({required this.icon, required this.activeIcon, required this.label});
}

class _ErpBottomNav extends StatelessWidget {
  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _ErpBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        boxShadow: [
          BoxShadow(
              color: ErpColors.navyDark.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final active = selectedIndex == i;
              return _NavItem(
                tab: tabs[i], isActive: active, onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabDef tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? ErpColors.accentBlue.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                color: isActive ? ErpColors.accentBlue : ErpColors.textOnDarkSub,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isActive ? ErpColors.accentBlue : ErpColors.textOnDarkSub,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
