import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/users_controller.dart';
import 'user_form_page.dart';

// ══════════════════════════════════════════════════════════════
//  USERS LIST PAGE — admin user management.
// ══════════════════════════════════════════════════════════════
class UsersListPage extends StatelessWidget {
  const UsersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(UsersController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Users',
        subtitle: 'Manage app accounts',
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.users.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.users.isEmpty) {
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
        if (ctrl.users.isEmpty) {
          return Center(
            child: Text('No users',
                style: TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.fetch,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: ctrl.users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final u = ctrl.users[i];
              return _UserCard(
                data: u,
                onEdit: () => Get.to(() => UserFormPage(existing: u))
                    ?.then((_) => ctrl.fetch()),
                onDelete: () => _confirmDelete(ctrl, u),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('New User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Get.to(() => const UserFormPage())
            ?.then((_) => ctrl.fetch()),
      ),
    );
  }

  void _confirmDelete(UsersController ctrl, Map<String, dynamic> u) {
    Get.defaultDialog(
      title: 'Delete user?',
      titleStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: ErpColors.textPrimary),
      middleText: '${u['name']} will lose access to the app.',
      middleTextStyle:
          TextStyle(color: ErpColors.textSecondary, fontSize: 12),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: ErpColors.solidError, elevation: 0),
        onPressed: () {
          Get.back();
          ctrl.remove(u['_id'] as String);
        },
        child: const Text('Delete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      cancel: TextButton(onPressed: Get.back, child: const Text('Cancel')),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UserCard(
      {required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '—';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? '';
    final dept = data['department'] as String?;

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
            CircleAvatar(
              radius: 18,
              backgroundColor: ErpColors.statusOpenBg,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: ErpColors.statusOpenText,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: ErpColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(
                          color: ErpColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (role.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ErpColors.statusOpenBg,
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: ErpColors.statusOpenBorder),
                          ),
                          child: Text(role,
                              style: TextStyle(
                                  color: ErpColors.statusOpenText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      if (dept != null && dept.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(dept,
                            style: TextStyle(
                                color: ErpColors.textMuted, fontSize: 11)),
                      ],
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
          ],
        ),
      ),
    );
  }
}
