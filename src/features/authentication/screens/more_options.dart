import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:production/src/features/authentication/screens/login.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../services/nav_registry.dart';
import 'global_search_sheet.dart';
import 'operations_page.dart' show ModuleTile;

// ══════════════════════════════════════════════════════════════
//  MORE OPTIONS PAGE — module hub
//
//  - Search bar opens the global module search sheet.
//  - Pinned strip + Recent strip pull from NavRegistry.
//  - Module grid is split into collapsible sections matching the
//    NavRegistry catalogue, plus an Account section for Logout.
// ══════════════════════════════════════════════════════════════

class MoreOptionsPage extends StatefulWidget {
  const MoreOptionsPage({super.key});

  @override
  State<MoreOptionsPage> createState() => _MoreOptionsPageState();
}

class _MoreOptionsPageState extends State<MoreOptionsPage> {
  final _collapsed = <String, bool>{};

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
        title: Column(
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
          _SearchTrigger(onTap: () => GlobalSearchSheet.show(context)),
          const SizedBox(height: 16),
          Obx(() {
            final ids = reg.pinned.toList();
            if (ids.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _StripSection(title: 'PINNED', ids: ids),
            );
          }),
          Obx(() {
            final ids = reg.recents.toList();
            if (ids.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _StripSection(title: 'RECENT', ids: ids),
            );
          }),
          for (final section in NavRegistry.sectionsOrder)
            _CollapsibleSection(
              title: section,
              modules: reg.modulesInSection(section),
              collapsed: _collapsed[section] ?? false,
              onToggle: () => setState(
                () => _collapsed[section] = !(_collapsed[section] ?? false),
              ),
            ),
          const SizedBox(height: 16),
          _AccountSection(),
        ],
      ),
    );
  }
}

// ── Search trigger ────────────────────────────────────────────
class _SearchTrigger extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchTrigger({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  color: ErpColors.accentBlue, size: 20),
              SizedBox(width: 10),
              Text(
                'Search modules…',
                style: TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Horizontal strip (pinned / recents) ───────────────────────
class _StripSection extends StatelessWidget {
  final String title;
  final List<String> ids;
  const _StripSection({required this.title, required this.ids});

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
              width: 92,
              child: ModuleTile(module: modules[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Collapsible section ───────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final List<NavModule> modules;
  final bool collapsed;
  final VoidCallback onToggle;
  const _CollapsibleSection({
    required this.title,
    required this.modules,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(title, style: ErpTextStyles.sectionHeader),
                  const SizedBox(width: 6),
                  Text(
                    '(${modules.length})',
                    style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: ErpColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 4),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: modules.length,
              itemBuilder: (_, i) => ModuleTile(module: modules[i]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Account section (logout) ──────────────────────────────────
class _AccountSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8, top: 4),
          child: Text('ACCOUNT', style: ErpTextStyles.sectionHeader),
        ),
        Material(
          color: ErpColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _confirmLogout,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: ErpColors.errorRed.withOpacity(0.35)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: ErpColors.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: ErpColors.errorRed, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.errorRed,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: ErpColors.errorRed),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: ErpColors.textPrimary,
      ),
      middleText: 'Are you sure you want to sign out?',
      middleTextStyle: TextStyle(
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
          onPressed: () => Get.offAll(() => const Login()),
          child: const Text(
            'Logout',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      cancel: TextButton(
        onPressed: Get.back,
        child: Text(
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
