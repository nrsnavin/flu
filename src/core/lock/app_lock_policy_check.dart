// Run with:  dart run src/core/lock/app_lock_policy_check.dart
//
// The lock decision, on a bare Dart VM. No Flutter, no plugin, no
// fingerprint — so the awkward combinations (the prompt backgrounding
// the app, a PDF viewer excursion, a clock that went backwards) are
// written down here rather than reproduced by hand on a phone.

import '../lock/app_lock_policy.dart';

int _passed = 0;
final _failures = <String>[];

void check(String what, bool ok, [String? detail]) {
  if (ok) {
    _passed++;
  } else {
    _failures.add('FAIL: $what${detail == null ? '' : '  ($detail)'}');
  }
}

final t0 = DateTime.utc(2026, 8, 21, 9, 0, 0);

/// Signed in, lock on, away since t0, default one-minute grace.
AppLockState away({
  bool enabled = true,
  bool signedIn = true,
  bool onExcursion = false,
  bool authenticating = false,
  Duration? grace,
}) =>
    AppLockState(
      enabled: enabled,
      signedIn: signedIn,
      onExcursion: onExcursion,
      authenticating: authenticating,
      leftAt: t0,
      grace: grace ?? kDefaultLockGrace,
    );

void main() {
  // ── The ordinary case ─────────────────────────────────────
  check('locks after longer than the grace window',
      shouldLockOnResume(away(), t0.add(const Duration(seconds: 61))));
  check('does not lock inside the grace window',
      !shouldLockOnResume(away(), t0.add(const Duration(seconds: 30))));
  check('locks exactly at the boundary',
      shouldLockOnResume(away(), t0.add(kDefaultLockGrace)),
      'the window is inclusive so a 60s trip locks, not 60.001s');

  // ── The setting is off ────────────────────────────────────
  check('does nothing at all when disabled',
      !shouldLockOnResume(away(enabled: false),
          t0.add(const Duration(days: 3))));

  // ── Nobody signed in ──────────────────────────────────────
  // A lock in front of the login screen is a door on an empty room,
  // and one the person has no way through.
  check('does not lock a signed-out app',
      !shouldLockOnResume(away(signedIn: false),
          t0.add(const Duration(hours: 5))));

  // ── The excursions this app makes constantly ──────────────
  check('a PDF viewer trip does not lock, however long it takes',
      !shouldLockOnResume(away(onExcursion: true),
          t0.add(const Duration(minutes: 20))));
  check('CONTROL: the same trip WOULD lock without the excursion flag',
      shouldLockOnResume(away(), t0.add(const Duration(minutes: 20))));

  // ── The prompt backgrounding the app ──────────────────────
  // On some Android builds the biometric sheet itself pauses the app.
  // Without this the lock re-arms underneath the person unlocking it,
  // which is the loop that makes the feature unusable rather than
  // merely annoying.
  check('the unlock prompt does not re-arm the lock',
      !shouldLockOnResume(away(authenticating: true),
          t0.add(const Duration(minutes: 5))));

  // ── A lifecycle event with no departure ───────────────────
  check('never left means never locks',
      !shouldLockOnResume(
          const AppLockState(enabled: true, signedIn: true), t0));

  // ── A clock that moved backwards ──────────────────────────
  // Timezone change, NTP correction. This holds because a negative
  // duration is never >= a positive grace, NOT because anything
  // guards it — an explicit guard was tried and mutation testing
  // showed removing it changed nothing, so it went. Kept as a
  // statement of the behaviour rather than of the mechanism.
  check('a backwards clock does not lock',
      !shouldLockOnResume(away(), t0.subtract(const Duration(hours: 2))));
  check('a backwards clock does not lock even at zero grace',
      !shouldLockOnResume(away(grace: Duration.zero),
          t0.subtract(const Duration(hours: 2))),
      'zero grace is the case where a guard would have mattered');

  // ── A custom grace ────────────────────────────────────────
  check('a longer grace holds longer',
      !shouldLockOnResume(
          away(grace: const Duration(minutes: 10)),
          t0.add(const Duration(minutes: 9))));
  check('a zero grace locks on any departure',
      shouldLockOnResume(away(grace: Duration.zero),
          t0.add(const Duration(milliseconds: 1))));

  // ── Cold start ────────────────────────────────────────────
  check('cold start locks when enabled and signed in',
      shouldLockOnStart(const AppLockState(enabled: true, signedIn: true)));
  check('cold start does not lock when disabled',
      !shouldLockOnStart(const AppLockState(enabled: false, signedIn: true)));
  check('cold start does not lock when signed out',
      !shouldLockOnStart(const AppLockState(enabled: true, signedIn: false)));

  // ── Failures that can never succeed ───────────────────────
  // These are the lock-out cases. A setting that bricks the app at
  // 6am on a factory floor is worse than the risk it guarded.
  for (final c in [
    'noCredentialsSet',
    'noBiometricsEnrolled',
    'noBiometricHardware',
  ]) {
    check('$c is unenforceable', isUnenforceable(c));
  }
  for (final c in [
    'userCanceled',
    'timeout',
    'temporaryLockout',
    'biometricLockout',
    'systemCanceled',
  ]) {
    check('CONTROL: $c is NOT unenforceable', !isUnenforceable(c),
        'treating a cancel as unenforceable would switch the lock off '
        'whenever somebody dismissed the prompt');
  }

  // ── Retry without troubling anybody ───────────────────────
  check('a system cancel is retryable', isRetryable('systemCanceled'));
  check('missing UI is retryable', isRetryable('uiUnavailable'));
  check('CONTROL: a user cancel is NOT retryable',
      !isRetryable('userCanceled'),
      're-prompting somebody who just dismissed it is nagging');
  check('CONTROL: a biometric lockout is NOT retryable',
      !isRetryable('biometricLockout'));

  // ── The two categories do not overlap ─────────────────────
  // A code that is both would be handled twice, and the order of the
  // two checks would silently decide the behaviour.
  for (final c in [
    'authInProgress', 'uiUnavailable', 'userCanceled', 'timeout',
    'systemCanceled', 'noCredentialsSet', 'noBiometricsEnrolled',
    'noBiometricHardware', 'biometricHardwareTemporarilyUnavailable',
    'temporaryLockout', 'biometricLockout',
  ]) {
    check('$c is not in both categories',
        !(isUnenforceable(c) && isRetryable(c)));
  }

  // ── Wording ───────────────────────────────────────────────
  check('no screen lock says to set one',
      lockFailureMessage('noCredentialsSet').contains('screen lock'));
  check('a biometric lockout says to use the PIN',
      lockFailureMessage('biometricLockout').contains('PIN'));
  check('an unknown code still says something',
      lockFailureMessage('something_new').isNotEmpty);
  check('CONTROL: an unknown code is not given a specific message',
      lockFailureMessage('something_new') == 'Could not unlock.');

  check('every reason has a prompt', LockReason.values
      .every((r) => lockPrompt(r).isNotEmpty));
  check('the prompts are not all the same',
      lockPrompt(LockReason.coldStart) != lockPrompt(LockReason.confirmIdentity));

  for (final f in _failures) {
    // ignore: avoid_print
    print(f);
  }
  // ignore: avoid_print
  print(_failures.isEmpty
      ? 'ALL PASS ($_passed checks)'
      : '${_failures.length} FAILED, $_passed passed');
}
