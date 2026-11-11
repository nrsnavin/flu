import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/safe_json.dart';
import '../../../theme/erp_theme.dart';
import '../../auth/controllers/emp_session.dart';
import '../../auth/models/employee_user.dart';
import '../controllers/profile_controller.dart';
import 'edit_profile_sheet.dart';

/// Rebuilt My Profile page.
///
/// Sections (top → bottom):
///   1. Hero header (avatar, name, dept·role, employee chip, verified badge)
///   2. Personal info card
///   3. Work stats KPI grid (2x2, parallel fetches, tolerates failure)
///   4. Quick actions row (edit, logout)
///   5. Recent activity timeline (last 5 shifts)
///   6. Account / app info footer
///
/// The page leans on `EmpSession.user` for identity (already in
/// memory) and `EmpProfileController` for the live stats / timeline.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the controller's default tag so the edit sheet can find it
    // via Get.find without coordinating a magic string.
    if (!Get.isRegistered<EmpProfileController>()) {
      Get.put(EmpProfileController(), permanent: false);
    }
    final c     = Get.find<EmpProfileController>();
    final login = EmpSession.find;

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        elevation: 0,
        title: const Text('My Profile', style: ErpTextStyles.pageTitle),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: c.refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: c.refreshAll,
        color: ErpColors.accentBlue,
        child: Obx(() {
          final u = login.user.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _HeroHeader(user: u),
              const SizedBox(height: 14),
              _PersonalInfoCard(user: u),
              const SizedBox(height: 14),
              _WorkStatsGrid(c: c),
              const SizedBox(height: 14),
              _QuickActions(onEdit: () => showEditProfileSheet(context)),
              const SizedBox(height: 14),
              _RecentActivity(c: c),
              const SizedBox(height: 18),
              const _FooterInfo(),
            ],
          );
        }),
      ),
    );
  }
}

