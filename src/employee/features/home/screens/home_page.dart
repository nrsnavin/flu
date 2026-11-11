import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_side.dart';
import '../../../core/error_boundary.dart';
import '../../../theme/erp_theme.dart';
import '../../active_job/screens/active_job_page.dart';
import '../../attendance/screens/attendance_page.dart';
import '../../auth/controllers/emp_session.dart';
import '../../bonus/screens/bonus_page.dart';
import '../../covering/screens/covering_list.dart';
import '../../feedback/screens/feedback_page.dart';
import '../../leave/screens/leave_page.dart';
import '../../machine_issue/screens/machine_issue_page.dart';
import '../../notice_board/screens/notice_board_page.dart';
import '../../packing/screens/packing_jobs.dart';
import '../../payroll/screens/payroll_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../settings/screens/settings_page.dart';
import '../../shift_history/screens/shift_history_page.dart';
import '../../shift_production/screens/shift_production_page.dart';
import '../../warping/screens/warping_list.dart';
import '../../wastage/screens/wastage_jobs.dart';
import '../../wastage/screens/wastage_page.dart';

/// Dashboard shown after successful login.
///
/// Header: navy hero showing employee name + department + linked-id
/// banner if the User has no Employee link.
/// Body : dept-specific MY WORK strip + EVERYONE strip.
///
/// MY WORK tiles per department (work-related actions only):
///   weaving  → Enter Shift Production, Shift History, Machine Issue
///   warping  → Warping Jobs
///   covering → Covering Jobs (beam-entry enabled)
///   checking → Wastage Entry (jobs picker → entry form)
///   packing  → Packing Entry
///   other    → (no MY WORK strip)
///
/// EVERYONE tiles (HR / comms shared by all):
///   Attendance, Leave, Wastage Report (read-only), Payroll, Yearly
///   Bonus, Current Jobs, Notice Board, Feedback, My Profile.
///
/// The same page serves two people: a worker signed in with their own
/// login (the whole app is this page and what it opens), and an office
/// login linked to an employee record, opening "My work" from the
/// office screens ([staffView]) — they get a back arrow instead of
/// Settings and Sign out, which their office screens already have.
class HomePage extends StatelessWidget {
  final bool staffView;
  const HomePage({super.key, this.staffView = false});

  @override
  Widget build(BuildContext context) {
    final c = EmpSession.find;
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      body: SafeArea(
        child: Obx(() {
          final u = c.user.value;
          final dept = (u.department ?? '').toLowerCase().trim();
          return Column(children: [
            // ── Hero header ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
              decoration: const BoxDecoration(color: ErpColors.navyDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (staffView) ...[
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                        onPressed: () => Get.back(),
                      ),
                      const SizedBox(width: 2),
                    ],
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          ErpColors.accentBlue.withValues(alpha: 0.22),
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
                    if (!staffView) ...[
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white, size: 20),
                        onPressed: () =>
                            _open('Settings', const SettingsPage()),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout_outlined,
                            color: Colors.white, size: 20),
                        onPressed: () async {
                          await c.logout();
                        },
                      ),
                    ],
                  ]),
                  // Not while the first read is still on its way: an
                  // empty card is not "no employee linked".
                  if (c.loadError.value != null) ...[
                    const SizedBox(height: 12),
                    _LoadError(message: c.loadError.value!, onRetry: c.load),
                  ] else if (!u.hasEmployeeLink && !c.isLoading.value) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: ErpColors.warningAmber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                ErpColors.warningAmber.withValues(alpha: 0.45)),
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

