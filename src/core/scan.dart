import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../features/PurchaseOrder/services/theme.dart';
import 'scan_payload.dart';

export 'scan_payload.dart' show ScannedJob;

// ══════════════════════════════════════════════════════════════
//  SCAN THE JOB LABEL
//
//  Packing and QC both begin by choosing a job from a dropdown that
//  can run to a hundred entries. The person doing it is standing at a
//  trolley with the job label taped to it, reading a number off the
//  paper and then hunting for the same number in a list — which is
//  the transcription step this label exists to remove. The web prints
//  a 2in square label with the code and the number precisely so it
//  can be scanned.
//
//  ── The dropdown stays ─────────────────────────────────────────
//  The scanner is offered BESIDE it, never instead of it. Labels get
//  wet, torn and covered in size; cameras fail in mill light and
//  phones run flat. A flow that can only be driven by a working
//  camera is a flow that stops the line when the camera stops.
//
//  ── A scan that matches nothing has to SAY so ──────────────────
//  The interesting failure is not an unreadable code — the person can
//  see that nothing happened and try again. It is a code that reads
//  perfectly and names a job that is not in this list: the job is
//  finished, or not in packing yet, or belongs to another stage. That
//  looks identical to a broken scanner unless it is spelled out, so
//  the caller is handed the parsed result and says which case it is.
// ══════════════════════════════════════════════════════════════

/// Open the camera and return the first job label it reads.
///
/// Returns null when the sheet was dismissed. A stray non-job barcode
/// is ignored rather than closing the sheet — sweeping a shed picks up
/// carton codes constantly, and each one closing the scanner would
/// make it unusable.
Future<ScannedJob?> scanJobLabel(BuildContext context) {
  return showModalBottomSheet<ScannedJob>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScanSheet(),
  );
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final _controller = MobileScannerController(
    // One code at a time; the label carries exactly one.
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Guards against the detector firing twice before the sheet closes,
  /// which would pop the route underneath it as well.
  bool _handled = false;

  String? _lastRejected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      final parsed = parseScannedJob(raw);
      if (!parsed.isEmpty) {
        _handled = true;
        Navigator.of(context).pop(parsed);
        return;
      }
      // Not a job label. Say what it was and keep the camera running.
      if (raw != null && raw != _lastRejected && mounted) {
        setState(() => _lastRejected = raw);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.62;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: ErpColors.navyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: ErpColors.navyLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Scan the job label',
                      style: TextStyle(
                          color: ErpColors.textOnDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Torch',
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flashlight_on_outlined,
                      color: ErpColors.textOnDark),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: ErpColors.textOnDark),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    // A camera the phone will not give us is a normal
                    // state — permission declined, or no camera at all
                    // on a shared tablet. It gets words, not a red
                    // Flutter error box.
                    errorBuilder: (_, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _cameraMessage(error),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: ErpColors.textOnDarkSub, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: ErpColors.accentLight, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Text(
              _lastRejected == null
                  ? 'Hold the square code on the job label inside the frame.'
                  : scanRejectionMessage(_lastRejected),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _lastRejected == null
                    ? ErpColors.textOnDarkSub
                    : ErpColors.statusPartialText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cameraMessage(MobileScannerException e) {
    switch (e.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'This app has not been given the camera.\n\n'
            'Allow it in the phone settings, or pick the job from the '
            'list instead.';
      case MobileScannerErrorCode.unsupported:
        return 'This device has no camera the scanner can use.\n\n'
            'Pick the job from the list instead.';
      default:
        return 'The camera could not be started.\n\n'
            'Pick the job from the list instead.';
    }
  }
}
