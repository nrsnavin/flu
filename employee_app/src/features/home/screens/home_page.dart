import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/erp_theme.dart';
import '../../auth/controllers/login_controller.dart';
import '../../payroll/screens/payroll_page.dart';
import '../../shift_history/screens/shift_history_page.dart';
import '../../shift_production/screens/shift_production_page.dart';
import '../../wastage/screens/wastage_page.dart';

/// Dashboard shown after successful login.
///
/// Header: navy hero showing employee name + department + linked-id
/// banner if the User has no Employee link.
/// Body : 2x2 grid of feature cards for the four employee actions.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = LoginController.find;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: SafeArea(
        child: Obx(() {
          final u = c.user.value;
          return Column(children: [
            // ── Hero header ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
              decoration: const BoxDecoration(color: ErpColors.navyDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          ErpColors.accentBlue.withOpacity(0.22),
                      child: const Icon(Icons.person_outline,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name.isNotEmpty ? u.name : 'Welcome',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (u.department?.isNotEmpty ?? false) u.department!,
                              if (u.employeeRole?.isNotEmpty ?? false) u.employeeRole!,
                            ].join('  ·  '),
                            style: const TextStyle(
                              color: ErpColors.textOnDarkSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout_outlined,
                          color: Colors.white, size: 20),
                      onPressed: () async {
                        await c.logout();
                      },
                    ),
                  ]),
                  if (!u.hasEmployeeLink) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: ErpColors.warningAmber.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                ErpColors.warningAmber.withOpacity(0.45)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'No employee record linked to your login. Ask your supervisor to link your User to an Employee.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            // ── Feature grid ───────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    _FeatureCard(
                      title:    'Enter Shift\nProduction',
                      subtitle: 'Close an open shift',
                      icon:     Icons.precision_manufacturing_outlined,
                      color:    ErpColors.accentBlue,
                      enabled:  u.hasEmployeeLink,
                      onTap:    () => Get.to(() => const ShiftProductionPage()),
                    ),
                    _FeatureCard(
                      title:    'Shift\nHistory',
                      subtitle: 'Open & closed shifts',
                      icon:     Icons.calendar_view_day_outlined,
                      color:    const Color(0xFF0891B2),
                      enabled:  u.hasEmployeeLink,
                      onTap:    () => Get.to(() => const ShiftHistoryPage()),
                    ),
                    _FeatureCard(
                      title:    'Wastage\nReport',
                      subtitle: 'Last 50 records',
                      icon:     Icons.delete_sweep_outlined,
                      color:    ErpColors.errorRed,
                      enabled:  u.hasEmployeeLink,
                      onTap:    () => Get.to(() => const WastagePage()),
                    ),
                    _FeatureCard(
                      title:    'Payroll',
                      subtitle: 'Slip & advances',
                      icon:     Icons.receipt_long_outlined,
                      color:    ErpColors.successGreen,
                      enabled:  u.hasEmployeeLink,
                      onTap:    () => Get.to(() => const PayrollPage()),
                    ),
                  ],
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              border: Border.all(color: ErpColors.borderLight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ErpColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ErpColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