            // ── Body: MY WORK (optional) + EVERYONE ──────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  ..._buildDepartmentSection(
                    dept: dept,
                    enabled: u.hasEmployeeLink,
                  ),
                  _SectionLabel('EVERYONE'),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _everyoneTiles(enabled: u.hasEmployeeLink),
                  ),
                ],
              ),
            ),
          ]);
        }),
      ),
    );
  }

  // ── EVERYONE tiles ──────────────────────────────────
  //
  // Enter Shift Production, Shift History and Machine Issue are no
  // longer here — they moved to MY WORK for weaving operators only.
  // The rest are HR / comms shared by every employee.
  List<Widget> _everyoneTiles({required bool enabled}) => [
        _FeatureCard(
          title:    'Attendance',
          subtitle: 'Monthly calendar',
          icon:     Icons.calendar_month_outlined,
          color:    const Color(0xFF7C3AED),
          enabled:  enabled,
          onTap: () =>
              _open('Attendance', const AttendancePage()),
        ),
        _FeatureCard(
          title:    'Leave',
          subtitle: 'Request & track',
          icon:     Icons.event_available_outlined,
          color:    const Color(0xFF0EA5E9),
          enabled:  enabled,
          onTap: () => _open('Leave', const LeavePage()),
        ),
        _FeatureCard(
          title:    'Wastage\nReport',
          subtitle: 'Last 50 records',
          icon:     Icons.delete_sweep_outlined,
          color:    ErpColors.errorRed,
          enabled:  enabled,
          onTap: () => _open('Wastage', const WastagePage()),
        ),
        _FeatureCard(
          title:    'Payroll',
          subtitle: 'Slip & advances',
          icon:     Icons.receipt_long_outlined,
          color:    ErpColors.successGreen,
          enabled:  enabled,
          onTap: () => _open('Payroll', const PayrollPage()),
        ),
        _FeatureCard(
          title:    'Yearly\nBonus',
          subtitle: 'View & download',
          icon:     Icons.workspace_premium_outlined,
          color:    ErpColors.warningAmber,
          enabled:  enabled,
          onTap: () =>
              _open('Yearly Bonus', const BonusPage()),
        ),
        _FeatureCard(
          title:    'Current\nJobs',
          subtitle: 'All active machines',
          icon:     Icons.assignment_turned_in_outlined,
          color:    const Color(0xFF14B8A6),
          enabled:  enabled,
          onTap: () =>
              _open('Current Jobs', const ActiveJobPage()),
        ),
        _FeatureCard(
          title:    'Notice\nBoard',
          subtitle: 'Announcements',
          icon:     Icons.campaign_outlined,
          color:    const Color(0xFF6366F1),
          enabled:  enabled,
          onTap: () =>
              _open('Notice Board', const NoticeBoardPage()),
        ),
        _FeatureCard(
          title:    'Feedback',
          subtitle: 'Complaints & ideas',
          icon:     Icons.forum_outlined,
          color:    const Color(0xFFDB2777),
          enabled:  enabled,
          onTap: () => _open('Feedback', const FeedbackPage()),
        ),
        _FeatureCard(
          title:    'My\nProfile',
          subtitle: 'Personal & shifts',
          icon:     Icons.person_outline,
          color:    const Color(0xFF475569),
          enabled:  enabled,
          onTap: () => _open('Profile', const ProfilePage()),
        ),
      ];

  // ── Dept-specific tiles ──────────────────────────────
  //
  // Returned as a flat list of children inserted above the EVERYONE
  // grid (label + grid + spacer). Returns an empty list for
  // departments that have no specialised flow yet (dyeing, blank)
  // so the UX matches the pre-feature behaviour.
  List<Widget> _buildDepartmentSection({
    required String dept,
    required bool enabled,
  }) {
    final tiles = _DepartmentTiles.forDept(dept, enabled, _open,
        officeWork: !AppSide.to.worker.value);
    if (tiles.isEmpty) return const [];
    return [
      _SectionLabel('MY WORK'),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: tiles,
      ),
      const SizedBox(height: 18),
    ];
  }

  /// Navigates to [page] wrapped in an ErrorBoundary so a crash on
  /// that screen falls back to a recovery card instead of taking
  /// the home dashboard down with it.
  void _open(String label, Widget page) {
    Get.to(() => ErrorBoundary(label: label, child: page));
  }
}

// ── Department tile factory ─────────────────────────────────────
//
// Resolves the worker's department to the tiles that should appear
// in the MY WORK strip. Centralised here so adding a new dept-
// specific module is a one-place change.
class _DepartmentTiles {
  _DepartmentTiles._();

