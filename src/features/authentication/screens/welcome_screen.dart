import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/screens/login.dart';
import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  WELCOME / SPLASH SCREEN
//
//  BUGS FIXED:
//  1. `throw UnimplementedError()` was placed after the `return`
//     statement — unreachable dead code but confused static analysis.
//  2. Fixed-width button (250) broke on small screens.
//  3. No SystemUI overlay style → status bar clashed with navy bg.
// ══════════════════════════════════════════════════════════════

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: set status bar style to match dark header
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: ErpColors.navyDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top brand section ──────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo mark
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: ErpColors.accentBlue.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.factory_rounded,
                        size: 46,
                        color: ErpColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'ANU TAPES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Factory ERP System',
                      style: TextStyle(
                        color: ErpColors.textOnDarkSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Decorative divider
                    Container(
                      width: 48, height: 2,
                      decoration: BoxDecoration(
                        color: ErpColors.accentBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom action section ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 42),
              child: Column(
                children: [
                  // Module info pills
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _ModulePill(Icons.work_outline_rounded, 'Production'),
                      _ModulePill(Icons.layers_outlined, 'Warping'),
                      _ModulePill(Icons.inventory_2_outlined, 'Inventory'),
                      _ModulePill(Icons.people_outline_rounded, 'HR'),
                      _ModulePill(Icons.analytics_outlined, 'Analytics'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // FIX: full-width button, not fixed 250
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ErpColors.accentBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Get.to(() => const Login()),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text('LOGIN TO ERP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'v1.0  ·  Powered by Factory ERP',
                    style: TextStyle(
                        color: ErpColors.textOnDarkSub,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ModulePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: ErpColors.textOnDarkSub),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          color: ErpColors.textOnDarkSub, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}