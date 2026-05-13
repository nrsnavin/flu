import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/announcement_controller.dart';
import 'announcement_form.dart';

// ══════════════════════════════════════════════════════════════
//  ADMIN NOTICE BOARD PAGE
//  Lists all announcements; admin can post / edit / deactivate.
// ══════════════════════════════════════════════════════════════
class AnnouncementListPage extends StatelessWidget {
  const AnnouncementListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AnnouncementListController());

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(
        title: 'Notice Board',
        subtitle: 'Announcements for employees',
      ),
      body: Obx(() {
        if (ctrl.loading.value && ctrl.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMsg.value != null && ctrl.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: ErpColors.errorRed),
                  const SizedBox(height: 8),
                  Text(ctrl.errorMsg.value!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: ErpColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  ErpPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: ctrl.fetch,
                  ),
                ],
              ),
            ),
          );
        }
        if (ctrl.items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_outlined, size: 48, color: ErpColors.textMuted),
                SizedBox(height: 10),
                Text('No announcements yet',
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
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = ctrl.items[i];
              return _AnnouncementCard(
                data: a,
                onEdit: () => Get.to(() => AnnouncementFormPage(existing: a))
                    ?.then((_) => ctrl.fetch()),
                onDeactivate: () => _confirmDeactivate(ctrl, a),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ErpColors.accentBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Announcement',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Get.to(() => const AnnouncementFormPage())
            ?.then((_) => ctrl.fetch()),
      ),
    );
  }

  void _confirmDeactivate(
      AnnouncementListController ctrl, Map<String, dynamic> a) {
    Get.defaultDialog(
      title: 'Deactivate announcement?',
      titleStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: ErpColors.textPrimary,
      ),
      middleText:
          'Employees will no longer see "${a['title']}" on their notice board.',
      middleTextStyle:
          const TextStyle(color: ErpColors.textSecondary, fontSize: 12),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ErpColors.errorRed,
          elevation: 0,
        ),
        onPressed: () {
          Get.back();
          ctrl.deactivate(a['_id'] as String);
        },
        child: const Text('Deactivate',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      cancel: TextButton(onPressed: Get.back, child: const Text('Cancel')),
    );
  }
}

// ── Single announcement card ──────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  const _AnnouncementCard({
    required this.data,
    required this.onEdit,
    required this.onDeactivate,
  });

  static final _typeColors = <String, Color>{
    'info':        ErpColors.accentBlue,
    'warning':     ErpColors.warningAmber,
    'safety':      ErpColors.errorRed,
    'policy':      Color(0xFF7C3AED),
    'celebration': ErpColors.successGreen,
  };

  static final _typeIcons = <String, IconData>{
    'info':        Icons.info_outline,
    'warning':     Icons.warning_amber_outlined,
    'safety':      Icons.health_and_safety_outlined,
    'policy':      Icons.policy_outlined,
    'celebration': Icons.celebration_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final title    = data['title']    as String? ?? '';
    final body     = data['body']     as String? ?? '';
    final type     = data['type']     as String? ?? 'info';
    final audience = data['audience'] as String? ?? 'all';
    final dept     = data['department'] as String? ?? '';
    final pinned   = data['isPinned'] == true;
    final active   = data['isActive'] != false;
    final validUntil = data['validUntil'] as String?;
    final color    = _typeColors[type] ?? ErpColors.accentBlue;
    final icon     = _typeIcons[type] ?? Icons.info_outline;

    String validLabel = '';
    if (validUntil != null) {
      try {
        validLabel = 'Until ${DateFormat('dd MMM yyyy').format(DateTime.parse(validUntil).toLocal())}';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border.all(
          color: active ? ErpColors.borderLight : ErpColors.borderMid,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              border: Border(
                  bottom: BorderSide(color: color.withOpacity(0.18))),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ErpColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pinned)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.push_pin,
                        size: 14, color: ErpColors.accentBlue),
                  ),
                if (!active)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('INACTIVE',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ErpColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: audience == 'department'
                          ? Icons.groups_outlined
                          : Icons.public,
                      label: audience == 'department'
                          ? 'Dept: ${dept.isEmpty ? '—' : dept}'
                          : 'All employees',
                    ),
                    _MetaChip(icon: Icons.label_outline, label: type),
                    if (validLabel.isNotEmpty)
                      _MetaChip(
                          icon: Icons.schedule_outlined, label: validLabel),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: ErpColors.accentBlue),
                      label: const Text('Edit',
                          style: TextStyle(
                              color: ErpColors.accentBlue,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (active)
                      TextButton.icon(
                        onPressed: onDeactivate,
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: ErpColors.errorRed),
                        label: const Text('Deactivate',
                            style: TextStyle(
                                color: ErpColors.errorRed,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ErpColors.bgMuted,
        border: Border.all(color: ErpColors.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ErpColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: ErpColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
