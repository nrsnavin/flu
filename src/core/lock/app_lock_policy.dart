// ══════════════════════════════════════════════════════════════
//  WHEN TO ASK FOR THE LOCK
//
//  The app can hold a ninety-day session so an operator on the floor
//  is not signing in every morning. The cost of that is a phone left
//  on a bench being a signed-in phone, and this is the thing that
//  pays it: an optional device lock — fingerprint, face, or the
//  phone's own PIN — in front of a session that otherwise never
//  expires.
//
//  ── The whole difficulty is that this app leaves itself ────────
//  A lock that fires every time the app is backgrounded sounds
//  correct and is unusable here, because backgrounding is not a
//  signal that anybody walked away:
//
//    * opening a PDF hands off to the OS viewer
//    * the camera and the gallery picker are separate activities
//    * on some Android builds the biometric prompt ITSELF
//      backgrounds the app, so a naive lock re-arms while the
//      person is in the middle of unlocking it
//
//  So two things are tracked, and they are different: how long the
//  app was away, and WHY it went. A trip to the PDF viewer is an
//  excursion the app started and expects to return from. A screen
//  that went dark in somebody's pocket is not.
//
//  ── Nobody may be locked out of their own data ─────────────────
//  Every decision here fails OPEN when the lock cannot be enforced —
//  a device with no biometrics and no PIN enrolled, a plugin that
//  will not answer. A setting that bricks the app on a factory floor
//  at 6am is worse than the risk it was guarding against, and the
//  escape from a genuinely locked app is signing out, which is
//  offered on the lock screen itself.
//
//  ── Kept free of Flutter on purpose ────────────────────────────
//  This is clock arithmetic and a small state machine, and both are
//  worth testing without an engine, a plugin or a real fingerprint.
//  See app_lock_policy_check.dart, which runs on a bare Dart VM.
// ══════════════════════════════════════════════════════════════

/// How long the app may be away before the lock re-arms.
///
/// A minute, not zero. Reading a despatch note in the OS PDF viewer,
/// answering a message and coming back is one continuous piece of
/// work; making it an authentication event trains people to turn the
/// lock off, which leaves them with less protection than a lenient
/// one would have.
const Duration kDefaultLockGrace = Duration(seconds: 60);

/// Why the app is asking for the lock, so the screen can say.
enum LockReason {
  /// Opened from cold with the lock on.
  coldStart,

  /// Came back after being away longer than the grace window.
  awayTooLong,

  /// Asked for explicitly — turning the setting on, or turning it off.
  confirmIdentity,
}

/// Everything the decision depends on, in one place.
///
/// Passed rather than read from globals so the awkward combinations
/// can be written down as tests instead of reproduced on a phone.
class AppLockState {
  /// The setting. False means this whole file does nothing.
  final bool enabled;

  /// Whether anybody is signed in. A locked login screen protects
  /// nothing and cannot be got past — there is no session to unlock.
  final bool signedIn;

  /// True while the app deliberately handed off to something else:
  /// the PDF viewer, the camera, the gallery. Set by the flows that
  /// do it, cleared when they return.
  final bool onExcursion;

  /// True while a biometric prompt is on screen. On some Android
  /// builds the prompt itself backgrounds the app; without this the
  /// lock re-arms underneath the person unlocking it.
  final bool authenticating;

  /// When the app went away, or null if it has not.
  final DateTime? leftAt;

  /// How long it may be away before the lock re-arms.
  final Duration grace;

  const AppLockState({
    required this.enabled,
    required this.signedIn,
    this.onExcursion = false,
    this.authenticating = false,
    this.leftAt,
    this.grace = kDefaultLockGrace,
  });

