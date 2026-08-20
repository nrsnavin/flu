import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ══════════════════════════════════════════════════════════════
//  THE LABEL DOCUMENT, WITHOUT THE FILE SYSTEM
//
//  Split from job_qr_label.dart, which imports open_file and
//  path_provider — Flutter plugins that pull dart:ui in behind them
//  and make the whole library unrunnable outside an engine.
//
//  `pdf` and `barcode` are pure Dart, so kept apart the DOCUMENT can
//  be built and inspected on a bare Dart VM. That matters more here
//  than it looks: "2 inch square" is exactly the kind of claim that
//  ends up quietly false. The web version of this label shipped at
//  the right size with the code flush against the paper edge, because
//  Tailwind dropped two arbitrary values at build time without a
//  word. A label at the wrong size does not error — it prints, and
//  then does not fit the roll.
//
//  See job_qr_label_check.dart, which builds the bytes and reads the
//  page box back out of them.
// ══════════════════════════════════════════════════════════════

/// 2in square, and nothing on it but the code and the number.
const double kLabelInches = 2.0;

/// Modules of quiet zone the QR spec wants around the symbol.
const double kQuietModules = 4.0;

/// The URL the web encodes: `<origin>/jobs/<id>`.
///
/// [apiBaseUrl] is the configured API base — the label points at the
/// web UI, not the API, so only scheme and authority are kept. Derived
/// rather than hardcoded so a sandbox build does not print labels that
/// scan into production.
String jobLabelPayload(String apiBaseUrl, String jobId) {
  final uri = Uri.tryParse(apiBaseUrl);
  final origin = uri == null || !uri.hasAuthority
      ? ''
      : '${uri.scheme}://${uri.authority}';
  return '$origin/jobs/$jobId';
}

pw.Document buildJobLabelDocument({
  required String payload,
  required String jobNo,
}) {
  final doc = pw.Document();
  final side = kLabelInches * PdfPageFormat.inch;

  doc.addPage(
    pw.Page(
      // marginAll: 0 — the quiet zone belongs to the symbol, and a
      // page margin on top of it would shrink the code without making
      // it any more scannable.
      pageFormat: PdfPageFormat(side, side, marginAll: 0),
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(0.1 * PdfPageFormat.inch),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.BarcodeWidget(
                barcode: Barcode.qrCode(
                  // Medium: enough to survive the ink spread and
                  // scuffing a mill label gets, without shrinking the
                  // modules the way High would.
                  errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
                ),
                data: payload,
                drawText: false,
                margin: const pw.EdgeInsets.all(0),
                padding: const pw.EdgeInsets.all(0),
              ),
            ),
            pw.SizedBox(height: 0.07 * PdfPageFormat.inch),
            // The one thing that survives a smudged code, a flat
            // battery, or a camera that will not focus in mill light.
            // src/core/scan_payload.dart accepts a bare job number for
            // exactly this reason.
            pw.Text(
              jobNo,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return doc;
}
