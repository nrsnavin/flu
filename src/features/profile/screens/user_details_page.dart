import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';
import '../../../core/lock/app_lock_setting.dart';
import '../../../core/theme/theme_toggle.dart';
import '../../PurchaseOrder/services/theme.dart';
import '../../authentication/controllers/login_controller.dart';
import '../user_profile.dart';

// ══════════════════════════════════════════════════════════════
//  WHO YOU ARE SIGNED IN AS
//
//  One page for the questions a person asks about their own login,
//  which were previously spread across nowhere in particular:
//
//    * which account is this, and what can it reach
//    * am I linked to a workforce record, and which one
//    * the app lock
//    * signing out
//
//  ── Why the lock lives here now ────────────────────────────────
//  It was on the document-settings screen, which is about PDF
//  branding — it went there because that was the only settings page
//  in the app, not because it belonged. A lock on the session
//  belongs beside the session it locks.
//
//  ── Shown from cache first ─────────────────────────────────────
//  The name and role are already in SharedPreferences from login, so
//  the page draws immediately and fills in from the server behind
//  that. A profile that spins for two seconds on mill wifi before
//  showing a name the phone already knew is a page nobody opens
//  twice.
// ══════════════════════════════════════════════════════════════

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _dio = ApiClient.buildClient(baseUrl: ApiConfig.baseUrl);

  UserProfile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _seedFromCache();
    _load();
  }

  /// What the phone already knows, so the page is never blank.
  void _seedFromCache() {
    final u = Get.find<LoginController>().user.value;
    if (u == null) return;
    _profile = UserProfile(id: u.id, name: u.name, role: u.role);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get('/user/me');
      final body = res.data;
      if (body is! Map || body['user'] == null) {
        throw const FormatException('The server sent no user.');
      }
      if (!mounted) return;
      setState(() {
        _profile =
            UserProfile.fromJson(Map<String, dynamic>.from(body['user']));
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        // The cached seed stays on screen — a failed refresh must not
        // blank out a name the phone already had.
        _error = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString() ??
                'Could not refresh your details.'
            : 'Could not reach the server.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read your details.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ErpColors.bgSurface,
        title: Text('Sign out?',
            style: TextStyle(color: ErpColors.textPrimary)),
        content: Text(
          'You will need your email and password to sign back in.',
          style: TextStyle(color: ErpColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay signed in')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign out',
                style: TextStyle(color: ErpColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok == true) await Get.find<LoginController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: const ErpAppBar(title: 'My account', subtitle: 'Your login'),
      body: RefreshIndicator(
        color: ErpColors.accentBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (p != null) _Hero(profile: p),

            // A failed refresh is said out loud but does not replace
            // what is already on screen.
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.cloud_off_rounded,
                    size: 15, color: ErpColors.errorRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(
                          fontSize: 11, color: ErpColors.errorRed)),
                ),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ]),
            ],

            if (_loading && p == null) ...[
              const SizedBox(height: 40),
              Center(
                  child: CircularProgressIndicator(
                      color: ErpColors.accentBlue)),
            ],

            if (p != null) ...[
              const SizedBox(height: 14),
              _AccountCard(profile: p),

              if (p.employee != null) ...[
                const SizedBox(height: 10),
                _EmployeeCard(employee: p.employee!),
              ],

              const SizedBox(height: 10),
              _AccessCard(profile: p),
            ],

            // ── Device preferences ────────────────────────────
            const SizedBox(height: 10),
            const AppLockSetting(),
            const SizedBox(height: 10),
            const ThemeModePicker(),

            const SizedBox(height: 20),
            _SignOutButton(onTap: _confirmLogout),
          ],
        ),
      ),
    );
  }
}

// ── The card at the top ───────────────────────────────────────
class _Hero extends StatelessWidget {
  final UserProfile profile;
  const _Hero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final since = memberSinceLabel(profile.memberSince);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ErpColors.accentBlue.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: ErpColors.accentLight.withValues(alpha: 0.4)),
          ),
          child: Text(
            initialsFor(profile.name),
            style: TextStyle(
              color: ErpColors.accentLight,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name.isEmpty ? 'Signed in' : profile.name,
                style: TextStyle(
                  color: ErpColors.textOnDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (profile.email.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(profile.email,
                    style: TextStyle(
                        color: ErpColors.textOnDark.withValues(alpha: 0.7),
                        fontSize: 12)),
              ],
              if (since != null) ...[
                const SizedBox(height: 6),
                Text(since,
                    style: TextStyle(
                        color: ErpColors.textOnDark.withValues(alpha: 0.5),
                        fontSize: 11)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final UserProfile profile;
  const _AccountCard({required this.profile});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'ACCOUNT',
        icon: Icons.badge_outlined,
        child: Column(children: [
          _Row(label: 'Role', value: titleCase(profile.role)),
          _Row(label: 'Department', value: titleCase(profile.department)),
          _Row(label: 'Email', value: profile.email),
        ]),
      );
}

class _EmployeeCard extends StatelessWidget {
  final LinkedEmployee employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) => ErpSectionCard(
        title: 'WORKFORCE RECORD',
        icon: Icons.person_outline,
        child: Column(children: [
          _Row(label: 'Name', value: employee.name),
          _Row(label: 'Department', value: titleCase(employee.department)),
          _Row(label: 'Role', value: titleCase(employee.role)),
          _Row(label: 'Phone', value: employee.phoneNumber),
        ]),
      );
}

class _AccessCard extends StatelessWidget {
  final UserProfile profile;
  const _AccessCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ErpSectionCard(
      title: 'ACCESS',
      icon: Icons.key_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // An empty feature list means UNRESTRICTED, not "nothing".
        // Rendering it as an empty list would tell an admin they can
        // open no modules at all — see UserProfile.hasFeatureLimits.
        Text(
          profile.hasFeatureLimits
              ? 'This login can open ${profile.features.length} '
                  'module${profile.features.length == 1 ? '' : 's'}.'
              : 'This login is not restricted — every module is available.',
          style: TextStyle(fontSize: 12, color: ErpColors.textSecondary),
        ),
        if (profile.hasFeatureLimits) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in profile.features)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ErpColors.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    f.startsWith('/') ? f.substring(1) : f,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ErpColors.accentBlue),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Access is set by an admin on the web. Ask them if something '
          'you need is missing.',
          style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // A blank field is dropped rather than shown as a dash — a
    // profile full of em-dashes reads as a broken record.
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: ErpColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ErpColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: ErpColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ErpColors.errorRed.withValues(alpha: 0.35)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(Icons.logout_rounded,
                  color: ErpColors.errorRed, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Sign out',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ErpColors.errorRed)),
              ),
              Icon(Icons.chevron_right_rounded, color: ErpColors.errorRed),
            ]),
          ),
        ),
      );
}
