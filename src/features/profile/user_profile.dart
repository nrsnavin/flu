// ══════════════════════════════════════════════════════════════
//  WHO IS SIGNED IN
//
//  The shape GET /user/me returns, and the small amount of thinking
//  the profile page does with it. Kept free of Flutter so the parts
//  that are easy to get subtly wrong — initials, an empty feature
//  list meaning the opposite of what it looks like — can be checked
//  on a bare Dart VM.
//
//  See user_profile_check.dart.
// ══════════════════════════════════════════════════════════════

/// The linked workforce record, when this login has one.
///
/// Office logins do not: an accounts clerk is a User with no
/// Employee behind them, and the page must not imply otherwise by
/// showing an empty staff card.
class LinkedEmployee {
  final String id;
  final String name;
  final String department;
  final String phoneNumber;
  final String role;

  const LinkedEmployee({
    this.id = '',
    this.name = '',
    this.department = '',
    this.phoneNumber = '',
    this.role = '',
  });

  static LinkedEmployee? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['_id'] ?? m['id'])?.toString() ?? '';
    if (id.isEmpty) return null;
    return LinkedEmployee(
      id: id,
      name: m['name']?.toString() ?? '',
      department: m['department']?.toString() ?? '',
      phoneNumber: m['phoneNumber']?.toString() ?? '',
      role: m['role']?.toString() ?? '',
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final DateTime? memberSince;
  final LinkedEmployee? employee;

  /// The modules this login may open, as nav paths.
  ///
  /// An EMPTY list does not mean "no access" — see [hasFeatureLimits].
  /// Getting that backwards on a profile page would tell an admin
  /// they can open nothing.
  final List<String> features;

  const UserProfile({
    this.id = '',
    this.name = '',
    this.email = '',
    this.role = '',
    this.department = '',
    this.memberSince,
    this.employee,
    this.features = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final created = j['createdAt']?.toString();
    return UserProfile(
      id: (j['id'] ?? j['_id'])?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      role: j['role']?.toString() ?? '',
      department: j['department']?.toString() ?? '',
      memberSince: (created == null || created.isEmpty)
          ? null
          : DateTime.tryParse(created),
      employee: LinkedEmployee.fromJson(j['employee']),
      features: (j['features'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  /// Whether this login is restricted to a named set of modules.
  ///
  /// The server sends an empty list for an unrestricted account, and
  /// the nav has always read it that way — "no limits", not "nothing
  /// allowed". Named here so the page cannot render the opposite.
  bool get hasFeatureLimits => features.isNotEmpty;
}

/// Up to two letters for the avatar.
///
/// From the FIRST and LAST word, not the first two characters:
/// "Ravi Kumar" is RK, and a single name gives one letter rather
/// than an accidental pair pulled out of the middle of a word.
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return (words.first.substring(0, 1) + words.last.substring(0, 1))
      .toUpperCase();
}

/// A department or role, in the case the screen wants.
///
/// The two fields disagree about casing — `department` is stored as
/// typed, `role` is lowercase from utils/roles.js — so a screen that
/// prints them side by side reads as a bug unless one of them is
/// normalised.
String titleCase(String s) {
  final t = s.trim();
  if (t.isEmpty) return '';
  return t
      .split(RegExp(r'[\s_]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// "Member since March 2026", or null when the date is unknown.
///
/// Null rather than a placeholder: a profile that says "Member since
/// —" is worse than one that does not mention it.
String? memberSinceLabel(DateTime? d) {
  if (d == null) return null;
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final m = (d.month >= 1 && d.month <= 12) ? months[d.month - 1] : '';
  return m.isEmpty ? null : 'Member since $m ${d.year}';
}
