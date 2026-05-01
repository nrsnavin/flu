import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return Obx(() {
      if (ctrl.isCheckingAuth.value) return const _SplashLoader();
      if (ctrl.isLoggedIn.value)     return Home();
      return const WelcomeScreen();
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
