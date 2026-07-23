import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/elastic_group_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ELASTIC GROUP FORM PAGE — create / edit a bundle.
// ══════════════════════════════════════════════════════════════
class ElasticGroupFormPage extends StatelessWidget {
  final Map<String, dynamic>? existing;
  const ElasticGroupFormPage({super.key, this.existing});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(
      ElasticGroupFormController(existing: existing, onSuccess: Get.back),
      tag: existing == null ? 'create' : 'edit-${existing!['_id']}',
    );

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: ctrl.isEdit ? 'Edit Group' : 'New Elastic Group',
        subtitle: ctrl.isEdit ? existing != null?['name'] as String? : 'Reusable bundle':"",
      ),
      body: Form(
        key: ctrl.formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: ctrl.nameCtrl,
              decoration: ErpDecorations.formInput('Group name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            const Text('Customer',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Obx(() {
              // DropdownButton asserts its value equals exactly one item —
              // fall back to Global if the group's customer isn't in the
              // loaded page.
              final ids = ctrl.customers.map((c) => c['_id'] as String?).toSet();
              final safeValue =
                  ids.contains(ctrl.customerId.value) ? ctrl.customerId.value : null;
              return Container(
                  decoration: BoxDecoration(
                    color: ErpColors.bgSurface,
                    border: Border.all(color: ErpColors.borderLight),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: safeValue,
                      hint: const Text('Global (all customers)',
                          style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Global (all customers)',
                              style: TextStyle(fontSize: 13)),
                        ),
                        ...ctrl.customers.map((c) => DropdownMenuItem<String?>(
                              value: c['_id'] as String?,
                              child: Text(c['name'] as String? ?? '—',
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (v) {
                        final c = ctrl.customers
                            .firstWhereOrNull((x) => x['_id'] == v);
                        ctrl.setCustomer(v, c?['name'] as String?);
                      },
                    ),
                  ),
                );
            }),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Elastics',
                    style: TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                TextButton.icon(
                  onPressed: () => _openElasticPicker(context, ctrl),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add elastic'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Obx(() {
              if (ctrl.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No elastics added yet',
                      style: TextStyle(
                          color: ErpColors.textMuted, fontSize: 12)),
                );
              }
              return Column(
                children: List.generate(ctrl.items.length, (i) {
                  final it = ctrl.items[i];
                  return Container(
                    key: ValueKey(it['elastic']),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: ErpColors.bgSurface,
                      border: Border.all(color: ErpColors.borderLight),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(it['name'] as String? ?? 'Elastic',
                              style: const TextStyle(
                                  color: ErpColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            initialValue:
                                (it['defaultQuantity'] ?? 0).toString(),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textAlign: TextAlign.right,
                            decoration:
                                ErpDecorations.formInput('Qty (m)'),
                            onChanged: (v) =>
                                ctrl.setQuantity(i, num.tryParse(v) ?? 0),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: ErpColors.textMuted),
                          onPressed: () => ctrl.removeItem(i),
                        ),
                      ],
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 20),
            Obx(() => ErpPrimaryButton(
                  label: ctrl.isEdit ? 'Save changes' : 'Create group',
                  icon: Icons.save_outlined,
                  isLoading: ctrl.loading.value,
                  onPressed: ctrl.submit,
                )),
          ],
        ),
      ),
    );
  }

  void _openElasticPicker(
      BuildContext context, ElasticGroupFormController ctrl) {
    ctrl.searchElastics('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ErpColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ErpColors.borderMid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: true,
                    decoration: ErpDecorations.formInput('Search elastic',
                        prefix: const Icon(Icons.search, size: 18)),
                    onChanged: ctrl.searchElastics,
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    if (ctrl.elasticSearching.value &&
                        ctrl.elasticResults.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (ctrl.elasticResults.isEmpty) {
                      return const Center(
                        child: Text('No elastics found',
                            style: TextStyle(
                                color: ErpColors.textMuted, fontSize: 12)),
                      );
                    }
                    return ListView.separated(
                      itemCount: ctrl.elasticResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = ctrl.elasticResults[i];
                        final already =
                            ctrl.items.any((it) => it['elastic'] == e['_id']);
                        return ListTile(
                          dense: true,
                          title: Text(e['name'] as String? ?? '—',
                              style: const TextStyle(fontSize: 13)),
                          trailing: already
                              ? const Icon(Icons.check,
                                  color: ErpColors.successGreen, size: 18)
                              : const Icon(Icons.add,
                                  color: ErpColors.accentBlue, size: 18),
                          onTap: already
                              ? null
                              : () {
                                  ctrl.addElastic(e);
                                  Get.back();
                                },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