  AppLockState copyWith({
    bool? enabled,
    bool? signedIn,
    bool? onExcursion,
    bool? authenticating,
    DateTime? leftAt,
    bool clearLeftAt = false,
    Duration? grace,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        signedIn: signedIn ?? this.signedIn,
        onExcursion: onExcursion ?? this.onExcursion,
        authenticating: authenticating ?? this.authenticating,
        leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
        grace: grace ?? this.grace,
      );
}

/// Should the app be locked, now that it has come back?
///
/// [now] is passed rather than read so the clock can be moved in a
/// test. Returns false whenever the answer is not clearly yes —
/// see the header on failing open.
bool shouldLockOnResume(AppLockState s, DateTime now) {
  if (!s.enabled) return false;

  // Nothing to protect. A lock in front of the login screen is a door
  // on an empty room, and one the person has no way to open.
  if (!s.signedIn) return false;

  // The prompt is up. Re-arming here is the loop that makes the
  // feature unusable rather than merely annoying.
  if (s.authenticating) return false;

  // The app sent itself away and is coming back. Locking here means a
  // fingerprint every time somebody looks at a delivery challan.
  if (s.onExcursion) return false;

  // Never actually left — a lifecycle event without a departure.
  final left = s.leftAt;
  if (left == null) return false;

  // A clock that went backwards (timezone change, NTP correction)
  // gives a negative gap, and a negative gap is never >= a positive
  // grace — so it reads as "no time passed" and does not lock, which
  // is what it should do. There was an explicit guard here; mutation
  // testing showed removing it changed nothing, so it was removed
  // rather than left looking load-bearing. The check below covers it.
  final away = now.difference(left);
  return away >= s.grace;
}

/// Should the app be locked when it starts from cold?
///
/// Simpler than the resume case on purpose: there is no excursion and
/// no grace window to reason about, because the process is new. If
/// the lock is on and somebody is signed in, ask.
bool shouldLockOnStart(AppLockState s) => s.enabled && s.signedIn;

/// What the lock screen should say it is asking for.
String lockPrompt(LockReason reason) {
  switch (reason) {
    case LockReason.coldStart:
      return 'Unlock to open the app';
    case LockReason.awayTooLong:
      return 'Unlock to continue';
    case LockReason.confirmIdentity:
      return 'Confirm it is you';
  }
}

/// Whether a failed unlock attempt leaves the app usable.
///
/// The distinction that matters: a person who cancelled the prompt is
/// still locked out and can try again, but a device that CANNOT do
/// this — no fingerprint enrolled, no PIN set, hardware missing —
/// must not leave somebody staring at a lock they can never pass.
/// Those cases turn the setting off and let them in.
bool isUnenforceable(String code) {
  const cannotEverSucceed = {
    'noCredentialsSet',
    'noBiometricsEnrolled',
    'noBiometricHardware',
  };
  return cannotEverSucceed.contains(code);
}

/// Whether a failure is worth retrying without troubling the person.
///
/// A prompt the SYSTEM cancelled — an incoming call, the app being
/// backgrounded mid-scan — is not a refusal and should not read as
/// one. A prompt the PERSON cancelled is a refusal, and re-asking
/// immediately would be nagging.
bool isRetryable(String code) {
  const worthRetrying = {
    'systemCanceled',
    'uiUnavailable',
    'authInProgress',
    'biometricHardwareTemporarilyUnavailable',
  };
  return worthRetrying.contains(code);
}

/// Words for a failure code, for the lock screen.
///
/// The lockouts are called out separately because they are the two
/// where the thing to do next is not "try again": one waits, the
/// other needs the device PIN.
String lockFailureMessage(String code) {
  switch (code) {
    case 'noCredentialsSet':
      return 'This phone has no screen lock set, so the app lock cannot '
          'be used. Set a PIN or fingerprint in the phone’s settings '
          'first.';
    case 'noBiometricsEnrolled':
      return 'No fingerprint or face is enrolled on this phone.';
    case 'noBiometricHardware':
      return 'This phone cannot check a fingerprint or face.';
    case 'temporaryLockout':
      return 'Too many attempts. Wait a moment, then try again.';
    case 'biometricLockout':
      return 'Too many attempts. Unlock the phone with its PIN to '
          're-enable fingerprint.';
    case 'userCanceled':
      return 'Unlock cancelled.';
    case 'timeout':
      return 'The unlock timed out.';
    default:
      return 'Could not unlock.';
  }
}
