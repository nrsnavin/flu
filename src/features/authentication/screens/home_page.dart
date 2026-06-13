import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/nav_registry.dart';
import 'global_search_sheet.dart';
import 'operations_page.dart' show ModuleTile;

/// Lightweight landing page for the new shell. Renders a search
/// shortcut + pinned + recents + the full section grid so every
/// module is one tap (or one search keystroke) away.
///
/// Replaces the old `DashboardPage` which is not in this branch.
/// Kept intentionally simple — no KPI fetches, no controllers —
/// so it works regardless of which feature branches are merged.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
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
            Text('Home', style: ErpTextStyles.pageTitle),
            Text('Quick access',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () => GlobalSearchSheet.show(context),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFF1E3A5F)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Obx(() {
            final pinned = reg.pinned.toList();
            if (pinned.isEmpty) return _EmptyPinnedHint();
            return _Strip(title: 'PINNED', ids: pinned);
          }),
          const SizedBox(height: 16),
          Obx(() {
            final ids = reg.recents.toList();
            if (ids.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _Strip(title: 'RECENT', ids: ids),
            );
          }),
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8, top: 2),
            child: Text('JUMP TO', style: ErpTextStyles.sectionHeader),
          ),
          for (final s in NavRegistry.sectionsOrder)
            _SectionRow(title: s, modules: reg.modulesInSection(s)),
        ],
      ),
    );
  }
}

class _EmptyPinnedHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.push_pin_outlined,
              color: ErpColors.accentBlue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Long-press any module tile to pin it here for one-tap access.',
              style: TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  final String title;
  final List<String> ids;
  const _Strip({required this.title, required this.ids});

  @override
  Widget build(BuildContext context) {
    final reg = NavRegistry.instance;
    final modules = ids.map(reg.byId).whereType<NavModule>().toList();
    if (modules.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title, style: ErpTextStyles.sectionHeader),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: 92, child: ModuleTile(module: modules[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final List<NavModule> modules;
  const _SectionRow({required this.title, required this.modules});

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6, top: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: modules.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                width: 92, child: ModuleTile(module: modules[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
