import 'package:get/get.dart';

// ══════════════════════════════════════════════════════════════
//  LEAVING A PAGE WHILE A NOTICE IS SHOWING
//
//  Get.back() does not always go back. While one of the app's notices
//  (Get.snackbar) is on screen it closes the NOTICE and returns — the
//  page, dialog or sheet stays where it is. GetX does this on purpose,
//  for compatibility with its older snackbars.
//
//  A dozen screens did "show Saved, then Get.back()". What the person
//  saw: the notice gone the instant it appeared and the form still open
//  with everything typed in it, as if nothing had happened. On the goods
//  receipt that invited a second tap, and a second receipt of the same
//  goods; on an order's Approve dialog, a dialog that never closed.
//
//  closePage() pops the route itself — the page, the dialog or the sheet
//  on top — and leaves the notice up for its time.
// ══════════════════════════════════════════════════════════════

/// Leave the page (or close the dialog or sheet) on top, handing
/// [result] to whoever opened it. Does nothing when there is nothing to
/// go back to.
void closePage<T>([T? result]) {
  final nav = Get.key.currentState;
  if (nav != null && nav.canPop()) nav.pop<T>(result);
}
