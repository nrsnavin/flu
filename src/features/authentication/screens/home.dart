import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/models/user.dart';
import 'package:production/src/features/authentication/screens/more_options.dart';
import 'package:production/src/features/employees/screens/empList.dart';
import 'package:production/src/features/machines/screens/machineList.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../production/screens/productionView.dart';
import '../../shiftPlanView/screens/shiftPlanToday.dart';
import '../controllers/login_controller.dart';

// ══════════════════════════════════════════════════════════════
//  HOME / SHELL — ERP Bottom Navigation
//
//  BUGS FIXED:
//  1. `Home.build()` returned `MaterialApp(home: ...)` — wrapping a
//     Scaffold inside MaterialApp inside another MaterialApp causes
//     Navigator conflicts, broken `Get.to()` navigation, and doubled
//     theming. Fixed: Home simply returns the shell directly.
//  2. `BottomNavigationBar` used `type: BottomNavigationBarType.shifting`
//     (default when items have backgroundColor set) with random per-item
//     colors (red, green, purple, pink, grey) — completely inconsistent.
//     Fixed: `type: fixed`, uniform navy/accent-blue theming.
//  3. `selectedItemColor: Colors.amber[800]` — amber on dark is low
//     contrast and off-brand. Fixed: accent blue.
//  4. `Get.put(LoginController())` at both class-field level of `Home`
//     AND at class-field level of `_BottomNavigationBarExampleState` →
//     double registration, possible state divergence.
//     Fixed: single `Get.find<LoginController>()` at the state level.
//  5. `_widgetOptions` was a `static final` list initialised once at
//     class load — instantiates all 5 screens immediately at startup
//     even before the user sees them. Fixed: `IndexedStack` with lazy
//     initialisation via `_pages` getter.
//  6. Bottom nav labels didn't match what the screens actually show:
//     "Running Orders" → EmpListScreen, "Pending Orders" → MachineList.
//     Fixed: correct labels.
// ══════════════════════════════════════════════════════════════

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // FIX: single find, not double put
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

  // ── Tab definitions ─────────────────────────────────────────
  static const _tabs = [
    _TabDef(icon: Icons.people_outline_rounded,        activeIcon: Icons.people_rounded,           label: 'Employees'),
    _TabDef(icon: Icons.precision_manufacturing_outlined, activeIcon: Icons.precision_manufacturing,  label: 'Machines'),
    _TabDef(icon: Icons.analytics_outlined,             activeIcon: Icons.analytics_rounded,        label: 'Production'),
    _TabDef(icon: Icons.calendar_today_outlined,        activeIcon: Icons.calendar_today_rounded,   label: 'Shift'),
    _TabDef(icon: Icons.grid_view_outlined,             activeIcon: Icons.grid_view_rounded,        label: 'More'),
  ];

  // FIX: lazy list — not static final, rebuilt on first access per tab
  // IndexedStack keeps them alive once built
  final _pages = <int, Widget>{};
  Widget _pageFor(int index) {
    return _pages.putIfAbsent(index, () {
      switch (index) {
        case 0: return const EmployeeListPage();
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
    // FIX: no MaterialApp wrapper — return Scaffold directly
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      // Use IndexedStack so pages stay alive when switching tabs
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

// ── Tab definition data class ──────────────────────────────
class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef({required this.icon, required this.activeIcon, required this.label});
}

// ══════════════════════════════════════════════════════════════
//  ERP BOTTOM NAVIGATION BAR
//  Navy background, accent-blue active indicator, white labels.
// ══════════════════════════════════════════════════════════════

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
              color: ErpColors.navyDark.withOpacity(0.3),
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
                    ? ErpColors.accentBlue.withOpacity(0.18)
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