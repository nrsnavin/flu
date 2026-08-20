import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/Job/screens/job_detail.dart';
import '../features/packing/screens/PackingDetail.dart';
import '../features/shift/screens/shift_detail.dart';
import '../features/PurchaseOrder/services/theme.dart';
import 'api_client.dart';
import 'app_config.dart';
import 'scan.dart';

// ══════════════════════════════════════════════════════════════
//  SCAN, THEN OPEN THE THING
//
//  One button, anywhere in the app: point it at a label and land on
//  that record's screen. The person on the floor is holding a
//  trolley tag or a carton and wants the screen for it — not a
//  module list, then a search box, then a row.
//
//  ── Two costs, and they are not the same ───────────────────────
//  A job label, a box label and a shift-sheet row all carry their
//  own id, so those open with no server call at all — the screen is pushed before the
//  camera sheet has finished closing. The beam labels carry only a
//  job NUMBER, so those cost one round trip to /job/by-number.
//
//  The difference is visible on purpose: the direct cases push
//  immediately, and only the lookup shows a spinner. Making all four
//  wait for a request that three of them do not need would be slower
//  for no reason, on the wifi where it matters most.
//
//  ── Every failure has to say WHICH failure ─────────────────────
//  This is the whole reason this file is not four lines. A label that
//  scans perfectly and leads nowhere looks, to the person holding the
//  phone, exactly like a camera that did not focus. So:
//
//    * a beam label printed before its job was linked says that
//    * a job number nothing matches names the number
//    * a number matching two jobs refuses and says why
//    * a network failure says it was the network
//
//  Each of those is a different thing to do next, and "scan failed"
//  tells the operator none of them.
// ══════════════════════════════════════════════════════════════

/// Open the camera, then push the screen for whatever was scanned.
///
/// Does nothing when the sheet is dismissed. Never throws — every
/// failure ends in a message rather than an exception, because this
/// is invoked from an icon button with nowhere to catch.
Future<void> scanAndOpen(BuildContext context) async {
  final code = await scanAnyLabel(context);
  if (code == null) return; // dismissed

  await openScannedCode(code);
}

/// Push the screen a parsed code names.
///
/// Split out from [scanAndOpen] so the routing can be reasoned about
/// without a camera in the way.
Future<void> openScannedCode(ScannedCode code) async {
  // ── The cheap cases: the label carried its own id ────────────
  if (code.isDirect) {
    switch (code.target) {
      case ScanTarget.packing:
        Get.to(() => const PackingDetailPage(), arguments: code.id);
        return;
      case ScanTarget.shift:
        // The row's id IS the ShiftDetail id — utils/shiftSheetPdf.js
        // encodes `sdId: d._id` off the plan, and the controller here
        // fetches /shift/shiftDetail?id= with exactly that.
        Get.to(() => ShiftDetailPage(shiftId: code.id!));
        return;
      case ScanTarget.job:
        Get.to(() => JobDetailPage(), arguments: code.id);
        return;
      case ScanTarget.unknown:
        break;
    }
  }

  // ── The beam labels: a job number, and one hop ───────────────
  final jobNo = code.jobNo;
  if (jobNo == null) {
    // Each recognised-but-unusable label has its own reason, and they
    // are not interchangeable: a beam label printed too early needs
    // reprinting, a shift short code needs the operator to aim at the
    // square code instead. Saying the wrong one sends them to fix
    // something that is not broken.
    _say('Nothing to open', scanCodeMessage(code), bad: true);
    return;
  }

  final resolved = await _jobIdForNumber(jobNo);
  switch (resolved.outcome) {
    case _Outcome.found:
      Get.to(() => JobDetailPage(), arguments: resolved.id);
      return;
    case _Outcome.failed:
      _say('Job $jobNo', resolved.message!, bad: true);
      return;
  }
}

// ─────────────────────────────────────────────────────────────
//  THE ONE HOP
// ─────────────────────────────────────────────────────────────

enum _Outcome { found, failed }

class _Resolved {
  final _Outcome outcome;
  final String? id;
  final String? message;
  const _Resolved.found(this.id) : outcome = _Outcome.found, message = null;
  const _Resolved.failed(this.message) : outcome = _Outcome.failed, id = null;
}

/// Ask the server which job carries [jobNo].
///
/// The server's own message is preferred over anything invented here:
/// it is the side that knows whether the number was unknown, or
/// duplicated, or belonged to a job whose order is gone, and it says
/// so in words. See api/job.js `GET /by-number/:jobNo`.
Future<_Resolved> _jobIdForNumber(int jobNo) async {
  final dio = ApiClient.buildClient(
    baseUrl: ApiConfig.baseUrl,
    timeout: const Duration(seconds: 12),
  );

  try {
    final res = await dio.get('/job/by-number/$jobNo');
    final id = (res.data?['job']?['id'] ?? '').toString();
    if (id.isEmpty) {
      // A 200 with no id is a contract break, not a missing job, and
      // saying "no such job" for it would send somebody hunting for a
      // job that is sitting right there.
      return const _Resolved.failed(
          'The server answered, but did not say which job. Try again.');
    }
    return _Resolved.found(id);
  } on DioException catch (e) {
    final msg = e.response?.data is Map
        ? (e.response!.data as Map)['message']?.toString()
        : null;
    if (msg != null && msg.isNotEmpty) return _Resolved.failed(msg);

    // No response body at all — the request did not arrive. That is a
    // different thing to do next from "no such job", so it reads
    // differently.
    return const _Resolved.failed(
        'Could not reach the server. Check the connection and scan again.');
  } catch (_) {
    return const _Resolved.failed('Something went wrong looking that up.');
  }
}

void _say(String title, String message, {bool bad = false}) {
  Get.snackbar(
    title,
    message,
    backgroundColor: bad ? ErpColors.errorRed : ErpColors.accentBlue,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    // Long enough to read a sentence. The default 3s is not.
    duration: const Duration(seconds: 5),
    margin: const EdgeInsets.all(12),
  );
}
