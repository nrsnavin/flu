import 'package:open_file/open_file.dart';

import 'app_lock_controller.dart';

// ══════════════════════════════════════════════════════════════
//  HANDING OFF TO ANOTHER APP
//
//  Every PDF this app produces is opened in the phone's own viewer,
//  which backgrounds this app. With the app lock on, that is
//  indistinguishable from somebody putting the phone down — so
//  without this, looking at a delivery challan and coming back asks
//  for a fingerprint.
//
//  That is not a small annoyance. It is the thing that makes people
//  switch the lock off, which leaves them with no protection at all
//  rather than the slightly lenient protection they would have kept.
//
//  So the trip is declared. The lock knows the app sent itself away
//  and expects to come back, and does not re-arm for it.
//
//  ── Why a wrapper and not sixteen call sites ───────────────────
//  There are sixteen places that open a document. Marking each by
//  hand works exactly until somebody adds the seventeenth, and the
//  failure then is not an error — it is a fingerprint prompt in one
//  screen out of seventeen, which nobody reports as a bug.
//  Everything goes through here instead.
// ══════════════════════════════════════════════════════════════

/// Open [path] in whatever app the OS uses for it.
///
/// Same signature and return as OpenFile.open, so call sites read
/// exactly as they did.
Future<OpenResult> openExternally(String path) {
  return AppLockController.to.duringExcursion(() => OpenFile.open(path));
}
