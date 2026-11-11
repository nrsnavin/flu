import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';
import '../../auth/models/employee_user.dart';
import '../controllers/profile_controller.dart';

/// Edit-profile bottom sheet.
///
/// Optimistically swaps `EmpSession.user` on success and re-fetches
/// `/user/me` to reconcile with whatever the backend canonicalised
/// (e.g. lowercased email). Errors snackbar without committing.
Future<void> showEditProfileSheet(BuildContext context) async {
  final login = EmpSession.find;
  final u     = login.user.value;

  final nameCtrl  = TextEditingController(text: u.name);
  final emailCtrl = TextEditingController(text: u.email);
  final phoneCtrl = TextEditingController(text: u.phoneNumber ?? '');
  final formKey   = GlobalKey<FormState>();
  final saving    = false.obs;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ErpColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ErpColors.borderMid,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                const Icon(Icons.edit_outlined,
                    size: 18, color: ErpColors.accentBlue),
                const SizedBox(width: 8),
                Text('Edit Profile',
                    style: ErpTextStyles.cardTitle.copyWith(fontSize: 16)),
              ]),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                decoration: ErpDecorations.formInput('Name'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailCtrl,
                decoration: ErpDecorations.formInput('Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  // A login that signs in by phone has no email, and
                  // need not get one to change a name or a number.
                  if (s.isEmpty) return u.email.isEmpty ? null : 'Required';
                  final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!re.hasMatch(s)) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneCtrl,
                decoration: ErpDecorations.formInput('Phone number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              Obx(() => SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: saving.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              saving.value = true;
                              final newName  = nameCtrl.text.trim();
                              final newEmail = emailCtrl.text.trim();
                              final newPhone = phoneCtrl.text.trim();

                              // Optimistic swap so the UI feels instant.
                              final previous = login.user.value;
                              login.user.value = previous.copyWith(
                                name: newName,
                                email: newEmail,
                                phoneNumber: newPhone,
                              );

                              try {
                                await ApiClient.instance.dio.patch(
                                  '/user/me',
                                  data: {
                                    'name':        newName,
                                    // Left blank = left as it is.
                                    if (newEmail.isNotEmpty) 'email': newEmail,
                                    'phoneNumber': newPhone,
                                  },
                                );
                                // Reconcile with the server's canonical view.
                                final me = await ApiClient.instance.dio
                                    .get('/user/me');
                                login.user.value = EmployeeUser.fromMe(
                                    SafeJson.asMap(
                                        SafeJson.asMap(me.data)['user']));

                                if (Get.isRegistered<EmpProfileController>()) {
                                  Get.find<EmpProfileController>().refreshAll();
                                }

                                if (ctx.mounted) Navigator.of(ctx).pop();
                                Get.snackbar(
                                  'Profile updated',
                                  'Your changes were saved.',
                                  backgroundColor: ErpColors.successGreen,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              } on DioException catch (e) {
                                // Roll back the optimistic update.
                                login.user.value = previous;
                                final msg = SafeJson.apiErrorMessage(
                                        e.response?.data) ??
                                    'Could not save profile';
                                Get.snackbar(
                                  'Update failed',
                                  msg,
                                  backgroundColor: ErpColors.errorRed,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              } catch (e) {
                                login.user.value = previous;
                                Get.snackbar(
                                  'Update failed',
                                  e.toString(),
                                  backgroundColor: ErpColors.errorRed,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              } finally {
                                saving.value = false;
                              }
                            },
                      icon: saving.value
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(saving.value ? 'Saving…' : 'Save changes'),
                    ),
                  )),
            ],
          ),
        ),
      ),
    ),
  );
}
