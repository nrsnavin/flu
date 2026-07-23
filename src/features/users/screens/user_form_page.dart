import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../../core/features.dart';
import '../controllers/users_controller.dart';

const _departments = ['admin', 'preparatory', 'weaving', 'packing', 'finance'];

// ══════════════════════════════════════════════════════════════
//  USER FORM PAGE — create / edit an app user.
// ══════════════════════════════════════════════════════════════
class UserFormPage extends StatelessWidget {
  final Map<String, dynamic>? existing;
  const UserFormPage({super.key, this.existing});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(
      UserFormController(existing: existing, onSuccess: Get.back),
      tag: existing?['_id'] as String? ?? 'new-user',
    );

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: ctrl.isEdit ? 'Edit User' : 'New User',
        subtitle: ctrl.isEdit ? existing?['name'] as String? : 'Create an account',
      ),
      body: Form(
        key: ctrl.formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: ctrl.nameCtrl,
              decoration: ErpDecorations.formInput('Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: ctrl.emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: ErpDecorations.formInput('Email'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Required';
                if (!s.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: ctrl.passwordCtrl,
              obscureText: true,
              decoration: ErpDecorations.formInput(
                ctrl.isEdit ? 'New password (leave blank to keep)' : 'Password',
              ),
              validator: (v) {
                if (ctrl.isEdit) return null; // optional on edit
                final s = (v ?? '').trim();
                if (s.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Text('Preset (department)',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Obx(() {
              ctrl.features.length; // reactive dep — setDepartment mutates features
              final dept = ctrl.deptCtrl.text.isEmpty ? 'weaving' : ctrl.deptCtrl.text;
              return Container(
                decoration: BoxDecoration(
                  color: ErpColors.bgSurface,
                  border: Border.all(color: ErpColors.borderLight),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _departments.contains(dept) ? dept : 'weaving',
                    items: _departments
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d[0].toUpperCase() + d.substring(1),
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) ctrl.setDepartment(v);
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),
            const Text('Feature access',
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Text(
              'Pick exactly what this user can open. The preset just seeds the list.',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            ..._buildFeatureGroups(ctrl),
            const SizedBox(height: 22),
            Obx(() => ErpPrimaryButton(
                  label: ctrl.isEdit ? 'Save changes' : 'Create user',
                  icon: Icons.save_outlined,
                  isLoading: ctrl.loading.value,
                  onPressed: ctrl.submit,
                )),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatureGroups(UserFormController ctrl) {
    return featureSections().map((section) {
      final defs = kFeatures.where((f) => f.section == section).toList();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: ErpColors.bgSurface,
          border: Border.all(color: ErpColors.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(section.toUpperCase(),
                  style: const TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            ...defs.map((f) => Obx(() {
                  final on = f.always || ctrl.features.contains(f.key);
                  return InkWell(
                    onTap: f.always ? null : () => ctrl.toggleFeature(f.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            on ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 20,
                            color: f.always
                                ? ErpColors.textMuted
                                : (on ? ErpColors.accentBlue : ErpColors.textMuted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(f.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: f.always
                                        ? ErpColors.textMuted
                                        : ErpColors.textPrimary)),
                          ),
                          if (f.always)
                            const Text('always',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: ErpColors.textMuted,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                })),
          ],
        ),
      );
    }).toList();
  }
}
