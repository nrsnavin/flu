import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_group_controller.dart';
import 'elastic_group_form_page.dart';

// ══════════════════════════════════════════════════════════════
//  ELASTIC GROUPS LIST PAGE — named elastic bundles.
// ══════════════════════════════════════════════════════════════
class ElasticGroupListPage extends StatelessWidget {
  const ElasticGroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ElasticGroupListController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Elastic Groups',
        subtitle: 'Reusable elastic bundles',
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.groups.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(ctrl.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                      label: 'Retry', icon: Icons.refresh, onPressed: ctrl.fetch),
                ],
              ),
            ),
          );
        }
        if (ctrl.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 48, color: ErpColors.textMuted),
                SizedBox(height: 10),
                Text('No elastic groups yet',
                    style: TextStyle(
                        color: ErpColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: ctrl.groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final g = ctrl.groups[i];
              return _GroupCard(
                data: g,
                onEdit: () => Get.to(() => ElasticGroupFormPage(existing: g))
                    ?.then((_) => ctrl.fetch()),
                onDelete: () => _confirmDelete(ctrl, g),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Group',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Get.to(() => const ElasticGroupFormPage())
            ?.then((_) => ctrl.fetch()),
      ),
    );
  }

  void _confirmDelete(
      ElasticGroupListController ctrl, Map<String, dynamic> g) {
    Get.defaultDialog(
      title: 'Delete group?',
      titleStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: ErpColors.textPrimary),
      middleText: 'Remove "${g['name']}"? Orders already created keep their lines.',
      middleTextStyle:
          TextStyle(color: ErpColors.textSecondary, fontSize: 12),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.errorRed, elevation: 0),
        onPressed: () {
          Get.back();
          ctrl.remove(g['_id'] as String);
        },
        child: const Text('Delete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      cancel: TextButton(onPressed: Get.back, child: const Text('Cancel')),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GroupCard(
      {required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '—';
    final cust = data['customer'];
    final custName = cust is Map ? cust['name'] as String? : null;
    final itemCount = (data['items'] as List?)?.length ?? 0;

    return InkWell(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: custName == null
                              ? ErpColors.statusPartialBg
                              : ErpColors.statusOpenBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(custName ?? 'Global',
                            style: TextStyle(
                                color: custName == null
                                    ? ErpColors.statusPartialText
                                    : ErpColors.statusOpenText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text('$itemCount elastic${itemCount == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: ErpColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: ErpColors.errorRed, size: 20),
              onPressed: onDelete,
            ),
            Icon(Icons.chevron_right, color: ErpColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
