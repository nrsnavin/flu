import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/announcement_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ANNOUNCEMENT FORM PAGE — create + edit
// ══════════════════════════════════════════════════════════════
class AnnouncementFormPage extends StatelessWidget {
  final Map<String, dynamic>? existing;
  const AnnouncementFormPage({super.key, this.existing});

  static const _types     = ["info", "warning", "safety", "policy", "celebration"];
  static const _audiences = ["all", "department"];

  @override
  Widget build(BuildContext context) {
    final tag  = existing == null ? 'create' : 'edit-${existing!['_id']}';
    final ctrl = Get.put(
      AnnouncementFormController(
        existing: existing,
        onSuccess: () => Get.back(),
      ),
      tag: tag,
    );

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: ErpAppBar(
        title: ctrl.isEdit ? 'Edit Announcement' : 'New Announcement',
        subtitle: 'Posted to employee notice board',
      ),
      body: Form(
        key: ctrl.formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            ErpFormSection(
              title: 'Content',
              children: [
                TextFormField(
                  controller: ctrl.titleCtrl,
                  decoration: ErpDecorations.formInput('Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ctrl.bodyCtrl,
                  maxLines: 6,
                  decoration: ErpDecorations.formInput(
                    'Message',
                    hint: 'Write the announcement body',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Body required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ctrl.attachmentCtrl,
                  decoration: ErpDecorations.formInput(
                    'Attachment URL (optional)',
                    hint: 'https://...',
                  ),
                ),
              ],
            ),
            ErpFormSection(
              title: 'Type',
              children: [
                Obx(() => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _types.map((t) {
                        final selected = ctrl.type.value == t;
                        return ChoiceChip(
                          label: Text(_cap(t)),
                          selected: selected,
                          selectedColor:
                              ErpColors.accentBlue.withOpacity(0.15),
                          backgroundColor: ErpColors.bgMuted,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? ErpColors.accentBlue
                                : ErpColors.textSecondary,
                          ),
                          side: BorderSide(
                            color: selected
                                ? ErpColors.accentBlue
                                : ErpColors.borderLight,
                          ),
                          onSelected: (_) => ctrl.type.value = t,
                        );
                      }).toList(),
                    )),
              ],
            ),
            ErpFormSection(
              title: 'Audience',
              children: [
                Obx(() => Row(
                      children: _audiences.map((a) {
                        final selected = ctrl.audience.value == a;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => ctrl.audience.value = a,
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? ErpColors.accentBlue.withOpacity(0.10)
                                    : ErpColors.bgMuted,
                                border: Border.all(
                                  color: selected
                                      ? ErpColors.accentBlue
                                      : ErpColors.borderLight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                a == 'all' ? 'All employees' : 'A department',
                                style: TextStyle(
                                  color: selected
                                      ? ErpColors.accentBlue
                                      : ErpColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                const SizedBox(height: 12),
                Obx(() => Visibility(
                      visible: ctrl.audience.value == 'department',
                      child: TextFormField(
                        controller: ctrl.departmentCtrl,
                        decoration: ErpDecorations.formInput(
                          'Department',
                          hint: 'e.g. weaving',
                        ),
                      ),
                    )),
              ],
            ),
            ErpFormSection(
              title: 'Options',
              children: [
                Obx(() => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Pin to top',
                          style: ErpTextStyles.fieldValue),
                      subtitle: Text(
                        'Pinned items always show first on the worker portal',
                        style: TextStyle(
                            color: ErpColors.textMuted, fontSize: 11),
                      ),
                      value: ctrl.isPinned.value,
                      activeColor: ErpColors.accentBlue,
                      onChanged: (v) => ctrl.isPinned.value = v,
                    )),
                if (ctrl.isEdit)
                  Obx(() => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Active',
                            style: ErpTextStyles.fieldValue),
                        subtitle: Text(
                          'Disable to hide without deleting',
                          style: TextStyle(
                              color: ErpColors.textMuted, fontSize: 11),
                        ),
                        value: ctrl.isActive.value,
                        activeColor: ErpColors.accentBlue,
                        onChanged: (v) => ctrl.isActive.value = v,
                      )),
                Obx(() => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_outlined,
                          color: ErpColors.textSecondary),
                      title: Text(
                        ctrl.validUntil.value == null
                            ? 'Valid until (optional)'
                            : 'Valid until: ${DateFormat('dd MMM yyyy').format(ctrl.validUntil.value!)}',
                        style: ErpTextStyles.fieldValue,
                      ),
                      trailing: ctrl.validUntil.value == null
                          ? const Icon(Icons.calendar_today_outlined, size: 18)
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => ctrl.validUntil.value = null,
                            ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: ctrl.validUntil.value ??
                              now.add(const Duration(days: 7)),
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) ctrl.validUntil.value = picked;
                      },
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() => ErpPrimaryButton(
                  label: ctrl.isEdit ? 'Update Announcement' : 'Post Announcement',
                  icon: Icons.send_rounded,
                  isLoading: ctrl.loading.value,
                  onPressed: ctrl.submit,
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
