import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_side.dart';
import '../../../core/lock/app_lock_controller.dart';
import '../../../core/lock/app_lock_gate.dart';
import '../../../core/lock/app_lock_reminder.dart';
import '../../../core/shared_device.dart';
import '../../../employee/employee_area.dart';
import '../../../employee/features/auth/controllers/emp_session.dart';
import 'package:production/src/features/authentication/controllers/login_controller.dart';
import 'package:production/src/features/authentication/screens/home.dart';
import 'package:production/src/features/authentication/screens/welcome_screen.dart';
import 'worker_sign_in.dart';

// Root routing widget.
// Shown while the app validates a stored JWT (isCheckingAuth == true),
// then hands off by who is signed in:
//
//   nobody      → the welcome screen (office sign-in, or "Sign in as
//                 employee"); on a phone marked shared, the employee
//                 sign-in itself
//   a worker    → the employee screens (src/employee), the whole app
//   office      → Home
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

    // The shared-phone timer, wired the same way: it signs out whoever
    // is in — a worker through their session, which also forgets their
    // card; anyone else as the office screens' own sign-out does.
    final shared = SharedDevice.to;
    shared.isSignedIn = () => ctrl.isLoggedIn.value;
    shared.signOut = () async {
      if (AppSide.to.worker.value) {
        await EmpSession.find.logout();
      } else {
        await ctrl.logout();
        Get.until((route) => route.isFirst);
      }
    };

    return Obx(() {
      if (ctrl.isCheckingAuth.value) return const _SplashLoader();
      if (!ctrl.isLoggedIn.value) {
        return shared.on.value
            ? const WorkerSignInPage(kiosk: true)
            : const WelcomeScreen();
      }
      final worker = AppSide.to.worker.value;

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
          // Not on a shared phone: its own PIN would be everybody's.
          if (!shared.on.value) maybeOfferAppLock(context);
        }
      });

      return AppLockGate(
        // A worker's sign-out also forgets their card and closes the
        // pages open on top, as their own Sign out button does.
        onSignOut: worker ? EmpSession.find.logout : ctrl.logout,
        child: worker ? const EmployeeArea() : Home(),
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
