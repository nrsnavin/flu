import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/PurchaseOrder/services/theme.dart';
import 'app_lock_controller.dart';

// ══════════════════════════════════════════════════════════════
//  THE APP LOCK SWITCH
//
//  A device preference, like the theme picker it sits beside: it
//  saves the moment it is tapped rather than waiting for a Save
//  button that belongs to a different form.
//
//  ── Both directions ask ────────────────────────────────────────
//  Turning it ON proves the device can actually do it before
//  anybody relies on it — a switch that flips to "on" and then
//  cannot enforce anything is worse than no switch. Turning it OFF
//  asks too, so a found phone cannot have the lock removed as
//  easily as it was added.
//
//  ── Hidden where it cannot work ────────────────────────────────
//  A phone with no fingerprint, face or PIN enrolled gets an
//  explanation instead of a switch. Offering a control that is
//  guaranteed to fail is how people learn to distrust the settings
//  screen.
// ══════════════════════════════════════════════════════════════

class AppLockSetting extends StatefulWidget {
  const AppLockSetting({super.key});

  @override
  State<AppLockSetting> createState() => _AppLockSettingState();
}

class _AppLockSettingState extends State<AppLockSetting> {
  bool? _supported; // null while we ask
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppLockController.to.deviceCanLock().then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  Future<void> _toggle(bool want) async {
    setState(() => _busy = true);
    final lock = AppLockController.to;
    final ok = await lock.setEnabled(want);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      // Did not happen — say so, rather than leaving a switch that
      // sprang back with no explanation.
      final why = lock.lastError.value ?? 'Not confirmed.';
      Get.snackbar(
        want ? 'App lock not turned on' : 'App lock not turned off',
        why,
        backgroundColor: ErpColors.warningAmber,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(12),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppLockController.to;

    return ErpSectionCard(
      title: 'APP LOCK',
      icon: Icons.lock_outline_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_supported == false)
          Text(
            'This phone has no fingerprint, face or PIN set up, so the '
            'app lock cannot be used. Add a screen lock in the phone’s '
            'settings first.',
            style: TextStyle(fontSize: 12, color: ErpColors.textSecondary),
          )
        else
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: lock.enabled.value,
                onChanged:
                    (_supported == null || _busy) ? null : _toggle,
                activeThumbColor: ErpColors.accentBlue,
                title: Text('Require unlock to open the app',
                    style: TextStyle(
                        fontSize: 13, color: ErpColors.textPrimary)),
                subtitle: Text(
                  lock.enabled.value
                      ? 'Asks for your fingerprint, face or phone PIN '
                          'when the app opens, and after ${_graceLabel(lock.grace)} '
                          'away from it.'
                      : 'The app stays signed in for months, so anybody '
                          'holding this phone can open it. Turn this on '
                          'to put the phone’s own lock in front.',
                  style:
                      TextStyle(fontSize: 11, color: ErpColors.textSecondary),
                ),
              )),
        if (_busy) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
              minHeight: 2, color: ErpColors.accentBlue),
        ],
      ]),
    );
  }
}

String _graceLabel(Duration d) {
  if (d.inSeconds == 0) return 'any time';
  if (d.inSeconds < 60) return '${d.inSeconds} seconds';
  final m = d.inMinutes;
  return m == 1 ? 'a minute' : '$m minutes';
}
