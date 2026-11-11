import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:production/src/features/authentication/screens/login.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../floor/screens/floor_page.dart';
import 'worker_sign_in.dart';

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
                        color: ErpColors.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: ErpColors.accentBlue.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Icon(
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
                    Text(
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
                  const SizedBox(height: 12),
                  // ── The employee door ─────────────────────────
                  // One app for everyone: a worker signs in here with
                  // phone and PIN and lands on their own screens (the
                  // employee app that used to be separate).
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55), width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Get.to(() => const WorkerSignInPage()),
                      // Shrinks rather than overflowing on a narrow phone
                      // or with the phone's text size turned up.
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text('SIGN IN AS EMPLOYEE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Employees: your phone number and PIN',
                    style: TextStyle(color: ErpColors.textOnDarkSub, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  // ── The floor door ────────────────────────────
                  // Loom production entered by the shift supervisor,
                  // opened with the shift's PIN rather than a login.
                  TextButton.icon(
                    onPressed: () => Get.to(() => const FloorPage()),
                    icon: Icon(Icons.precision_manufacturing_outlined,
                        size: 16, color: ErpColors.accentLight),
                    label: Text('Floor entry with the shift PIN',
                        style: TextStyle(
                            color: ErpColors.accentLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: ErpColors.textOnDarkSub),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          color: ErpColors.textOnDarkSub, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}