// ══ Hero header ═════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final EmployeeUser user;
  const _HeroHeader({required this.user});

  String get _initials {
    // Build a list of non-empty word fragments so a trailing/leading
    // space or a name with only whitespace can't crash
    // `.characters.first` on an empty string.
    final parts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dept = user.department ?? '—';
    final role = (user.employeeRole?.isNotEmpty ?? false)
        ? user.employeeRole!
        : user.role;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ErpColors.navyDark, ErpColors.navyMid],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ErpColors.navyDark.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar tile — accent-blue background with the user's initials.
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: ErpColors.accentBlue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: ErpColors.accentBlue.withValues(alpha: 0.35),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          user.name.isEmpty ? '—' : user.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.hasEmployeeLink) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            size: 16, color: ErpColors.accentLight),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text('$dept  ·  $role',
                        style: const TextStyle(
                            color: ErpColors.textOnDarkSub, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (user.hasEmployeeLink) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined,
                      size: 12, color: ErpColors.textOnDarkSub),
                  const SizedBox(width: 6),
                  Text('ID  ${user.employeeId}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══ Personal info card ═════════════════════════════════════
class _PersonalInfoCard extends StatelessWidget {
  final EmployeeUser user;
  const _PersonalInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final rate = user.hourlyRate ?? 0;
    return ErpSectionCard(
      title: 'PERSONAL INFO',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _row(Icons.person, 'Name',  user.name.isEmpty ? '—' : user.name),
          _row(Icons.mail_outline, 'Email', user.email.isEmpty ? '—' : user.email),
          _row(Icons.phone_outlined, 'Phone',
              (user.phoneNumber == null || user.phoneNumber!.isEmpty)
                  ? '—' : user.phoneNumber!),
          _row(Icons.apartment_outlined, 'Department',
              user.department ?? '—'),
          if (rate > 0)
            _row(Icons.payments_outlined, 'Hourly rate',
                '₹${rate.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 14, color: ErpColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(
                    color: ErpColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: ErpColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ══ Work stats 2x2 grid ════════════════════════════════════
class _WorkStatsGrid extends StatelessWidget {
  final EmpProfileController c;
  const _WorkStatsGrid({required this.c});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'THIS MONTH',
      icon: Icons.insights_outlined,
      child: Obx(() {
        final tiles = <Widget>[
          _KpiTile(
            label: 'Attendance',
            value: c.attendancePct.value == null
                ? '—'
                : '${c.attendancePct.value!.toStringAsFixed(0)}%',
            icon: Icons.event_available_outlined,
            accent: ErpColors.successGreen,
            loading: c.isLoading.value,
          ),
          _KpiTile(
            label: 'Shifts logged',
            value: c.shiftsThisMonth.value?.toString() ?? '—',
            icon: Icons.access_time,
            accent: ErpColors.accentBlue,
            loading: c.isLoading.value,
          ),
          _KpiTile(
            label: 'Pending leaves',
            value: c.pendingLeaves.value?.toString() ?? '—',
            icon: Icons.beach_access_outlined,
            accent: ErpColors.warningAmber,
            loading: c.isLoading.value,
          ),
          _KpiTile(
            label: 'Bonus tier (YTD)',
            value: c.yearlyBonusTier.value ?? '—',
            icon: Icons.workspace_premium_outlined,
            accent: ErpColors.accentLight,
            loading: c.isLoading.value,
          ),
        ];
        return Column(children: [
          Row(children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 10),
            Expanded(child: tiles[1]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 10),
            Expanded(child: tiles[3]),
          ]),
        ]);
      }),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;
  final bool loading;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ErpColors.accentBlue),
                )
              : Text(value,
                  style: const TextStyle(
                      color: ErpColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

// ══ Quick actions ═══════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final VoidCallback onEdit;
  const _QuickActions({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // App-lock / PIN flow doesn't exist in this repo yet, so the
    // "Change PIN" action from the spec is intentionally omitted.
    return Row(children: [
      Expanded(
        child: _ActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit profile',
          color: ErpColors.accentBlue,
          onTap: onEdit,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionButton(
          icon: Icons.logout,
          label: 'Logout',
          color: ErpColors.errorRed,
          onTap: () async {
            final ok = await Get.dialog<bool>(
              AlertDialog(
                backgroundColor: ErpColors.bgSurface,
                title: const Text('Log out?'),
                content: const Text(
                    'You’ll need to sign in again to access your shifts.'),
                actions: [
                  TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancel')),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: ErpColors.errorRed),
                      onPressed: () => Get.back(result: true),
                      child: const Text('Log out')),
                ],
              ),
            );
            if (ok == true) {
              await EmpSession.find.logout();
            }
          },
        ),
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ErpColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: ErpColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══ Recent activity timeline ═════════════════════════════════
class _RecentActivity extends StatelessWidget {
  final EmpProfileController c;
  const _RecentActivity({required this.c});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'RECENT ACTIVITY',
      icon: Icons.history_outlined,
      child: Obx(() {
        if (c.isLoading.value) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ErpColors.accentBlue),
              ),
            ),
          );
        }
        if (c.recentShifts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('No recent shifts.',
                style: TextStyle(
                    color: ErpColors.textSecondary, fontSize: 12)),
          );
        }
        final dateFmt = DateFormat('dd MMM');
        final timeFmt = DateFormat('HH:mm');
        final items = c.recentShifts;
        return Column(
          children: List.generate(items.length, (i) {
            final s = items[i];
            final dt = SafeJson.asLocalDateTime(s['date']) ??
                SafeJson.asLocalDateTime(s['createdAt']);
            final when = dt == null ? '—' : dateFmt.format(dt);
            final time = dt == null ? '' : timeFmt.format(dt);
            final shiftLabel = SafeJson.asString(s['shift'], '—');
            final machine    = SafeJson.asString(s['machine'], '—');
            final isLast     = i == items.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline rail
                  SizedBox(
                    width: 22,
                    child: Column(children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: ErpColors.accentBlue,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: ErpColors.accentBlue
                                    .withValues(alpha: 0.3),
                                blurRadius: 4),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: ErpColors.borderLight,
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          top: 0, bottom: isLast ? 0 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(when,
                                style: const TextStyle(
                                    color: ErpColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ErpColors.statusOpenBg,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(shiftLabel.toUpperCase(),
                                  style: const TextStyle(
                                      color: ErpColors.statusOpenText,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (time.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(time,
                                  style: const TextStyle(
                                      color: ErpColors.textMuted,
                                      fontSize: 11)),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Text('Machine M-$machine',
                              style: const TextStyle(
                                  color: ErpColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      }),
    );
  }
}

// ══ Footer info ═════════════════════════════════════════════════
class _FooterInfo extends StatelessWidget {
  const _FooterInfo();

  @override
  Widget build(BuildContext context) {
    // TODO: wire package_info_plus if/when added to pubspec.
    const appVersion = 'v1.0.0';
    final host = ApiClient.instance.dio.options.baseUrl;
    return Center(
      child: Column(
        children: [
          Text(appVersion,
              style: const TextStyle(
                  color: ErpColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(host,
              style: const TextStyle(
                  color: ErpColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
