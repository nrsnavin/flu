import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../dashboard/screens/dashboard_page.dart';
import '../services/nav_registry.dart';
import 'catalog_page.dart';
import 'global_search_sheet.dart';
import 'more_options.dart';
import 'operations_page.dart';

/// Adaptive app shell. Bottom nav on phones, persistent left rail on
/// tablets / large screens (≥ 800 px). The four primary destinations
/// are Home, Operations, Catalogue, More — a global search FAB sits
/// in the centre notch on phones and at the top of the rail on wide
/// screens.
///
/// Replaces the original 5-tab `Home` (Dashboard / Machines /
/// Production / Shift / More). The dropped tabs are reachable via
/// Operations and the search overlay, with one-tap return via
/// pinned modules persisted in `NavRegistry`.
class ErpShell extends StatefulWidget {
  const ErpShell({super.key});

  @override
  State<ErpShell> createState() => _ErpShellState();
}

class _ErpShellState extends State<ErpShell> {
  int _index = 0;
  final _pages = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    // Touch the registry once so it starts loading prefs.
    NavRegistry.instance;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  static const _tabs = [
    _Tab(icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded, label: 'Home'),
    _Tab(icon: Icons.factory_outlined,
        activeIcon: Icons.factory_rounded, label: 'Operations'),
    _Tab(icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded, label: 'Catalogue'),
    _Tab(icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded, label: 'More'),
  ];

  Widget _pageFor(int i) => _pages.putIfAbsent(i, () {
        switch (i) {
          case 0: return const DashboardPage();
          case 1: return const OperationsPage();
          case 2: return const CatalogPage();
          case 3: return const MoreOptionsPage();
          default: return const SizedBox.shrink();
        }
      });

  void _openSearch() => GlobalSearchSheet.show(context);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 800;
        return wide ? _buildWide(context) : _buildCompact(context);
      },
    );
  }

  // ── Compact (phones) ──────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: IndexedStack(
        index: _index,
        children: List.generate(_tabs.length, _pageFor),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ErpColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: _openSearch,
        child: const Icon(Icons.search_rounded, size: 26),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        tabs: _tabs,
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }

  // ── Wide (tablets / web) ──────────────────────────────────
  Widget _buildWide(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: Row(
        children: [
          _SideRail(
            tabs: _tabs,
            selectedIndex: _index,
            onTap: (i) => setState(() => _index = i),
            onSearch: _openSearch,
          ),
          VerticalDivider(width: 1, color: ErpColors.borderLight),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: List.generate(_tabs.length, _pageFor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({required this.icon, required this.activeIcon, required this.label});
}

// ══════════════════════════════════════════════════════════════
//  Bottom nav — notched for the centre FAB, lighter pill, flatter
//  shadow than the previous shell (per redesign brief).
// ══════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: ErpColors.navyDark,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              Expanded(child: _Item(tab: tabs[0], active: selectedIndex == 0, onTap: () => onTap(0))),
              Expanded(child: _Item(tab: tabs[1], active: selectedIndex == 1, onTap: () => onTap(1))),
              const SizedBox(width: 56), // notch space
              Expanded(child: _Item(tab: tabs[2], active: selectedIndex == 2, onTap: () => onTap(2))),
              Expanded(child: _Item(tab: tabs[3], active: selectedIndex == 3, onTap: () => onTap(3))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;
  const _Item({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        active ? ErpColors.accentBlue : ErpColors.textOnDarkSub;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? ErpColors.accentBlue.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(active ? tab.activeIcon : tab.icon,
                size: 22, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Side rail — wide layout
// ══════════════════════════════════════════════════════════════
class _SideRail extends StatelessWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onSearch;

  const _SideRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      color: ErpColors.navyDark,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Tooltip(
              message: 'Search',
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 24),
            for (int i = 0; i < tabs.length; i++)
              _RailItem(
                tab: tabs[i],
                active: selectedIndex == i,
                onTap: () => onTap(i),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;
  const _RailItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? ErpColors.accentBlue : ErpColors.textOnDarkSub;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? ErpColors.accentBlue.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(active ? tab.activeIcon : tab.icon,
                  color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
