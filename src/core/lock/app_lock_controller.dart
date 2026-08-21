import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_policy.dart';

// ══════════════════════════════════════════════════════════════
//  THE APP LOCK
//
//  Optional. Off until somebody turns it on. When on, the phone's
//  own fingerprint / face / PIN stands in front of the session.
//
//  It exists because the app now holds a ninety-day login so an
//  operator is not signing in every morning — which means a phone
//  left on a bench is a signed-in phone. This is what pays for that.
//
//  ── The decision is not made here ──────────────────────────────
//  Whether to lock lives in app_lock_policy.dart, free of Flutter
//  and covered by 45 checks on a bare VM. This file does the parts
//  that need a device: talking to the plugin, watching the lifecycle,
//  and remembering the setting.
//
//  ── Failing open, deliberately ─────────────────────────────────
//  Every path that cannot enforce the lock lets the person in and
//  turns the setting off, loudly. A phone whose fingerprint was
//  un-enrolled overnight must not become a phone that cannot open
//  the app at 6am — and the escape from a lock nobody can pass is
//  signing out, which the lock screen offers.
// ══════════════════════════════════════════════════════════════

class AppLockKeys {
  static const enabled = 'appLockEnabled';
  static const graceSeconds = 'appLockGraceSeconds';
}

class AppLockController extends GetxController with WidgetsBindingObserver {
  static AppLockController get to => Get.find<AppLockController>();

  static Future<AppLockController> ensure() async {
    if (Get.isRegistered<AppLockController>()) return Get.find();
    final c = Get.put(AppLockController(), permanent: true);
    await c._load();
    return c;
  }

  final _auth = LocalAuthentication();

  /// The setting.
  final enabled = false.obs;

  /// Whether the lock screen is up right now.
  final locked = false.obs;

  /// Why, so the screen can say.
  final reason = LockReason.coldStart.obs;

  /// The last failure, for the lock screen to show.
  final lastError = Rxn<String>();

  Duration _grace = kDefaultLockGrace;
  Duration get grace => _grace;

  DateTime? _leftAt;
  bool _authenticating = false;

  /// Depth of deliberate trips out of the app — the PDF viewer, the
  /// camera, the gallery. A counter rather than a flag because these
  /// nest: a QC photo opened from a screen that itself came from a
  /// document.
  int _excursions = 0;

  /// Whether anybody is signed in. Supplied by the caller rather than
  /// read from LoginController, so this file does not depend on auth
  /// and auth does not depend on it.
  bool Function() isSignedIn = () => false;

  AppLockState get _state => AppLockState(
        enabled: enabled.value,
        signedIn: isSignedIn(),
        onExcursion: _excursions > 0,
        authenticating: _authenticating,
        leftAt: _leftAt,
        grace: _grace,
      );

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(AppLockKeys.enabled) ?? false;
    final secs = prefs.getInt(AppLockKeys.graceSeconds);
    if (secs != null && secs >= 0) _grace = Duration(seconds: secs);
  }

  // ─────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Only `paused` and `hidden` mean gone. `inactive` fires for a
        // notification shade pull or an incoming call banner, and
        // treating those as departures locks the app while somebody is
        // holding it.
        _leftAt ??= DateTime.now();
        break;

      case AppLifecycleState.resumed:
        if (shouldLockOnResume(_state, DateTime.now())) {
          reason.value = LockReason.awayTooLong;
          locked.value = true;
        }
        _leftAt = null;
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Call around any flow that hands off to another app.
  ///
  /// Without it, opening a delivery challan in the OS PDF viewer and
  /// coming back two minutes later asks for a fingerprint — which
  /// trains people to switch the lock off, leaving them with less
  /// protection than a lenient lock would have given.
  Future<T> duringExcursion<T>(Future<T> Function() body) async {
    _excursions++;
    try {
      return await body();
    } finally {
      // Cleared on the way out, and the departure timestamp with it,
      // so a long trip does not lock the moment the NEXT one ends.
      _excursions = _excursions > 0 ? _excursions - 1 : 0;
      if (_excursions == 0) _leftAt = null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  LOCKING AND UNLOCKING
  // ─────────────────────────────────────────────────────────────

  /// Lock now, if the setting is on. Called at startup and after login.
  void lockIfEnabledAtStart() {
    if (shouldLockOnStart(_state)) {
      reason.value = LockReason.coldStart;
      locked.value = true;
    }
  }

  /// Ask the device. Returns true when it said yes.
  ///
  /// Never throws: the caller is a button on a lock screen with
  /// nowhere to catch, and an unhandled exception there is an app
  /// nobody can get into.
  Future<bool> _ask(String prompt) async {
    if (_authenticating) return false;
    _authenticating = true;
    lastError.value = null;
    try {
      return await _auth.authenticate(
        localizedReason: prompt,
        // Not biometricOnly: the phone's PIN is a legitimate answer,
        // and on a shared floor phone it is often the only one
        // enrolled. Refusing it would make the lock unusable on
        // exactly the devices that need it most.
        biometricOnly: false,
        // The prompt backgrounds the app on some Android builds; this
        // makes the plugin resume it rather than fail.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      final code = e.code.name;
      if (isUnenforceable(code)) {
        // The lock cannot work on this device. Turn it off and let
        // them in rather than leaving somebody outside their own app.
        await setEnabled(false, confirm: false);
        lastError.value = lockFailureMessage(code);
        locked.value = false;
        return false;
      }
      lastError.value = lockFailureMessage(code);
      return false;
    } catch (_) {
      lastError.value = 'Could not unlock.';
      return false;
    } finally {
      _authenticating = false;
      // The prompt's own backgrounding must not read as a departure.
      _leftAt = null;
    }
  }

  /// Try to clear the lock screen.
  Future<void> unlock() async {
    if (await _ask(lockPrompt(reason.value))) {
      locked.value = false;
      lastError.value = null;
    }
  }

  /// Turn the setting on or off.
  ///
  /// Both directions ask for identity when [confirm] is set: turning
  /// it ON proves the device can actually do it before somebody
  /// relies on it, and turning it OFF stops a found phone from having
  /// the lock removed as easily as it was added.
  ///
  /// Returns whether the setting ended up where it was asked to go.
  Future<bool> setEnabled(bool value, {bool confirm = true}) async {
    if (confirm) {
      reason.value = LockReason.confirmIdentity;
      final ok = await _ask(value
          ? 'Confirm to turn the app lock on'
          : 'Confirm to turn the app lock off');
      if (!ok) return false;
    }

    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppLockKeys.enabled, value);
    if (!value) locked.value = false;
    return true;
  }

  /// Change how long the app may be away before re-locking.
  Future<void> setGrace(Duration d) async {
    _grace = d.isNegative ? Duration.zero : d;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppLockKeys.graceSeconds, _grace.inSeconds);
  }

  /// Whether this device can do it at all, for the settings screen.
  ///
  /// False on a device with no biometrics AND no PIN — where offering
  /// the switch at all would be offering something that cannot work.
  Future<bool> deviceCanLock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }
}
