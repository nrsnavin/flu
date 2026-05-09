import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/erp_theme.dart';
import '../../home/screens/home_page.dart';
import '../controllers/login_controller.dart';
import 'login_page.dart';

/// Decides which top-level screen to show based on the current
/// [LoginController] state — the splash spinner during the
/// auto-login probe, the login screen if not authenticated, or
/// the home dashboard once a session is established.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final c = LoginController.find;
    return Obx(() {
      if (c.isCheckingAuth.value) {
        return const _SplashScreen();
      }
      return c.isLoggedIn.value ? const HomePage() : const LoginPage();
    });
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ErpColors.navyDark,
      body: Center(
        child: SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
            color: ErpColors.accentLight, strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
