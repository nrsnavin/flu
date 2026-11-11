import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/PurchaseOrder/services/theme.dart';
import 'lock/app_lock_controller.dart';

// ══════════════════════════════════════════════════════════════
//  A PHONE KEPT FOR EVERYONE ON THE FLOOR
//
//  The app stays signed in for months on purpose: on somebody's own
//  phone that is what makes it usable with gloves on. On a phone that
//  lives by the looms and is passed from hand to hand it is the
//  opposite of what anyone wants — the next person would be holding
//  the last one's payslip, leave and PIN-signed session.
//
//  So a phone can be marked shared (by the office, under My account;
//  a device setting, like the lock and the theme). A shared phone:
//
//    * opens on the employee sign-in — phone number and PIN — rather
//      than the office welcome screen;
//    * signs whoever is in out after a few untouched minutes, with a
//      thirty-second "still there?" first, so somebody reading a long
//      payslip is asked rather than thrown out;
//    * signs out at once when it is picked up after longer than that
//      in somebody's pocket (timers do not run in the background, so
//      the time away is checked on return).
//
//  "Untouched" is any touch on the screen or key press, caught at the
//  root — not per screen — so no screen can forget to report it.
// ══════════════════════════════════════════════════════════════

class SharedDevice extends GetxController with WidgetsBindingObserver {
  static const _kOn = 'device.shared';
  static const _kMinutes = 'device.sharedIdleMinutes';

  /// The idle limits offered, in minutes.
  static const choices = [3, 5, 10, 15];
  static const _warnFor = Duration(seconds: 30);

  static SharedDevice get to => Get.isRegistered<SharedDevice>()
      ? Get.find<SharedDevice>()
      : Get.put(SharedDevice(), permanent: true);

  /// Read the stored setting before the first frame, so a shared phone
  /// never flashes the office welcome screen first.
  static Future<SharedDevice> ensure() async {
    final c = to;
    await c._restore();
    return c;
  }

  final on = false.obs;
  final idleMinutes = 5.obs;

  /// Wired by AuthGate, as the lock is, so this file depends on neither
  /// sign-in nor the screens: whether anybody is signed in, and how to
  /// sign them out (which differs for a worker and an office login).
  bool Function() isSignedIn = () => false;
  Future<void> Function()? signOut;

  DateTime _lastTouch = DateTime.now();
  Timer? _timer;
  bool _warning = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _timer?.cancel();
    super.onClose();
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) touch();
  }

  bool _onKey(KeyEvent e) {
    touch();
    return false; // seen, not consumed
  }

  /// Somebody is using the phone.
  void touch() => _lastTouch = DateTime.now();

  /// When the phone was last touched, set by a test.
  @visibleForTesting
  void idleSince(DateTime at) => _lastTouch = at;

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      on.value = p.getBool(_kOn) ?? false;
      final m = p.getInt(_kMinutes) ?? 5;
      idleMinutes.value = choices.contains(m) ? m : 5;
    } catch (_) {
      // No preferences: an ordinary phone.
    }
    _schedule();
  }

  Future<void> setOn(bool value) async {
    on.value = value;
    touch();
    _schedule();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOn, value);
  }

  Future<void> setIdleMinutes(int minutes) async {
    if (!choices.contains(minutes)) return;
    idleMinutes.value = minutes;
    touch();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMinutes, minutes);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!on.value) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => check());
  }

  Duration get _limit => Duration(minutes: idleMinutes.value);

  /// Sign out, or ask first, if the phone has been left long enough.
  /// Runs every few seconds, and on return from the background.
  @visibleForTesting
  void check() {
    if (!on.value || !isSignedIn()) return;
    final idle = DateTime.now().difference(_lastTouch);
    if (idle >= _limit) {
      _expire();
    } else if (!_warning && idle >= _limit - _warnFor) {
      _warn();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> _expire() async {
    final out = signOut;
    if (out == null) return;
    _warning = false;
    touch(); // the next person starts with a fresh clock
    await out();
    Get.snackbar(
      'Signed out',
      'This shared phone signs out after ${idleMinutes.value} minutes untouched.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 5),
    );
  }

  void _warn() {
    _warning = true;
    Get.dialog<void>(
      const _StillThere(),
      barrierDismissible: true,
    ).whenComplete(() => _warning = false);
  }
}

/// "Still there?" with the seconds left. Any touch keeps the session —
/// the touch itself resets the clock — and closes this.
class _StillThere extends StatefulWidget {
  const _StillThere();

  @override
  State<_StillThere> createState() => _StillThereState();
}

class _StillThereState extends State<_StillThere> {
  int _left = SharedDevice._warnFor.inSeconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = (_left - 1).clamp(0, 999));
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Still there?'),
      content: Text(
        'This shared phone will sign you out in $_left seconds.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Get.back(),
          child: const Text('Stay signed in'),
        ),
      ],
    );
  }
}

/// The switch, for the device preferences on My account.
class SharedDeviceSetting extends StatelessWidget {
  const SharedDeviceSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final d = SharedDevice.to;
    return ErpSectionCard(
      title: 'SHARED PHONE',
      icon: Icons.groups_2_outlined,
      child: Obx(() {
        final shared = d.on.value;
        final lockOn = Get.isRegistered<AppLockController>() &&
            AppLockController.to.enabled.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: shared,
              onChanged: d.setOn,
              activeThumbColor: ErpColors.accentBlue,
              title: Text('This phone is shared on the floor',
                  style: TextStyle(fontSize: 13, color: ErpColors.textPrimary)),
              subtitle: Text(
                shared
                    ? 'Opens on the employee sign-in, and signs anyone out '
                        'after ${d.idleMinutes.value} minutes untouched.'
                    : 'For a phone kept by the looms for everyone. It then '
                        'opens on the employee sign-in and signs people out '
                        'by itself.',
                style: TextStyle(fontSize: 11, color: ErpColors.textSecondary),
              ),
            ),
            if (shared) ...[
              const SizedBox(height: 4),
              Text('Sign out after',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ErpColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final m in SharedDevice.choices)
                  ChoiceChip(
                    label: Text('$m min'),
                    selected: d.idleMinutes.value == m,
                    onSelected: (_) => d.setIdleMinutes(m),
                  ),
              ]),
              if (lockOn) ...[
                const SizedBox(height: 10),
                Text(
                  'The app lock is on, so everyone would need this phone’s '
                  'own PIN or fingerprint to open the app. On a shared phone, '
                  'turn the app lock off.',
                  style: TextStyle(fontSize: 11, color: ErpColors.warningAmber),
                ),
              ],
            ],
          ],
        );
      }),
    );
  }
}
