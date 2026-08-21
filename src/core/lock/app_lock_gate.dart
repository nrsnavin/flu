import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/PurchaseOrder/services/theme.dart';
import 'app_lock_controller.dart';
import 'app_lock_policy.dart';

// ══════════════════════════════════════════════════════════════
//  THE LOCK SCREEN
//
//  Drawn OVER the app rather than pushed as a route, for one
//  reason: a route can be popped. A stack overlay cannot be
//  dismissed by the back button, a deep link, or a notification tap,
//  and it survives whatever navigation happened before the lock came
//  down — the person returns to the screen they left, once they are
//  through it.
//
//  ── The way out ────────────────────────────────────────────────
//  Sign out. A phone whose fingerprint was un-enrolled overnight
//  would otherwise be a phone nobody can open, and "reinstall the
//  app" is not an answer on a factory floor. Signing out clears the
//  session and returns to the login screen, which is always passable
//  with an email and a password.
// ══════════════════════════════════════════════════════════════

class AppLockGate extends StatelessWidget {
  final Widget child;

  /// What to do when somebody gives up and signs out.
  final Future<void> Function() onSignOut;

  const AppLockGate({
    super.key,
    required this.child,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final lock = AppLockController.to;
    return Stack(
      children: [
        child,
        Obx(() => lock.locked.value
            ? const Positioned.fill(child: _LockScreen())
            : const SizedBox.shrink()),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask straight away. Making somebody tap "Unlock" before the
    // prompt they were always going to get is a tap for nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLockController.to.unlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppLockController.to;

    // Opaque, and it must stay opaque: this covers whatever was on
    // screen when the app went away, which is the thing being hidden
    // from somebody who picked the phone up.
    return Material(
      color: ErpColors.navyDark,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 48, color: ErpColors.accentLight),
                const SizedBox(height: 20),
                Text(
                  'ANU TAPES',
                  style: TextStyle(
                    color: ErpColors.textOnDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => Text(
                      lockPrompt(lock.reason.value),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.textOnDark.withValues(alpha: 0.7),
                          fontSize: 13),
                    )),
                const SizedBox(height: 24),

                Obx(() {
                  final err = lock.lastError.value;
                  if (err == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      err,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ErpColors.errorRed, fontSize: 12),
                    ),
                  );
                }),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: lock.unlock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ErpColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // The way out of a lock that cannot be passed.
                TextButton(
                  onPressed: () async {
                    final gate = context
                        .findAncestorWidgetOfExactType<AppLockGate>();
                    lock.locked.value = false;
                    await gate?.onSignOut();
                  },
                  child: Text(
                    'Sign out instead',
                    style: TextStyle(
                        color: ErpColors.textOnDark.withValues(alpha: 0.7),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
