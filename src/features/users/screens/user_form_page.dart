import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/users_controller.dart';

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
            TextFormField(
              controller: ctrl.deptCtrl,
              decoration: ErpDecorations.formInput('Department'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
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
}
