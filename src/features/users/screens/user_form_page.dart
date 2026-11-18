import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../../../core/features.dart';
import '../controllers/users_controller.dart';
import 'package:production/src/core/nav.dart';

// ══════════════════════════════════════════════════════════════
//  USER FORM PAGE — create / edit an app user.
// ══════════════════════════════════════════════════════════════
class UserFormPage extends StatelessWidget {
  final Map<String, dynamic>? existing;
  const UserFormPage({super.key, this.existing});

  @override
  Widget build(BuildContext context) {
    // The Users list holds what the server says can be granted, and to
    // which departments; opened from anywhere else, this build's copy.
    final list = Get.isRegistered<UsersController>() ? Get.find<UsersController>() : null;
    final departments = (list == null || list.departments.isEmpty) ? kDepartments : list.departments.toList();
    final ctrl = Get.put(
      UserFormController(
        existing: existing,
        // closePage, not Get.back: the save has just shown "Saved", and
        // Get.back would close that notice and leave this form open.
        onSuccess: closePage,
        catalog: list?.catalog ?? kFeatures,
        departments: departments,
      ),
      tag: existing?['_id'] as String? ?? 'new-user',
    );

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: ctrl.isEdit ? 'Edit User' : 'New User',
        // Was `existing != null?['name'] as String?`, which Dart reads as
        // "if existing is not null, the LIST ['name'] cast to a String":
        // it threw on every edit, so no login could be opened here.
        subtitle: ctrl.isEdit ? (existing?['name'] as String? ?? '') : 'Create an account',
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
              decoration: ErpDecorations.formInput(
                ctrl.signsInByPhone ? 'Email (none — signs in by phone and PIN)' : 'Email',
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                // A worker's login has no email: it signs in by phone and
                // PIN, and must stay saveable without one.
                if (s.isEmpty) return ctrl.signsInByPhone ? null : 'Required';
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
                final s = (v ?? '').trim();
                if (ctrl.isEdit && s.isEmpty) return null; // blank keeps the old one
                // The server's rule (utils/passwordPolicy.js); it also
                // refuses the easy ones, in its own words.
                if (s.length < kMinPasswordLength) return 'At least $kMinPasswordLength characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Text('Preset (department)',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Obx(() {
              ctrl.features.length; // reactive dep — setDepartment mutates features
              final dept = ctrl.deptCtrl.text;
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
                    value: departments.contains(dept) ? dept : null,
                    items: departments
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
            Text('Feature access',
                style: TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text(
              'Pick what this user can open. The list is scoped to their role — '
              'only features that role can reach are shown.',
              style: TextStyle(color: ErpColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            // Rebuilds when the department (and thus the scoped feature set)
            // or any toggle changes — features is a reactive RxList.
            Obx(() {
              ctrl.features.length; // reactive dependency
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildFeatureGroups(ctrl),
              );
            }),
            const SizedBox(height: 22),
            Obx(() => ErpPrimaryButton(
                  label: ctrl.isEdit ? 'Save changes' : 'Create user',
                  icon: Icons.save_outlined,
                  isLoading: ctrl.loading.value,
                  onPressed: () => _save(context, ctrl),
                )),
          ],
        ),
      ),
    );
  }

  /// Saving a login that can open nothing but the always-on screens is
  /// allowed, but it is asked first, as on the web: the server enforces
  /// it silently and the person just meets "you don't have access".
  Future<void> _save(BuildContext context, UserFormController ctrl) async {
    if (ctrl.isEmployeeLogin || !ctrl.grantsNothing) return ctrl.submit();
    final name = ctrl.nameCtrl.text.trim();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save with no modules?'),
        content: Text(
          '${name.isEmpty ? 'This login' : name} will be able to open only the screens '
          'everyone has (dashboard, notices, feedback, claims, settings) — no module is ticked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save anyway')),
        ],
      ),
    );
    if (go == true) await ctrl.submit();
  }

  List<Widget> _buildFeatureGroups(UserFormController ctrl) {
    // Scope selection to what this department/role can actually reach, so a
    // feature the backend role gate would block can never be granted.
    final allowed = ctrl.scope.toSet();
    final widgets = <Widget>[];
    for (final section in featureSections(ctrl.catalog)) {
      final defs = ctrl.catalog
          .where((f) => f.section == section && (f.always || allowed.contains(f.key)))
          .toList();
      if (defs.isEmpty) continue;
      widgets.add(Container(
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
                  style: TextStyle(
                      color: ErpColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            ...defs.map((f) {
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
                        Text('always',
                            style: TextStyle(
                                fontSize: 9,
                                color: ErpColors.textMuted,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ));
    }
    return widgets;
  }
}
