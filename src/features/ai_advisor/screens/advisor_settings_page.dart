import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../services/advisor_prefs_store.dart';

/// Lets the admin mute coarse advisor categories. Stays narrow on
/// purpose — fine-grained per-rule muting is a future iteration; for
/// v1 the four buckets cover every shipped rule and avoid 17 toggle
/// rows the user has to babysit.
class AdvisorSettingsPage extends StatelessWidget {
  const AdvisorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = AdvisorPrefsStore.instance;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Advisor preferences', style: ErpTextStyles.pageTitle),
            Text('Which signals to surface',
                style: TextStyle(
                    color: ErpColors.textOnDarkSub, fontSize: 10)),
          ],
        ),
      ),
      body: Obx(() {
        if (!prefs.loaded.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Disabled categories are hidden from the dashboard '
                "strip but stay visible in the diagnostics sheet so "
                "you can re-enable them.",
                style: TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: ErpColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ErpColors.borderLight),
              ),
              child: Column(
                children: [
                  for (final c in AdvisorCategory.values)
                    _CategoryTile(category: c, prefs: prefs),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final AdvisorCategory category;
  final AdvisorPrefsStore prefs;

  const _CategoryTile({required this.category, required this.prefs});

  IconData get _icon {
    switch (category) {
      case AdvisorCategory.inventory:  return Icons.inventory_2_outlined;
      case AdvisorCategory.people:     return Icons.groups_outlined;
      case AdvisorCategory.production: return Icons.factory_outlined;
      case AdvisorCategory.purchasing: return Icons.shopping_cart_outlined;
    }
  }

  String get _subtitle {
    switch (category) {
      case AdvisorCategory.inventory:
        return 'Low stock, projected stockout, reconcile drift';
      case AdvisorCategory.people:
        return 'Attendance, leave, pending shifts, payroll';
      case AdvisorCategory.production:
        return 'Jobs, machines, wastage, orders, anomalies';
      case AdvisorCategory.purchasing:
        return 'PO aging, supplier follow-ups';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = prefs.isEnabled(category);
      return InkWell(
        onTap: () => prefs.toggle(category, !enabled),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon,
                    color: ErpColors.accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ErpColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(_subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ErpColors.textSecondary,
                        )),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: (v) => prefs.toggle(category, v),
                activeColor: ErpColors.accentBlue,
              ),
            ],
          ),
        ),
      );
    });
  }
}
