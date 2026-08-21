import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/PurchaseOrder/services/theme.dart';
import 'app_lock_controller.dart';

// ══════════════════════════════════════════════════════════════
//  OFFER THE LOCK, ONCE PER SIGN-IN
//
//  Shown after somebody actually signs in, when the lock is off and
//  the phone can do it. Not on every app open — the cold-start
//  restore is the app remembering a session, not a person choosing
//  to sign in, and a prompt there would be a nag.
//
//  ── Why once per sign-in is not nagging ────────────────────────
//  Sessions now last ninety days and renew on use, so a person signs
//  in roughly four times a year. That is the right frequency for
//  this question: often enough that a phone which changed hands gets
//  asked again, rare enough that nobody learns to dismiss it
//  reflexively.
//
//  ── It never blocks ────────────────────────────────────────────
//  A sheet with a plain "Not now", dismissible by tapping outside.
//  Somebody signing in at the start of a shift is trying to get to
//  work, and a modal they must answer before reaching a job card is
//  a modal they will answer without reading.
// ══════════════════════════════════════════════════════════════

Future<void> maybeOfferAppLock(BuildContext context) async {
  final lock = AppLockController.to;

  // Already on — nothing to offer.
  if (lock.enabled.value) return;

  // Nothing enrolled on this phone. Offering a lock that cannot be
  // turned on is worse than staying quiet: the person taps, it
  // fails, and they learn the feature is broken.
  if (!await lock.deviceCanLock()) return;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _OfferSheet(lock: lock),
  );
}

class _OfferSheet extends StatefulWidget {
  final AppLockController lock;
  const _OfferSheet({required this.lock});

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  bool _busy = false;

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    final ok = await widget.lock.setEnabled(true);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.of(context).pop();
      Get.snackbar(
        'App lock on',
        'The app will ask for your fingerprint, face or phone PIN '
            'when it opens.',
        backgroundColor: ErpColors.solidSuccess,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    // Stayed open, with the reason — the sheet is where the person
    // is looking, and a failure that closes the sheet and raises a
    // snackbar behind it is a failure nobody reads.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.lock.lastError.value;

    return Container(
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: ErpColors.borderLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 18),
        Icon(Icons.lock_outline_rounded,
            size: 34, color: ErpColors.accentBlue),
        const SizedBox(height: 12),
        Text(
          'Protect this phone?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ErpColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You stay signed in for months, so anybody holding this '
          'phone can open the app. Turning on the app lock puts your '
          'fingerprint, face or phone PIN in front of it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: ErpColors.textSecondary),
        ),
        if (err != null) ...[
          const SizedBox(height: 12),
          Text(err,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: ErpColors.errorRed)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _turnOn,
            style: ElevatedButton.styleFrom(
              backgroundColor: ErpColors.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_busy ? 'Waiting…' : 'Turn on app lock'),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('Not now',
              style: TextStyle(color: ErpColors.textSecondary)),
        ),
        Text(
          'You can turn it on any time from More → My account.',
          style: TextStyle(fontSize: 11, color: ErpColors.textMuted),
        ),
      ]),
    );
  }
}