  static List<Widget> forDept(
    String dept,
    bool enabled,
    void Function(String, Widget) open, {
    bool officeWork = true,
  }) {
    // Warping, covering, wastage and packing entries are the office's
    // modules on the server: a worker's own login (phone + PIN) is
    // refused every one of them, so it is not shown tiles that can only
    // fail. A supervisor's login opening "My work" still gets them.
    // Weaving's three are a worker's own — their shifts, their machine.
    if (!officeWork && dept != 'weaving') return const [];
    switch (dept) {
      // Weaving employees own the loom — they're the ones entering
      // production, reviewing their shift history, and reporting
      // machine issues. These tiles used to be in EVERYONE; moved
      // here so non-weaving operators don't see workflow that doesn't
      // apply to them.
      case 'weaving':
        return [
          _FeatureCard(
            title:    'Enter Shift\nProduction',
            subtitle: 'Close an open shift',
            icon:     Icons.precision_manufacturing_outlined,
            color:    ErpColors.accentBlue,
            enabled:  enabled,
            onTap: () => open('Shift Production',
                const ShiftProductionPage()),
          ),
          _FeatureCard(
            title:    'Shift\nHistory',
            subtitle: 'Open & closed shifts',
            icon:     Icons.calendar_view_day_outlined,
            color:    const Color(0xFF0891B2),
            enabled:  enabled,
            onTap: () => open('Shift History',
                const ShiftHistoryPage()),
          ),
          _FeatureCard(
            title:    'Machine\nIssues',
            subtitle: 'Report breakdown',
            icon:     Icons.build_circle_outlined,
            color:    const Color(0xFFEA580C),
            enabled:  enabled,
            onTap: () =>
                open('Machine Issues', const MachineIssuePage()),
          ),
        ];
      case 'warping':
        return [
          _FeatureCard(
            title:    'Warping\nJobs',
            subtitle: 'Plans & specs',
            icon:     Icons.linear_scale_rounded,
            color:    ErpColors.accentBlue,
            enabled:  enabled,
            onTap: () =>
                open('Warping Jobs', const WarpingListPage()),
          ),
        ];
      case 'covering':
        return [
          _FeatureCard(
            title:    'Covering\nJobs',
            subtitle: 'Record beam entries',
            icon:     Icons.layers_outlined,
            color:    ErpColors.successGreen,
            enabled:  enabled,
            onTap: () => open(
              'Covering Jobs',
              const CoveringListPage(canRecordBeamEntries: true),
            ),
          ),
        ];
      // The MY WORK tile for the checking dept is the entry flow —
      // operators land on the jobs picker so the very first tap is
      // "start a new wastage entry", matching the admin Add Wastage
      // flow. The read-only Wastage Report still lives under EVERYONE
      // (and has its own CTA back into this flow).
      case 'checking':
        return [
          _FeatureCard(
            title:    'Wastage\nEntry',
            subtitle: 'Record reject quantity',
            icon:     Icons.delete_sweep_outlined,
            color:    ErpColors.errorRed,
            enabled:  enabled,
            onTap: () =>
                open('Wastage Entry', const WastageJobsPage()),
          ),
        ];
      case 'packing':
        return [
          _FeatureCard(
            title:    'Packing\nEntry',
            subtitle: 'Record packed batches',
            icon:     Icons.inventory_2_outlined,
            color:    ErpColors.successGreen,
            enabled:  enabled,
            onTap: () =>
                open('Packing Entry', const PackingJobsPage()),
          ),
        ];
      default:
        return const [];
    }
  }
}

// ── Could not read who this is ───────────────────────────
class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ErpColors.errorRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ErpColors.errorRed.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

// ── Section label ────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2, left: 2),
        child: Text(label,
            style: const TextStyle(
                color: ErpColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
      );
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
                  color: color.withValues(alpha: 0.06),
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
                    color: color.withValues(alpha: 0.12),
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
