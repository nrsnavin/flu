import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/lock/app_lock_setting.dart';
import '../../../../core/shared_device.dart';
import '../../../core/emp_settings_controller.dart';
import '../../../theme/erp_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = EmpSettingsController.find;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: Text('settings.title'.tr, style: ErpTextStyles.pageTitle),
      ),
      body: Obx(() {
        // A phone kept for everyone on the floor has no lock of its own
        // to offer: the phone's PIN would be everybody's, or nobody's. It
        // signs out by itself instead (set by the office, under My
        // account).
        final shared = SharedDevice.to.on.value;
        return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _SectionHeader('settings.language'.tr),
              _LangRadio(code: 'en', label: 'settings.language.en'.tr,
                  current: s.locale.value.languageCode,
                  onChanged: s.setLocale),
              _LangRadio(code: 'ta', label: 'settings.language.ta'.tr,
                  current: s.locale.value.languageCode,
                  onChanged: s.setLocale),
              _LangRadio(code: 'hi', label: 'settings.language.hi'.tr,
                  current: s.locale.value.languageCode,
                  onChanged: s.setLocale),
              const SizedBox(height: 16),
              if (shared)
                Container(
                  decoration: ErpDecorations.card,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'This is a shared phone: it signs you out by itself '
                    'after ${SharedDevice.to.idleMinutes.value} minutes '
                    'untouched. Sign out when you finish, too.',
                    style: const TextStyle(
                        color: ErpColors.textSecondary, fontSize: 12),
                  ),
                )
              else
                // The app's one lock — the same switch the office
                // screens show.
                const AppLockSetting(),
            ],
          );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(label.toUpperCase(), style: ErpTextStyles.sectionHeader),
      );
}

class _LangRadio extends StatelessWidget {
  final String code, label, current;
  final void Function(String) onChanged;
  const _LangRadio({
    required this.code,
    required this.label,
    required this.current,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        decoration: ErpDecorations.card,
        margin: const EdgeInsets.only(bottom: 6),
        child: RadioListTile<String>(
          value: code,
          groupValue: current,
          onChanged: (v) => v != null ? onChanged(v) : null,
          title: Text(label, style: ErpTextStyles.cardTitle),
        ),
      );
}
