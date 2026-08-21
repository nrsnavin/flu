import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/lock/app_lock_controller.dart';
import '../../../core/lock/app_lock_gate.dart';
import '../../../core/lock/app_lock_reminder.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';
import 'package:production/src/features/authentication/screens/home.dart';
import 'package:production/src/features/authentication/screens/welcome_screen.dart';

// Root routing widget.
// Shown while the app validates a stored JWT (isCheckingAuth == true),
// then hands off to Home or WelcomeScreen based on isLoggedIn.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LoginController>();

    // The lock needs to know whether there is a session to protect,
    // and this is the one place that knows. Wired here rather than
    // having the lock import LoginController, so neither depends on
    // the other.
    final lock = AppLockController.to;
    lock.isSignedIn = () => ctrl.isLoggedIn.value;

    return Obx(() {
      if (ctrl.isCheckingAuth.value) return const _SplashLoader();
      if (!ctrl.isLoggedIn.value) return const WelcomeScreen();

      // Arm on the first frame after the session is confirmed. Doing
      // it during build would set an observable mid-build, and doing
      // it before the check finishes would lock in front of a session
      // that turned out not to exist.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        lock.lockIfEnabledAtStart();

        // Offer the lock to somebody who just signed in and does not
        // have it on. Consumed here so it fires once per sign-in, not
        // on every rebuild of this Obx — an offer that reappears each
        // time the tree repaints is not an offer, it is a loop.
        if (ctrl.justSignedIn.value) {
          ctrl.justSignedIn.value = false;
          maybeOfferAppLock(context);
        }
      });

      return AppLockGate(
        onSignOut: ctrl.logout,
        child: Home(),
      );
    });
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.factory_rounded, size: 56, color: Color(0xFF3B82F6)),
            SizedBox(height: 20),
            Text(
              'ANU TAPES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Color(0xFF3B82F6), strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
